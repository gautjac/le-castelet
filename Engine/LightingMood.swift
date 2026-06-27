import SwiftUI
import simd

/// The four moods on the day→night slider. The dollhouse relights as the slider sweeps from
/// dawn through to deep night, the same room changing character without re-scanning.
///
/// Each mood carries everything the RealityKit scene needs to express it: the directional
/// "sun" colour and intensity, an ambient fill, the angle the key light rakes in at, and the
/// warm/cool tint of the surrounding studio backdrop. The scene interpolates between adjacent
/// moods so dragging the slider is a continuous dissolve, not four hard steps.
enum LightingMood: Int, CaseIterable, Identifiable {
    case dawn      // 0.00 — cool blue morning
    case midday    // 0.33 — bright neutral daylight
    case dusk      // 0.66 — warm amber golden hour
    case night     // 1.00 — deep indigo, lamp-lit

    var id: Int { rawValue }

    /// The slider position (0…1) this mood sits at.
    var phase: Double {
        switch self {
        case .dawn:   return 0.0
        case .midday: return 0.34
        case .dusk:   return 0.68
        case .night:  return 1.0
        }
    }

    var label: String {
        switch self {
        case .dawn:   return "Aube"
        case .midday: return "Midi"
        case .dusk:   return "Crépuscule"
        case .night:  return "Nuit"
        }
    }

    var symbol: String {
        switch self {
        case .dawn:   return "sunrise.fill"
        case .midday: return "sun.max.fill"
        case .dusk:   return "sunset.fill"
        case .night:  return "moon.stars.fill"
        }
    }

    // MARK: - Light parameters (linear RGB 0…1)

    /// Colour of the directional key light.
    var keyColor: SIMD3<Float> {
        switch self {
        case .dawn:   return SIMD3(0.78, 0.83, 1.00)   // cool morning blue
        case .midday: return SIMD3(1.00, 0.99, 0.95)   // crisp neutral
        case .dusk:   return SIMD3(1.00, 0.74, 0.45)   // amber gold
        case .night:  return SIMD3(0.55, 0.62, 0.92)   // moon indigo
        }
    }

    /// Directional light intensity (lux-ish, RealityKit units).
    var keyIntensity: Float {
        switch self {
        case .dawn:   return 4200
        case .midday: return 9000
        case .dusk:   return 5200
        case .night:  return 1500
        }
    }

    /// Ambient fill colour.
    var ambientColor: SIMD3<Float> {
        switch self {
        case .dawn:   return SIMD3(0.42, 0.48, 0.62)
        case .midday: return SIMD3(0.62, 0.64, 0.66)
        case .dusk:   return SIMD3(0.52, 0.40, 0.34)
        case .night:  return SIMD3(0.16, 0.20, 0.34)
        }
    }

    var ambientIntensity: Float {
        switch self {
        case .dawn:   return 1600
        case .midday: return 3000
        case .dusk:   return 1700
        case .night:  return 600
        }
    }

    /// Compass-ish azimuth (radians) the key light rakes in from, so the shadows sweep across
    /// the room as the day passes.
    var keyAzimuth: Float {
        switch self {
        case .dawn:   return -1.1
        case .midday: return  0.1
        case .dusk:   return  1.2
        case .night:  return  0.6
        }
    }

    /// Elevation (radians) of the key light above the horizon — low at the ends of the day,
    /// high at noon.
    var keyElevation: Float {
        switch self {
        case .dawn:   return 0.35
        case .midday: return 1.15
        case .dusk:   return 0.30
        case .night:  return 0.55
        }
    }

    /// Backdrop / "studio table" colours, top and bottom of the gradient behind the maquette.
    var backdropTop: Color {
        switch self {
        case .dawn:   return Color(red: 0.74, green: 0.82, blue: 0.93)
        case .midday: return Color(red: 0.86, green: 0.90, blue: 0.95)
        case .dusk:   return Color(red: 0.96, green: 0.74, blue: 0.52)
        case .night:  return Color(red: 0.10, green: 0.12, blue: 0.24)
        }
    }

