import Photos
import SwiftUI

private enum Palette {
    static let background = Color(red: 0.035, green: 0.035, blue: 0.04)
    static let peach = Color(red: 0.97, green: 0.79, blue: 0.67)
    static let purple = Color(red: 0.66, green: 0.43, blue: 0.91)
    static let mint = Color(red: 0.50, green: 0.93, blue: 0.67)
    static let yellow = Color(red: 0.96, green: 0.80, blue: 0.36)
    static let orange = Color(red: 0.96, green: 0.53, blue: 0.28)
    static let blue = Color(red: 0.32, green: 0.57, blue: 0.93)
    static let teal = Color(red: 0.17, green: 0.77, blue: 0.68)
}

struct RootView: View {
    @EnvironmentObject private var library: PhotoLibraryStore
    @State private var selectedTab = 0

    var body: some View {
        Group {
            switch library.authorizationStatus {
            case .authorized, .limited:
                TabView(selection: $selectedTab) {
                    HomeView().tabItem { Label("Clean", systemImage: "sparkles") }.tag(0)
                    MemoriesView().tabItem { Label("Today", systemImage: "sun.max") }.tag(1)
                    BookmarksView().tabItem { Label("Saved", systemImage: "bookmark") }.tag(2)
                    StatsView().tabItem { Label("Stats", systemImage: "chart.line.uptrend.xyaxis") }.tag(3)
                }
                .tint(Palette.peach)
            case .notDetermined:
                PermissionView(action: library.requestAccess)
            default:
                PermissionView(action: library.requestAccess, denied: true)
            }
        }
        .background(Palette.background.ignoresSafeArea())
        .fullScreenCover(item: Binding(get: { library.activeMonth }, set: { if $0 == nil { library.finishSessionWithoutDeletion() } })) { month in
            SwipeFlowView(month: month)
                .environmentObject(library)
        }
        .fullScreenCover(item: Binding(get: { library.lastResult }, set: { if $0 == nil { library.dismissResult() } })) { result in
            ResultView(result: result) { library.dismissResult() }
        }
        .alert("Photo Library", isPresented: Binding(get: { library.alertMessage != nil }, set: { if !$0 { library.alertMessage = nil } })) {
            Button("OK", role: .cancel) { library.clearAlert() }
        } message: { Text(library.alertMessage ?? "") }
    }
}

struct PermissionView: View {
    let action: () -> Void
    var denied = false
    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "photo.stack").font(.system(size: 48, weight: .light)).foregroundStyle(Palette.peach)
            Text("Let’s clean up your camera roll.").font(.system(size: 28, weight: .bold, design: .rounded)).multilineTextAlignment(.center)
            Text(denied ? "Swipewipe needs Photos access to show your pictures and remove the ones you choose." : "Your photos stay in your library. Swipe left to queue a photo for deletion, or right to keep it.")
                .font(.body).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
            Button(action: action) {
                Text(denied ? "Check Access" : "Allow Photo Access")
                    .font(.headline).foregroundStyle(.black).padding(.vertical, 16).frame(maxWidth: .infinity)
                    .background(Palette.mint, in: Capsule())
            }
        }
        .padding(28).frame(maxWidth: .infinity, maxHeight: .infinity).background(Palette.background.ignoresSafeArea())
    }
}

