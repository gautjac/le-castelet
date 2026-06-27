import Foundation
import SwiftData
import UIKit

/// Seeds the bundled sample room into the galerie once, so a fresh install (or a device that
/// can't scan) immediately has something to hold as a dollhouse.
///
/// The sample's model is read straight from the bundle via `CasteletStorage.bundledSampleURL`,
/// so we don't copy the USDZ into Application Support — the `Castelet` record simply points at
/// the bundle resource through a sentinel filename the storage layer understands.
enum SampleSeeder {
    /// Sentinel filename meaning "this room's model is the bundled sample, resolved from the
    /// app bundle, not from Application Support."
    static let bundledFilename = "__bundled_sample__"

    @MainActor
    static func seedIfNeeded(into context: ModelContext) {
        let descriptor = FetchDescriptor<Castelet>(predicate: #Predicate { $0.isSample == true })
        let existing = (try? context.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }

        let sample = Castelet(
            name: "Le petit salon (exemple)",
            modelFilename: bundledFilename,
            thumbnailData: nil,
            floorAreaSquareMetres: 14.2,
            wallCount: 4,
            objectCount: 5,
            isSample: true
        )
        context.insert(sample)
        try? context.save()
    }
}

extension Castelet {
    /// Resolve the model URL, accounting for the bundled-sample sentinel.
    var resolvedModelURL: URL? {
        if modelFilename == SampleSeeder.bundledFilename {
            return CasteletStorage.bundledSampleURL
        }
        return CasteletStorage.existingModelURL(filename: modelFilename)
    }
}
