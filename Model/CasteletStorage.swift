import Foundation
import UIKit
import OSLog

/// Manages the on-disk USDZ models that back each saved room.
///
/// Models live in `Application Support/Castelets/` — a durable, non-purgeable location that is
/// excluded from iCloud backup chatter and survives relaunches. SwiftData stores only the
/// filename; this type resolves it to a live URL, so the app keeps working even if the
/// container's absolute path changes between installs.
enum CasteletStorage {
    /// `Application Support/Castelets`, created on first access.
    static var modelsDirectory: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Castelets", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            } catch {
                casteletLog.error("Could not create models dir: \(String(describing: error), privacy: .public)")
            }
        }
        return dir
    }

    /// Destination URL for a freshly captured model, named by its room's UUID.
    static func newModelURL(for uuid: UUID) -> URL {
        modelsDirectory.appendingPathComponent("\(uuid.uuidString).usdz")
    }

    /// Resolve a stored filename to a live on-disk URL, or `nil` if the file is gone.
    static func existingModelURL(filename: String) -> URL? {
        guard !filename.isEmpty else { return nil }
        let url = modelsDirectory.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Delete a room's model file from disk. Sample rooms are never deleted here (their model
    /// lives read-only in the bundle, not in this directory).
    static func deleteModel(filename: String) {
        guard let url = existingModelURL(filename: filename) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Bundled sample room

    /// The sample room shipped inside the app bundle, so the dollhouse experience is fully
    /// demoable on hardware that can't scan (Simulator, non-LiDAR devices).
    static var bundledSampleURL: URL? {
        Bundle.main.url(forResource: "SampleRoom", withExtension: "usdz")
    }
}