struct HomeView: View {
    @EnvironmentObject private var library: PhotoLibraryStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("swipewipe").font(.system(size: 34, weight: .black, design: .rounded)).tracking(-1.5)
                        Spacer()
                        NavigationLink { StatsView() } label: {
                            Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your camera roll,\nback under control.")
                            .font(.system(size: 31, weight: .bold, design: .rounded)).tracking(-0.8)
                        Text("Pick a month and make a little room.")
                            .font(.subheadline).foregroundStyle(.white.opacity(0.62))
                    }
                    Button { library.beginRandomForty() } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "shuffle").font(.title3.weight(.black))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Random 40").font(.subheadline.weight(.bold))
                                Text("\(min(40, library.allAssets.count)) random photos").font(.caption).opacity(0.8)
                            }
                            Spacer()
                            Image(systemName: "arrow.right").font(.system(size: 15, weight: .bold))
                        }
                        .foregroundStyle(.black).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.purple, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(library.allAssets.isEmpty || library.isLoading)
                    .opacity(library.allAssets.isEmpty || library.isLoading ? 0.45 : 1)
                    if library.isLoading {
                        ProgressView("Finding photos…").tint(Palette.peach).padding(.vertical, 36)
                    } else if library.months.isEmpty {
                        EmptyLibraryCard()
                    } else {
                        VStack(spacing: 12) {
                            ForEach(Array(library.months.enumerated()), id: \.element.id) { index, month in
                                MonthCard(month: month, color: monthColor(index), progress: library.progress(for: month)) {
                                    library.begin(month)
                                }
                            }
                        }
                    }
                    HStack(spacing: 12) {
                        SmallFeatureCard(title: "On this day", value: "\(library.onThisDayAssets.count) photos", color: Palette.orange, icon: "sun.max.fill")
                        SmallFeatureCard(title: "Bookmarks", value: "\(library.bookmarkedIDs.count) saved", color: Palette.teal, icon: "bookmark.fill")
                    }
                }
                .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 28)
            }
            .background(Palette.background)
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { library.loadLibrary() }
        }
    }

    private func monthColor(_ index: Int) -> Color {
        [Palette.peach, Palette.blue, Palette.yellow, Palette.orange, Palette.purple, Palette.mint, Palette.teal][index % 7]
    }
}

struct MonthCard: View {
    @EnvironmentObject private var library: PhotoLibraryStore
    let month: PhotoMonth
    let color: Color
    let progress: (done: Int, total: Int)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(month.date.formatted(.dateTime.month(.abbreviated).year()).uppercased())
                        .font(.system(size: 21, weight: .black, design: .rounded)).tracking(0.3)
                    Text("\(month.assets.count) photos")
                        .font(.subheadline.weight(.medium)).opacity(0.75)
                }
                Spacer()
                if library.completedMonthIDs.contains(month.id) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 25)).foregroundStyle(Palette.mint)
                } else {
                    ProgressRing(progress: progress.total == 0 ? 0 : Double(progress.done) / Double(progress.total))
                        .frame(width: 33, height: 33)
                }
                Image(systemName: "arrow.right").font(.system(size: 15, weight: .bold))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 18).padding(.vertical, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .environmentObject(library)
    }
}

struct ProgressRing: View {
    let progress: Double
    var body: some View {
        ZStack {
            Circle().stroke(.black.opacity(0.15), lineWidth: 4)
            Circle().trim(from: 0, to: progress).stroke(.black, style: StrokeStyle(lineWidth: 4, lineCap: .round)).rotationEffect(.degrees(-90))
        }
    }
}

