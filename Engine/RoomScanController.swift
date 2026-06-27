import Foundation
import SwiftUI
import OSLog

#if canImport(RoomPlan)
import RoomPlan
#endif

/// Drives a RoomPlan capture session and turns the finished `CapturedRoom` into a USDZ model
/// on disk, ready for the dollhouse.
///
/// Everything RoomPlan touches is guarded two ways:
///   * the whole framework is wrapped in `#if canImport(RoomPlan)`, so a toolchain without it
///     still compiles, and
///   * at runtime we check `RoomCaptureSession.isSupported` (a device with LiDAR running a
///     supported OS). When unsupported we never construct a session — the UI offers the
///     bundled sample room instead. The app never crashes on unsupported hardware.
@MainActor
final class RoomScanController: ObservableObject {
    enum Phase: Equatable {
        case idle          // ready, not yet scanning
        case scanning      // capture in progress
        case processing    // post-processing the captured room
        case finished      // model written to disk
        case failed(String)
    }

    @Published var phase: Phase = .idle

    /// Whether this device can actually scan a room.
    static var isSupported: Bool {
        #if canImport(RoomPlan) && !targetEnvironment(simulator)
        if #available(iOS 16.0, *) {
            return RoomCaptureSession.isSupported
        }
        return false
        #else
        return false
        #endif
    }

    #if canImport(RoomPlan)
    /// The most recently captured room, retained so we can export it after the session ends.
    @available(iOS 16.0, *)
    private var capturedRoom: CapturedRoom? {
        get { _capturedRoom as? CapturedRoom }
        set { _capturedRoom = newValue }
    }
    private var _capturedRoom: Any?
    #endif

    // MARK: - Export

    /// Write the captured room to a USDZ file for the given room UUID, returning the metrics
    /// the galerie card displays. Throws if there is nothing captured or the export fails.
    @discardableResult
    func exportCapturedRoom(uuid: UUID) async throws -> RoomMetrics {
        #if canImport(RoomPlan)
        guard #available(iOS 16.0, *), let room = capturedRoom else {
            throw ScanError.nothingCaptured
        }
        let url = CasteletStorage.newModelURL(for: uuid)
        // RoomPlan exports a parametric USDZ describing walls, openings and detected objects.
        try room.export(to: url, exportOptions: .parametric)
        let metrics = RoomMetrics(captured: room)
        casteletLog.info("Exported room to \(url.lastPathComponent, privacy: .public)")
        return metrics
        #else
        throw ScanError.unsupported
        #endif
    }

    enum ScanError: LocalizedError {
        case unsupported
        case nothingCaptured

        var errorDescription: String? {
            switch self {
            case .unsupported:     return "La numérisation de pièce n'est pas disponible sur cet appareil."
            case .nothingCaptured: return "Aucune pièce n'a été capturée."
            }
        }
    }

    #if canImport(RoomPlan)
    @available(iOS 16.0, *)
    func store(capturedRoom room: CapturedRoom) {
        self.capturedRoom = room
    }
    #endif
}

/// Lightweight, framework-free metrics extracted from a captured room, so the rest of the app
/// (cards, save flow) never needs to import RoomPlan.
struct RoomMetrics {
    var floorArea: Double = 0
    var wallCount: Int = 0
    var objectCount: Int = 0

    init() {}

    #if canImport(RoomPlan)
    @available(iOS 16.0, *)
    init(captured room: CapturedRoom) {
        wallCount = room.walls.count
        objectCount = room.objects.count
        // Approximate floor area from the bounding footprint of the floor surfaces.
        var area: Double = 0
        for floor in room.floors {
            let dims = floor.dimensions
            area += Double(dims.x * dims.z)
        }
        // If RoomPlan reported no explicit floor, fall back to the wall footprint extent.
        if area == 0, !room.walls.isEmpty {
            var minX = Float.greatestFiniteMagnitude, maxX = -Float.greatestFiniteMagnitude
            var minZ = Float.greatestFiniteMagnitude, maxZ = -Float.greatestFiniteMagnitude
            for wall in room.walls {
                let t = wall.transform
                let px = t.columns.3.x, pz = t.columns.3.z
                minX = min(minX, px); maxX = max(maxX, px)
                minZ = min(minZ, pz); maxZ = max(maxZ, pz)
            }
            area = Double(max(0, (maxX - minX)) * max(0, (maxZ - minZ)))
        }
        floorArea = area
    }
    #endif
}
