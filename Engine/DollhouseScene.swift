import Foundation
import SwiftUI
import UIKit
import RealityKit
import simd
import OSLog

/// Builds and maintains the little dollhouse: a loaded room model parented under a turntable,
/// scaled to sit in the palm of your hand on a virtual tabletop, lit by a relightable rig.
///
/// The scene is deliberately framework-light on the SwiftUI side: `DollhouseView` owns a
/// `RealityView` and hands gestures + the lighting phase to this controller, which mutates the
/// RealityKit entity graph. Keeping all of RealityKit here means the views stay declarative.
@MainActor
final class DollhouseScene: ObservableObject {
    /// Root that everything hangs from; positioned so the maquette floats above the backdrop.
    let root = Entity()

    /// Turntable the model spins on (yaw from horizontal drags).
    private let turntable = Entity()

    /// The loaded room model, reparented under the turntable and recentred on its own bounds.
    private var modelEntity: Entity?

    /// Lighting rig.
    private let keyLight = DirectionalLight()
    private let fillLight = DirectionalLight()
    private var ambientEntity = Entity()

    /// Tiny props that glow at night (a lamp, a hearth). Faded in as the scene darkens.
    private var propLights: [PointLight] = []
    private var propEntities: [Entity] = []

    /// Current interaction state.
    private(set) var yaw: Float = 0.6      // a pleasing 3/4 starting angle
    private(set) var pitch: Float = -0.35  // tilt down to look into the room
    private(set) var modelScale: Float = 1.0
    private var baseScale: Float = 1.0     // auto-fit scale that frames the room in the palm

    /// How big the maquette should read on the tabletop (longest side, in metres).
    private let targetSize: Float = 0.34

    private(set) var isLoaded = false
    private(set) var propsEnabled = true

    init() {
        buildRig()
    }

    // MARK: - Scene construction

    private func buildRig() {
        root.addChild(turntable)

        // Key + fill directional lights, oriented later by the lighting phase.
        keyLight.light.intensity = 6000
        keyLight.shadow = DirectionalLightComponent.Shadow(maximumDistance: 4, depthBias: 2)
        root.addChild(keyLight)

        fillLight.light.intensity = 1200
        root.addChild(fillLight)

        // Apply an initial daylight-ish state so a freshly built scene is never black.
        apply(lighting: LightingState.at(phase: 0.34))
    }

    // MARK: - Loading a room

    /// Load a USDZ room model from disk, fit it into the palm, and centre it on the turntable.
    func load(url: URL) async {
        do {
            let loaded = try await Entity(contentsOf: url)
            // Drop any prior model.
            modelEntity?.removeFromParent()
            propEntities.forEach { $0.removeFromParent() }
            propLights.removeAll()
            propEntities.removeAll()

            // Recentre the model on its own visual bounds so it spins about its middle, and
            // auto-scale so the longest side reads at `targetSize` — the "in your palm" feel.
            let bounds = loaded.visualBounds(relativeTo: nil)
            let extents = bounds.extents
            let longest = max(extents.x, max(extents.y, extents.z))
            let fit = longest > 0 ? targetSize / longest : 1
            baseScale = fit

            let holder = Entity()
            holder.addChild(loaded)
            loaded.position = -bounds.center   // recentre about origin
            holder.scale = SIMD3(repeating: fit)
            turntable.addChild(holder)
            modelEntity = holder

            // Sprinkle a couple of tiny prop lights for the night mood.
            addProps(roomBounds: bounds, fit: fit)

            modelScale = 1.0
            applyTransform()
            isLoaded = true
            casteletLog.info("Loaded dollhouse model: \(url.lastPathComponent, privacy: .public)")
        } catch {
            casteletLog.error("Failed to load model: \(String(describing: error), privacy: .public)")
            isLoaded = false
        }
    }