struct SmallFeatureCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.title3.weight(.bold))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.bold))
                Text(value).font(.caption).opacity(0.8)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.black).padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(color, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct SwipeFlowView: View {
    @EnvironmentObject private var library: PhotoLibraryStore
    let month: PhotoMonth
    @State private var dragOffset: CGSize = .zero
    @State private var showPhotoInfo = false
    @State private var showDeleteConfirmation = false

    private var isReviewing: Bool { library.currentSwipeAsset == nil }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            if isReviewing {
                ReviewQueueView(month: month, showDeleteConfirmation: $showDeleteConfirmation)
            } else {
                swipeScreen
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showPhotoInfo) {
            Group {
                if let asset = library.currentSwipeAsset { PhotoInfoSheet(asset: asset) }
            }
            .presentationDetents([.medium])
        }
        .confirmationDialog("Delete \(library.currentDeletionAssets.count) photos?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Photos", role: .destructive) { library.confirmDeletion() }
            Button("Go Back", role: .cancel) { }
        } message: {
            Text("Photos will be moved to Recently Deleted. You can review the selection before confirming.")
        }
        .overlay {
            if library.isDeleting {
                ZStack { Color.black.opacity(0.65).ignoresSafeArea(); ProgressView("Deleting photos…").tint(Palette.peach) }
            }
        }
    }

    private var swipeScreen: some View {
        VStack(spacing: 0) {
            HStack {
                Button { library.finishSessionWithoutDeletion() } label: { Label("MONTHS", systemImage: "chevron.left").font(.caption.weight(.bold)) }
                Spacer()
                Text(month.title.uppercased()).font(.caption.weight(.bold)).lineLimit(1).foregroundStyle(.white.opacity(0.75))
                Spacer()
                Button { showPhotoInfo = true } label: { Image(systemName: "info.circle.fill").font(.title3) }
                Text("\(library.currentMonthProgress.done + 1)/\(library.currentMonthProgress.total)")
                    .font(.headline.monospacedDigit())
                Button { library.undoLastDecision() } label: { Image(systemName: "arrow.uturn.backward").font(.title3) }
                    .disabled(library.currentMonthProgress.done == 0).opacity(library.currentMonthProgress.done == 0 ? 0.3 : 1)
            }
            .foregroundStyle(.white).padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 8)

            GeometryReader { proxy in
                if let asset = library.currentSwipeAsset {
                    ZStack {
                        AssetThumbnail(asset: asset, contentMode: .aspectFit, cornerRadius: 8)
                        if dragOffset.width < -30 {
                            DecisionStamp(title: "DELETE", color: Palette.purple).rotationEffect(.degrees(-10)).offset(x: -40, y: -proxy.size.height * 0.32)
                        } else if dragOffset.width > 30 {
                            DecisionStamp(title: "KEEP", color: Palette.mint).rotationEffect(.degrees(8)).offset(x: 40, y: -proxy.size.height * 0.32)
                        }
                    }
                    .padding(.horizontal, 18).padding(.vertical, 10)
                    .offset(dragOffset)
                    .rotationEffect(.degrees(Double(dragOffset.width / 28)))
                    .gesture(DragGesture(minimumDistance: 12)
                        .onChanged { dragOffset = $0.translation }
                        .onEnded { value in
                            if value.translation.width < -100 { decide(.delete) }
                            else if value.translation.width > 100 { decide(.keep) }
                            else { withAnimation(.spring) { dragOffset = .zero } }
                        })
                    .animation(.spring(response: 0.28, dampingFraction: 0.78), value: dragOffset)
                    .accessibilityHint("Swipe right to keep, left to delete")
                }
            }

            HStack(alignment: .center) {
                Button { decide(.delete) } label: { Text("DELETE").font(.system(size: 17, weight: .black, design: .rounded)).foregroundStyle(Palette.purple) }
                Spacer()
                Button { if let asset = library.currentSwipeAsset { library.toggleBookmark(asset) } } label: {
                    Image(systemName: library.currentSwipeAsset.map(library.isBookmarked) == true ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 22, weight: .semibold)).foregroundStyle(Palette.peach)
                }
                Spacer()
                Button { decide(.keep) } label: { Text("KEEP").font(.system(size: 17, weight: .black, design: .rounded)).foregroundStyle(Palette.mint) }
            }
            .padding(.horizontal, 26).padding(.top, 12).padding(.bottom, 20)
        }
    }

    private func decide(_ decision: PhotoDecision) {
        withAnimation(.easeInOut(duration: 0.18)) { dragOffset = .zero; library.decideCurrent(decision) }
    }
}

struct DecisionStamp: View {
    let title: String
    let color: Color
    var body: some View {
        Text(title).font(.system(size: 24, weight: .black, design: .rounded)).padding(.horizontal, 12).padding(.vertical, 8)
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(color, lineWidth: 4)).foregroundStyle(color)
    }
}

