import Foundation
import Photos
import SwiftUI

enum PhotoDecision: String, Codable {
    case keep
    case delete
}

struct PhotoMonth: Identifiable {
    let id: String
    let date: Date
    let assets: [PHAsset]
    var displayName: String? = nil

    var title: String { displayName ?? date.formatted(.dateTime.month(.wide).year()) }
}

@MainActor
final class PhotoLibraryStore: ObservableObject {
    @Published private(set) var authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @Published private(set) var months: [PhotoMonth] = []
    @Published private(set) var allAssets: [PHAsset] = []
    @Published private(set) var isLoading = false
    @Published var alertMessage: String?
    @Published private(set) var activeMonth: PhotoMonth?
    @Published private(set) var swipeQueue: [String] = []
    @Published private(set) var swipeAssets: [PHAsset] = []
    @Published private(set) var swipeIndex = 0
    @Published private(set) var isDeleting = false
    @Published private(set) var lastResult: CleanupResult?
    @Published private(set) var bookmarkedIDs: Set<String>
    @Published private(set) var completedMonthIDs: Set<String>

    private var decisions: [String: [String: PhotoDecision]]
    private var undoStack: [(assetID: String, decision: PhotoDecision?)] = []
    private let defaults = UserDefaults.standard

    @Published private(set) var deletedCount: Int
    @Published private(set) var savedBytes: Int64

    private let bookmarksKey = "swipewipe.bookmarks.v1"
    private let decisionsKey = "swipewipe.decisions.v2"
    private let completedMonthsKey = "swipewipe.completed-months.v2"
    private let deletedCountKey = "swipewipe.deleted-count.v1"
    private let savedBytesKey = "swipewipe.saved-bytes.v1"

    init() {
        bookmarkedIDs = Set(defaults.stringArray(forKey: bookmarksKey) ?? [])
        completedMonthIDs = Set(defaults.stringArray(forKey: completedMonthsKey) ?? [])
        if let data = defaults.data(forKey: decisionsKey),
           let saved = try? JSONDecoder().decode([String: [String: PhotoDecision]].self, from: data) {
            decisions = saved
        } else {
            decisions = [:]
        }
        deletedCount = defaults.integer(forKey: deletedCountKey)
        savedBytes = Int64(defaults.object(forKey: savedBytesKey) as? Int ?? 0)
        refreshAuthorizationAndLibrary()
    }

    var currentSwipeAsset: PHAsset? {
        guard swipeIndex < swipeAssets.count else { return nil }
        return swipeAssets[swipeIndex]
    }

    var currentDeletionAssets: [PHAsset] {
        guard let activeMonth else { return [] }
        let queuedIDs = Set(swipeQueue)
        return activeMonth.assets.filter { asset in
            queuedIDs.contains(asset.localIdentifier)
                && decisions[activeMonth.id]?[asset.localIdentifier] == .delete
        }
    }

    var currentMonthProgress: (done: Int, total: Int) {
        guard let activeMonth else { return (0, 0) }
        let done = activeMonth.assets.filter { decisions[activeMonth.id]?[$0.localIdentifier] != nil }.count
        return (done, activeMonth.assets.count)
    }

    var bookmarkedAssets: [PHAsset] {
        let byID = Dictionary(allAssets.map { ($0.localIdentifier, $0) }, uniquingKeysWith: { first, _ in first })
        return bookmarkedIDs.compactMap { byID[$0] }.sorted { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
    }

    var onThisDayAssets: [PHAsset] {
        let calendar = Calendar.current
        let today = Date()
        return allAssets.filter { asset in
            guard let date = asset.creationDate else { return false }
            let a = calendar.dateComponents([.month, .day], from: date)
            let b = calendar.dateComponents([.month, .day], from: today)
            return a.month == b.month && a.day == b.day
        }.sorted { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
    }

    func requestAccess() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            Task { @MainActor in
                self?.authorizationStatus = status
                if status == .authorized || status == .limited {
                    self?.loadLibrary()
                }
            }
        }
    }