    var backdropBottom: Color {
        switch self {
        case .dawn:   return Color(red: 0.50, green: 0.58, blue: 0.74)
        case .midday: return Color(red: 0.62, green: 0.68, blue: 0.78)
        case .dusk:   return Color(red: 0.70, green: 0.42, blue: 0.40)
        case .night:  return Color(red: 0.04, green: 0.05, blue: 0.12)
        }
    }
}

/// A fully-interpolated lighting state for an arbitrary slider phase (0…1). Blends between the
/// two nearest moods so the relight is a smooth dissolve.
struct LightingState {
    var keyColor: SIMD3<Float>
    var keyIntensity: Float
    var ambientColor: SIMD3<Float>
    var ambientIntensity: Float
    var keyAzimuth: Float
    var keyElevation: Float
    var backdropTop: Color
    var backdropBottom: Color
    /// The mood the slider is closest to — used for the on-screen label.
    var nearestMood: LightingMood

    /// Build the interpolated state for a slider phase in 0…1.
    static func at(phase rawPhase: Double) -> LightingState {
        let phase = min(max(rawPhase, 0), 1)
        let moods = LightingMood.allCases

        // Find the two moods bracketing `phase`.
        var lower = moods[0]
        var upper = moods[moods.count - 1]
        for i in 0..<(moods.count - 1) {
            if phase >= moods[i].phase && phase <= moods[i + 1].phase {
                lower = moods[i]
                upper = moods[i + 1]
                break
            }
        }

        let span = upper.phase - lower.phase
        let t = Float(span > 0 ? (phase - lower.phase) / span : 0)

        let nearest = t < 0.5 ? lower : upper

        return LightingState(
            keyColor: mix(lower.keyColor, upper.keyColor, t),
            keyIntensity: mixF(lower.keyIntensity, upper.keyIntensity, t),
            ambientColor: mix(lower.ambientColor, upper.ambientColor, t),
            ambientIntensity: mixF(lower.ambientIntensity, upper.ambientIntensity, t),
            keyAzimuth: mixF(lower.keyAzimuth, upper.keyAzimuth, t),
            keyElevation: mixF(lower.keyElevation, upper.keyElevation, t),
            backdropTop: blend(lower.backdropTop, upper.backdropTop, Double(t)),
            backdropBottom: blend(lower.backdropBottom, upper.backdropBottom, Double(t)),
            nearestMood: nearest
        )
    }

    /// How "dark" the scene is, 0 (bright) … 1 (night). Used to fade tiny prop lights in.
    var darkness: Double {
        let p = Double(nearestMood.phase)
        return min(max(p, 0), 1)
    }

    // MARK: - Interpolation helpers

    private static func mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ t: Float) -> SIMD3<Float> {
        a + (b - a) * t
    }
    private static func mixF(_ a: Float, _ b: Float, _ t: Float) -> Float {
        a + (b - a) * t
    }
    private static func blend(_ a: Color, _ b: Color, _ t: Double) -> Color {
        let ca = a.rgbaComponents
        let cb = b.rgbaComponents
        return Color(
            red:   ca.r + (cb.r - ca.r) * t,
            green: ca.g + (cb.g - ca.g) * t,
            blue:  ca.b + (cb.b - ca.b) * t
        )
    }
}

private extension Color {
    /// Resolve to sRGB components for blending. Falls back to mid-grey if resolution fails.
    var rgbaComponents: (r: Double, g: Double, b: Double, a: Double) {
        #if canImport(UIKit)
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if ui.getRed(&r, green: &g, blue: &b, alpha: &a) {
            return (Double(r), Double(g), Double(b), Double(a))
        }
        #endif
        return (0.5, 0.5, 0.5, 1)
    }
}