struct ReviewQueueView: View {
    @EnvironmentObject private var library: PhotoLibraryStore
    let month: PhotoMonth
    @Binding var showDeleteConfirmation: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { library.finishSessionWithoutDeletion() } label: { Label("MONTHS", systemImage: "chevron.left").font(.caption.weight(.bold)) }
                Spacer()
                Text(month.title.uppercased()).font(.caption.weight(.bold)).lineLimit(1).foregroundStyle(.white.opacity(0.75))
                Spacer()
                Text("REVIEW").font(.caption.weight(.bold)).tracking(1.5).foregroundStyle(.white.opacity(0.55))
            }
            .foregroundStyle(.white).padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 12)
            if library.currentDeletionAssets.isEmpty {
                Spacer()
                Image(systemName: "checkmark.circle.fill").font(.system(size: 56)).foregroundStyle(Palette.mint)
                Text(month.displayName == "Random 40" ? "Selection complete" : "Month complete").font(.system(size: 28, weight: .bold, design: .rounded)).padding(.top, 16)
                Text(month.displayName == "Random 40" ? "You kept every photo in this selection." : "You kept every photo in this month.").font(.subheadline).foregroundStyle(.white.opacity(0.65)).padding(.top, 4)
                Spacer()
                Button { library.finishSessionWithoutDeletion() } label: { Text("Return Home").font(.headline.weight(.bold)).foregroundStyle(.black).frame(maxWidth: .infinity).padding(.vertical, 17).background(Palette.mint, in: Capsule()) }
                    .padding(.horizontal, 20).padding(.bottom, 20)
            } else {
                Text("Give them one last look.").font(.system(size: 24, weight: .bold, design: .rounded)).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.bottom, 10)
                Text("Tap a photo to remove it from the deletion list.").font(.subheadline).foregroundStyle(.white.opacity(0.62)).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.bottom, 16)
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 3), spacing: 5) {
                        ForEach(library.currentDeletionAssets, id: \.localIdentifier) { asset in
                            Button { library.removeFromQueue(asset) } label: {
                                ZStack(alignment: .bottomTrailing) {
                                    AssetThumbnail(asset: asset, cornerRadius: 3)
                                    Image(systemName: "trash.fill").font(.caption2).padding(7).background(Palette.purple, in: Circle()).foregroundStyle(.white).padding(5)
                                }
                                .aspectRatio(1, contentMode: .fit)
                            }.buttonStyle(.plain)
                        }
                    }.padding(.horizontal, 10).padding(.bottom, 18)
                }
                Spacer(minLength: 6)
                Button { showDeleteConfirmation = true } label: {
                    Text("Delete \(library.currentDeletionAssets.count) Photos")
                        .font(.system(size: 18, weight: .black, design: .rounded)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 17).background(Palette.purple, in: Capsule())
                }
                .padding(.horizontal, 20).padding(.bottom, 18)
            }
        }
    }
}

struct PhotoInfoSheet: View {
    let asset: PHAsset
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Photo details").font(.title2.bold())
            if let date = asset.creationDate { Label(date.formatted(date: .complete, time: .shortened), systemImage: "calendar") }
            Label("\(asset.pixelWidth) × \(asset.pixelHeight)", systemImage: "viewfinder")
            Label(AssetInfo.bytes(asset), systemImage: "externaldrive")
            Spacer()
        }.padding(24).frame(maxWidth: .infinity, alignment: .leading).background(Palette.background)
    }
}

@MainActor
private enum AssetInfo {
    static func bytes(_ asset: PHAsset) -> String { PhotoLibraryStore.byteString(PhotoLibraryStore.estimatedBytes(for: asset)) }
}