    func refreshAuthorizationAndLibrary() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if authorizationStatus == .authorized || authorizationStatus == .limited {
            loadLibrary()
        }
    }

    func loadLibrary() {
        guard !isLoading else { return }
        isLoading = true
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let result = PHAsset.fetchAssets(with: options)
        var fetched: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in fetched.append(asset) }

        let calendar = Calendar.current
        let groups = Dictionary(grouping: fetched) { asset -> String in
            guard let date = asset.creationDate else { return "undated" }
            let c = calendar.dateComponents([.year, .month], from: date)
            return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
        }
        let newMonths = groups.compactMap { key, assets -> PhotoMonth? in
            guard let firstDate = assets.compactMap(\.creationDate).first else { return nil }
            return PhotoMonth(id: key, date: firstDate, assets: assets)
        }.sorted { $0.date > $1.date }

        allAssets = fetched
        months = newMonths
        isLoading = false
        reconcileCompletedMonths()
    }

    func progress(for month: PhotoMonth) -> (done: Int, total: Int) {
        let done = month.assets.filter { decisions[month.id]?[$0.localIdentifier] != nil }.count
        return (done, month.assets.count)
    }

    func begin(_ month: PhotoMonth) {
        if completedMonthIDs.contains(month.id) {
            decisions[month.id] = [:]
            completedMonthIDs.remove(month.id)
            persistDecisions()
            defaults.set(Array(completedMonthIDs), forKey: completedMonthsKey)
        }
        activeMonth = month
        lastResult = nil
        undoStack.removeAll()
        let monthDecisions = decisions[month.id] ?? [:]
        swipeQueue = month.assets.filter { monthDecisions[$0.localIdentifier] == .delete }.map(\.localIdentifier)
        swipeAssets = month.assets.filter { monthDecisions[$0.localIdentifier] == nil }
        swipeIndex = 0
        if swipeAssets.isEmpty && swipeQueue.isEmpty {
            markMonthComplete(month.id)
        }
    }

    func beginRandomForty() {
        guard !allAssets.isEmpty else { return }
        let selection = Array(allAssets.shuffled().prefix(40))
        let randomMonth = PhotoMonth(id: "random-40", date: Date(), assets: selection, displayName: "Random 40")
        decisions[randomMonth.id] = [:]
        completedMonthIDs.remove(randomMonth.id)
        persistDecisions()
        defaults.set(Array(completedMonthIDs), forKey: completedMonthsKey)
        begin(randomMonth)
    }

    func decideCurrent(_ decision: PhotoDecision) {
        guard let month = activeMonth, let asset = currentSwipeAsset else { return }
        let old = decisions[month.id]?[asset.localIdentifier]
        undoStack.append((asset.localIdentifier, old))
        decisions[month.id, default: [:]][asset.localIdentifier] = decision
        switch decision {
        case .keep:
            swipeQueue.removeAll { $0 == asset.localIdentifier }
        case .delete:
            if !swipeQueue.contains(asset.localIdentifier) { swipeQueue.append(asset.localIdentifier) }
        }
        persistDecisions()
        swipeIndex += 1
        updateCompletionIfNeeded()
    }

    func undoLastDecision() {
        guard let month = activeMonth, let last = undoStack.popLast() else { return }
        if decisions[month.id]?[last.assetID] == .delete {
            swipeQueue.removeAll { $0 == last.assetID }
        }
        if let old = last.decision {
            decisions[month.id, default: [:]][last.assetID] = old
            if old == .delete && !swipeQueue.contains(last.assetID) { swipeQueue.append(last.assetID) }
        } else {
            decisions[month.id]?.removeValue(forKey: last.assetID)
        }
        swipeIndex = max(0, swipeIndex - 1)
        persistDecisions()
        updateCompletionIfNeeded()
    }

    func toggleBookmark(_ asset: PHAsset) {
        if bookmarkedIDs.contains(asset.localIdentifier) {
            bookmarkedIDs.remove(asset.localIdentifier)
        } else {
            bookmarkedIDs.insert(asset.localIdentifier)
        }
        defaults.set(Array(bookmarkedIDs), forKey: bookmarksKey)
    }

    func isBookmarked(_ asset: PHAsset) -> Bool {
        bookmarkedIDs.contains(asset.localIdentifier)
    }

    func removeFromQueue(_ asset: PHAsset) {
        guard let month = activeMonth else { return }
        swipeQueue.removeAll { $0 == asset.localIdentifier }
        decisions[month.id, default: [:]][asset.localIdentifier] = .keep
        persistDecisions()
        updateCompletionIfNeeded()
    }

    func confirmDeletion() {
        let assetsToDelete = currentDeletionAssets
        guard !assetsToDelete.isEmpty else {
            finishSessionWithoutDeletion()
            return
        }
        isDeleting = true
        let ids = assetsToDelete.map(\.localIdentifier)
        let bytes = assetsToDelete.reduce(Int64(0)) { $0 + Self.estimatedBytes(for: $1) }
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assetsToDelete as NSArray)
        } completionHandler: { [weak self] success, error in
            Task { @MainActor in
                guard let self else { return }
                self.isDeleting = false
                if success {
                    self.deletedCount += ids.count
                    self.savedBytes += bytes
                    self.defaults.set(self.deletedCount, forKey: self.deletedCountKey)
                    self.defaults.set(Int(self.savedBytes), forKey: self.savedBytesKey)
                    let monthID = self.activeMonth?.id
                    let remainingAssets = (self.activeMonth?.assets ?? []).filter { !ids.contains($0.localIdentifier) }
                    if let monthID {
                        for id in ids { self.decisions[monthID]?.removeValue(forKey: id) }
                        let allRemainingKept = !remainingAssets.isEmpty && remainingAssets.allSatisfy {
                            self.decisions[monthID]?[$0.localIdentifier] == .keep
                        }
                        if allRemainingKept { self.markMonthComplete(monthID) }
                    }
                    self.persistDecisions()
                    self.lastResult = CleanupResult(count: ids.count, bytes: bytes, monthTitle: self.activeMonth?.title ?? "your library")
                    self.activeMonth = nil
                    self.swipeAssets = []
                    self.swipeQueue = []
                    self.loadLibrary()
                } else {
                    self.alertMessage = error?.localizedDescription ?? "Photos couldn’t delete those images. Try again."
                }
            }
        }
    }

    func finishSessionWithoutDeletion() {
        updateCompletionIfNeeded()
        activeMonth = nil
        swipeAssets = []
        swipeQueue = []
    }

    func dismissResult() {
        lastResult = nil
    }

    func clearAlert() {
        alertMessage = nil
    }

    static func estimatedBytes(for asset: PHAsset) -> Int64 {
        PHAssetResource.assetResources(for: asset).reduce(Int64(0)) { sum, resource in
            sum + (resource.value(forKey: "fileSize") as? Int64 ?? 0)
        }
    }

    static func byteString(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func updateCompletionIfNeeded() {
        guard let month = activeMonth else { return }
        let progress = currentMonthProgress
        if progress.total > 0 && progress.done == progress.total && swipeQueue.isEmpty {
            markMonthComplete(month.id)
        } else {
            completedMonthIDs.remove(month.id)
            defaults.set(Array(completedMonthIDs), forKey: completedMonthsKey)
        }
    }

    private func reconcileCompletedMonths() {
        let validKeys = Set(months.map(\.id))
        completedMonthIDs.formIntersection(validKeys)
        defaults.set(Array(completedMonthIDs), forKey: completedMonthsKey)
    }

    private func markMonthComplete(_ id: String) {
        completedMonthIDs.insert(id)
        defaults.set(Array(completedMonthIDs), forKey: completedMonthsKey)
    }

    private func persistDecisions() {
        if let data = try? JSONEncoder().encode(decisions) {
            defaults.set(data, forKey: decisionsKey)
        }
    }
}

struct CleanupResult: Identifiable {
    let id = UUID()
    let count: Int
    let bytes: Int64
    let monthTitle: String
}
