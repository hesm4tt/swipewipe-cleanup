import CryptoKit
import Foundation
import SwiftUI

struct DiagnosticRecord: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let event: String
    let details: [String: String]

    var formattedDetails: String {
        details.keys.sorted().map { "\($0)=\(details[$0] ?? "")" }.joined(separator: "  ")
    }
}

@MainActor
final class DiagnosticLog: ObservableObject {
    static let shared = DiagnosticLog()

    @Published private(set) var records: [DiagnosticRecord]

    private let defaults = UserDefaults.standard
    private static let recordsKey = "swipewipe.diagnostics.v1"
    private static let saltKey = "swipewipe.diagnostics.asset-salt.v1"
    private let maximumRecords = 500
    private let assetSalt: String

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.recordsKey),
           let saved = try? JSONDecoder().decode([DiagnosticRecord].self, from: data) {
            records = saved
        } else {
            records = []
        }

        if let savedSalt = UserDefaults.standard.string(forKey: Self.saltKey) {
            assetSalt = savedSalt
        } else {
            let newSalt = UUID().uuidString
            assetSalt = newSalt
            UserDefaults.standard.set(newSalt, forKey: Self.saltKey)
        }
    }

    func record(_ event: String, details: [String: String] = [:]) {
        let safeDetails = details.mapValues { $0.replacingOccurrences(of: "\n", with: " ") }
        records.append(DiagnosticRecord(id: UUID(), timestamp: Date(), event: event, details: safeDetails))
        if records.count > maximumRecords {
            records.removeFirst(records.count - maximumRecords)
        }
        persist()
    }

    func assetTag(for localIdentifier: String) -> String {
        let bytes = Data("\(assetSalt)|\(localIdentifier)".utf8)
        let digest = SHA256.hash(data: bytes)
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    var exportText: String {
        let formatter = ISO8601DateFormatter()
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        let header = [
            "Swipewipe Cleanup diagnostics",
            "App version: \(appVersion) (\(build))",
            "Photo references are salted hashes; photo content and raw Photos identifiers are not logged. Month labels identify review sessions.",
            ""
        ]
        let lines = records.map { record in
            let details = record.formattedDetails
            return "\(formatter.string(from: record.timestamp))  \(record.event)\(details.isEmpty ? "" : "  \(details)")"
        }
        return (header + lines).joined(separator: "\n")
    }

    func clear() {
        records.removeAll()
        defaults.removeObject(forKey: Self.recordsKey)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: Self.recordsKey)
    }
}

struct DiagnosticsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var diagnostics = DiagnosticLog.shared
    @State private var showingClearConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Recent app events help trace which photo was shown, which action was recorded, and what entered the deletion request. Logs stay on this device unless you choose Export.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    HStack {
                        ShareLink(item: diagnostics.exportText) {
                            Label("Export logs", systemImage: "square.and.arrow.up")
                        }
                        Spacer()
                        Button("Clear", role: .destructive) { showingClearConfirmation = true }
                    }
                }

                Section("Recent events · \(diagnostics.records.count)") {
                    if diagnostics.records.isEmpty {
                        Text("No diagnostic events yet.").foregroundStyle(.secondary)
                    } else {
                        ForEach(diagnostics.records.reversed()) { record in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(record.event).font(.subheadline.weight(.semibold))
                                    Spacer(minLength: 8)
                                    Text(record.timestamp.formatted(date: .numeric, time: .standard))
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                if !record.formattedDetails.isEmpty {
                                    Text(record.formattedDetails)
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                }
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
            }
            .navigationTitle("Diagnostics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Clear diagnostic logs?", isPresented: $showingClearConfirmation, titleVisibility: .visible) {
                Button("Clear Logs", role: .destructive) { diagnostics.clear() }
                Button("Cancel", role: .cancel) { }
            }
        }
    }
}