struct MemoriesView: View {
    @EnvironmentObject private var library: PhotoLibraryStore
    @State private var selectedPhoto: SelectedPhoto?
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("On this day").font(.system(size: 32, weight: .black, design: .rounded)).tracking(-1)
                    Text(Date.now.formatted(.dateTime.month(.wide).day())).font(.headline).foregroundStyle(Palette.peach)
                    Text("Photos from this date in your library, across the years.").font(.subheadline).foregroundStyle(.white.opacity(0.65))
                    if library.onThisDayAssets.isEmpty {
                        EmptyMessageView(title: "No memories today", icon: "sun.max", message: "When your library has photos from this date, they’ll show up here.")
                            .padding(.top, 40)
                    } else {
                        LazyVGrid(columns: columns, spacing: 5) {
                            ForEach(library.onThisDayAssets, id: \.localIdentifier) { asset in
                                Button { selectedPhoto = SelectedPhoto(asset: asset) } label: { AssetThumbnail(asset: asset, cornerRadius: 4).aspectRatio(1, contentMode: .fit).overlay(alignment: .bottomLeading) {
                                    if let date = asset.creationDate { Text(date.formatted(.dateTime.year())).font(.caption2.bold()).padding(4).background(.black.opacity(0.5), in: Capsule()).padding(4) }
                                } }.buttonStyle(.plain)
                            }
                        }
                    }
                }.padding(18)
            }.background(Palette.background).toolbar(.hidden, for: .navigationBar)
        }
        .sheet(item: $selectedPhoto) { photo in PhotoDetailSheet(asset: photo.asset) }
    }
}

struct BookmarksView: View {
    @EnvironmentObject private var library: PhotoLibraryStore
    @State private var selectedPhoto: SelectedPhoto?
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Bookmarks").font(.system(size: 32, weight: .black, design: .rounded)).tracking(-1)
                    Text("Save a photo to come back to it later.").font(.subheadline).foregroundStyle(.white.opacity(0.65))
                    if library.bookmarkedAssets.isEmpty {
                        EmptyMessageView(title: "Nothing saved yet", icon: "bookmark", message: "Tap the bookmark while swiping to set a photo aside.")
                            .padding(.top, 40)
                    } else {
                        LazyVGrid(columns: columns, spacing: 5) {
                            ForEach(library.bookmarkedAssets, id: \.localIdentifier) { asset in
                                Button { selectedPhoto = SelectedPhoto(asset: asset) } label: {
                                    AssetThumbnail(asset: asset, cornerRadius: 4).aspectRatio(1, contentMode: .fit)
                                        .overlay(alignment: .topTrailing) { Image(systemName: "bookmark.fill").font(.caption).foregroundStyle(Palette.mint).padding(6) }
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }.padding(18)
            }.background(Palette.background).toolbar(.hidden, for: .navigationBar)
        }
        .sheet(item: $selectedPhoto) { photo in PhotoDetailSheet(asset: photo.asset) }
    }
}

private struct SelectedPhoto: Identifiable {
    let asset: PHAsset
    var id: String { asset.localIdentifier }
}

struct PhotoDetailSheet: View {
    @EnvironmentObject private var library: PhotoLibraryStore
    @Environment(\.dismiss) private var dismiss
    let asset: PHAsset

    var body: some View {
        VStack(spacing: 14) {
            AssetThumbnail(asset: asset, contentMode: .aspectFit, cornerRadius: 12).frame(maxHeight: 360)
            if let date = asset.creationDate { Text(date.formatted(date: .complete, time: .shortened)).font(.subheadline).foregroundStyle(.white.opacity(0.7)) }
            Button { library.toggleBookmark(asset); dismiss() } label: {
                Label(library.isBookmarked(asset) ? "Remove Bookmark" : "Bookmark Photo", systemImage: library.isBookmarked(asset) ? "bookmark.slash" : "bookmark")
                    .font(.headline).foregroundStyle(.black).frame(maxWidth: .infinity).padding(15).background(Palette.mint, in: Capsule())
            }
        }.padding(20).background(Palette.background).presentationDetents([.medium, .large])
    }
}