    /// Drop a glowing lamp and a hearth ember into the room so night-time has little points of
    /// warmth — the toy-theatre touch.
    private func addProps(roomBounds: BoundingBox, fit: Float) {
        let c = roomBounds.center
        let e = roomBounds.extents

        // A warm "lamp" point light near one corner, slightly above the floor.
        let lamp = PointLight()
        lamp.light.color = UIColor(red: 1.0, green: 0.78, blue: 0.45, alpha: 1)
        lamp.light.intensity = 0
        lamp.light.attenuationRadius = max(e.x, e.z) * 0.9
        lamp.position = SIMD3(c.x + e.x * 0.32, roomBounds.min.y + e.y * 0.45, c.z + e.z * 0.28) - c
        lamp.position *= fit

        // A small glowing sphere so you can *see* the lamp, not just its light.
        let bulbMaterial = UnlitMaterial(color: UIColor(red: 1.0, green: 0.85, blue: 0.55, alpha: 1.0))
        let bulb = ModelEntity(mesh: .generateSphere(radius: 0.006), materials: [bulbMaterial])
        bulb.position = lamp.position

        // A hearth ember on the opposite side.
        let hearth = PointLight()
        hearth.light.color = UIColor(red: 1.0, green: 0.5, blue: 0.2, alpha: 1)
        hearth.light.intensity = 0
        hearth.light.attenuationRadius = max(e.x, e.z) * 0.7
        hearth.position = SIMD3(c.x - e.x * 0.34, roomBounds.min.y + e.y * 0.12, c.z - e.z * 0.30) - c
        hearth.position *= fit

        for node in [lamp as Entity, bulb as Entity, hearth as Entity] {
            turntable.addChild(node)
            propEntities.append(node)
        }
        propLights = [lamp, hearth]
        applyPropIntensity(darkness: 0)
    }

    // MARK: - Lighting

    /// Apply an interpolated lighting state to the rig.
    func apply(lighting state: LightingState) {
        keyLight.light.color = uiColor(state.keyColor)
        keyLight.light.intensity = state.keyIntensity
        keyLight.orientation = directionalOrientation(azimuth: state.keyAzimuth, elevation: state.keyElevation)

        // Fill comes from the opposite side, softer and tinted toward ambient.
        fillLight.light.color = uiColor(state.ambientColor)
        fillLight.light.intensity = state.ambientIntensity
        fillLight.orientation = directionalOrientation(azimuth: state.keyAzimuth + .pi, elevation: 0.5)

        applyPropIntensity(darkness: state.darkness)
    }

    private func applyPropIntensity(darkness: Double) {
        guard propsEnabled else {
            propLights.forEach { $0.light.intensity = 0 }
            propEntities.forEach { $0.isEnabled = $0 is PointLight ? true : false }
            return
        }
        // Lamps glow from dusk into night; invisible at midday.
        let glow = Float(max(0, (darkness - 0.4) / 0.6))
        if propLights.count >= 1 { propLights[0].light.intensity = 5200 * glow }
        if propLights.count >= 2 { propLights[1].light.intensity = 3000 * glow }
    }

    /// Toggle the tiny props on/off.
    func setProps(enabled: Bool, darkness: Double) {
        propsEnabled = enabled
        propEntities.forEach { $0.isEnabled = enabled }
        applyPropIntensity(darkness: darkness)
    }

    // MARK: - Interaction

    func rotate(deltaYaw: Float, deltaPitch: Float) {
        yaw += deltaYaw
        pitch = min(max(pitch + deltaPitch, -1.45), 0.2)   // clamp so you can't flip under the floor
        applyTransform()
    }

    func zoom(scale: Float) {
        modelScale = min(max(scale, 0.4), 3.2)
        applyTransform()
    }

    /// Reset to the pleasing default 3/4 view.
    func resetView() {
        yaw = 0.6
        pitch = -0.35
        modelScale = 1.0
        applyTransform()
    }

    private func applyTransform() {
        turntable.transform.rotation =
            simd_quatf(angle: pitch, axis: SIMD3(1, 0, 0)) *
            simd_quatf(angle: yaw, axis: SIMD3(0, 1, 0))
        turntable.scale = SIMD3(repeating: modelScale)
    }

    // MARK: - Helpers

    private func uiColor(_ rgb: SIMD3<Float>) -> UIColor {
        UIColor(red: CGFloat(rgb.x), green: CGFloat(rgb.y), blue: CGFloat(rgb.z), alpha: 1)
    }

    /// Build an orientation that points a directional light from the given azimuth/elevation.
    private func directionalOrientation(azimuth: Float, elevation: Float) -> simd_quatf {
        // Start pointing straight down (-Y), then rotate up to elevation and around to azimuth.
        let pitchRot = simd_quatf(angle: -(.pi / 2 - elevation), axis: SIMD3(1, 0, 0))
        let yawRot = simd_quatf(angle: azimuth, axis: SIMD3(0, 1, 0))
        return yawRot * pitchRot
    }
}
