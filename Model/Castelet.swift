import Foundation
import SwiftData

/// A saved room — one little maquette in the galerie.
///
/// The heavy 3-D payload (the USDZ model the dollhouse renders) lives on disk in the app's
/// Application Support directory, not in SwiftData, because USDZ files are far too large to
/// store comfortably in a SQLite-backed store. SwiftData holds only the lightweight
/// metadata plus the filename that points at the model on disk. The thumbnail is small
/// enough (a downsized PNG) to keep inline as `externalStorage` data.
///
/// The model follows the same local-store rules the Atelier house pattern uses: every stored
/// property has a default value and the identifier is a plain `UUID`, so the schema stays
/// trivially migratable and CloudKit-ready should sync ever be switched on.
@Model
final class Castelet {
    /// Stable identity, also used to derive the on-disk model filename.
    var uuid: UUID = UUID()

    /// User-facing name, e.g. "Le salon", "La chambre".
    var name: String = ""

    var createdAt: Date = Date.now

    /// Filename (not a full path) of the USDZ model inside the app's models directory.
    /// Resolved through `CasteletStorage.modelURL(for:)` so the container can move between
    /// app sandboxes (upgrades, restores) without breaking the link.
    var modelFilename: String = ""

    /// A small PNG snapshot of the dollhouse, shown in the galerie grid. Kept inline but in
    /// external storage so the store file stays lean.
    @Attribute(.externalStorage) var thumbnailData: Data? = nil

    /// Rough metrics the scanner reported, surfaced as little stats on the card.
    var floorAreaSquareMetres: Double = 0
    var wallCount: Int = 0
    var objectCount: Int = 0

    /// Where on the day→night slider this room was last left (0 = dawn, 1 = deep night).
    var lastLightingPhase: Double = 0.25

    /// Marks the bundled demo room so the galerie can label it and never let the user delete
    /// the file out from under the bundle.
    var isSample: Bool = false

    init(
        uuid: UUID = UUID(),
        name: String = "",
        modelFilename: String = "",
        thumbnailData: Data? = nil,
        floorAreaSquareMetres: Double = 0,
        wallCount: Int = 0,
        objectCount: Int = 0,
        isSample: Bool = false,
        createdAt: Date = .now
    ) {
        self.uuid = uuid
        self.name = name
        self.modelFilename = modelFilename
        self.thumbnailData = thumbnailData
        self.floorAreaSquareMetres = floorAreaSquareMetres
        self.wallCount = wallCount
        self.objectCount = objectCount
        self.isSample = isSample
        self.createdAt = createdAt
    }

    /// Display name with a graceful fallback.
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Pièce sans nom" : trimmed
    }

    /// Resolved on-disk URL of the USDZ model, or `nil` if the file is missing.
    var modelURL: URL? {
        CasteletStorage.existingModelURL(filename: modelFilename)
    }
}