struct StatsView: View {
    @EnvironmentObject private var library: PhotoLibraryStore
    private var completedCount: Int { library.completedMonthIDs.count }
    private var monthCount: Int { library.months.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Your progress").font(.system(size: 32, weight: .black, design: .rounded)).tracking(-1)
                    Text("A little lighter, one month at a time.").font(.subheadline).foregroundStyle(.white.opacity(0.65))
                    HStack(spacing: 12) {
                        StatTile(value: "\(library.deletedCount)", label: "photos deleted", color: Palette.peach)
                        StatTile(value: PhotoLibraryStore.byteString(library.savedBytes), label: "space saved", color: Palette.mint)
                    }
                    HStack(spacing: 12) {
                        StatTile(value: "\(completedCount)/\(monthCount)", label: "months finished", color: Palette.yellow)
                        StatTile(value: "\(library.bookmarkedIDs.count)", label: "bookmarks", color: Palette.teal)
                    }
                    Text("Months").font(.title3.bold()).padding(.top, 6)
                    ForEach(library.months) { month in
                        let progress = library.progress(for: month)
                        HStack {
                            Text(month.title).font(.headline)
                            Spacer()
                            if library.completedMonthIDs.contains(month.id) {
                                Text("DONE").font(.caption.bold()).foregroundStyle(Palette.mint)
                            } else {
                                Text("\(progress.done) / \(progress.total)").font(.subheadline.monospacedDigit()).foregroundStyle(.white.opacity(0.6))
                            }
                        }.padding(.vertical, 8)
                    }
                }.padding(18)
            }.background(Palette.background).toolbar(.hidden, for: .navigationBar)
        }
    }
}

struct StatTile: View {
    let value: String
    let label: String
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(value).font(.system(size: 25, weight: .black, design: .rounded)).minimumScaleFactor(0.7).lineLimit(1)
            Text(label).font(.caption.weight(.medium)).opacity(0.72)
        }.foregroundStyle(.black).frame(maxWidth: .infinity, alignment: .leading).padding(16)
            .background(color, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
    }
}

struct EmptyMessageView: View {
    let title: String
    let icon: String
    let message: String
    var body: some View {
        VStack(spacing: 11) {
            Image(systemName: icon).font(.system(size: 34, weight: .light)).foregroundStyle(Palette.peach)
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(.white.opacity(0.62)).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(24)
    }
}

struct ResultView: View {
    @EnvironmentObject private var library: PhotoLibraryStore
    let result: CleanupResult
    let returnHome: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Spacer()
                Text("success.").font(.system(size: 44, weight: .black, design: .rounded)).foregroundStyle(.white)
                Text("\(result.monthTitle)").font(.headline).foregroundStyle(.white.opacity(0.75))
                Spacer()
            }.frame(maxWidth: .infinity).frame(height: 220).background(Palette.orange)
            VStack(alignment: .leading, spacing: 22) {
                Text("\(result.count) \(result.count == 1 ? "photo" : "photos") deleted")
                    .font(.title3.weight(.semibold))
                Text("\(PhotoLibraryStore.byteString(result.bytes)) saved this round")
                    .font(.title3.weight(.semibold))
                Divider().overlay(.black.opacity(0.12))
                Text("\(library.deletedCount) photos deleted all time")
                Text("\(PhotoLibraryStore.byteString(library.savedBytes)) saved all time")
                    .foregroundStyle(.black.opacity(0.75))
                Spacer(minLength: 0)
                Button(action: returnHome) {
                    Text("Return Home").font(.system(size: 19, weight: .black, design: .rounded)).foregroundStyle(.black)
                        .frame(maxWidth: .infinity).padding(.vertical, 17).background(Palette.mint, in: Capsule())
                }
            }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).background(Palette.peach)
        }.ignoresSafeArea().preferredColorScheme(.light)
    }
}

struct EmptyLibraryCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled").font(.system(size: 32)).foregroundStyle(Palette.peach)
            Text("No photos to sort").font(.title3.bold())
            Text("If you chose limited access, add photos in Settings or grant access to more of your library.").font(.subheadline).foregroundStyle(.white.opacity(0.62)).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(30).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
    }
}
