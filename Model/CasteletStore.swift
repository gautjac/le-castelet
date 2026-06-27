import Foundation
import SwiftData
import OSLog

let casteletLog = Logger(subsystem: "com.jac.LeCastelet", category: "store")

/// The single source of truth for the app's data — one local `ModelContainer` shared by
/// every scene.
///
/// This app keeps its store **local only** (no CloudKit): the heavy 3-D models live as files
/// in Application Support and SwiftData just holds their metadata, so there is no sync surface
/// to manage. The container degrades gracefully — if the on-disk store can't be opened for any
/// reason we fall back to an in-memory store so the app still launches instead of crashing.
enum CasteletStore {
    static let shared: ModelContainer = makeContainer()

    private static func makeContainer() -> ModelContainer {
        let schema = Schema([Castelet.self])
        let candidates: [(String, ModelConfiguration)] = [
            ("local", ModelConfiguration("LeCastelet", schema: schema, cloudKitDatabase: .none)),
            ("in-memory", ModelConfiguration("LeCastelet", schema: schema, isStoredInMemoryOnly: true)),
        ]
        for (label, config) in candidates {
            do {
                let container = try ModelContainer(for: schema, configurations: config)
                casteletLog.info("Opened store: \(label, privacy: .public)")
                return container
            } catch {
                casteletLog.error("Store '\(label, privacy: .public)' unavailable: \(String(describing: error), privacy: .public)")
            }
        }
        fatalError("Could not open any ModelContainer for the Castelet schema")
    }
}
