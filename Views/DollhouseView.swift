import SwiftUI
import RealityKit
import SwiftData

/// The signature screen: the scanned room held as a small, spinnable maquette on a tabletop,
/// relightable from dawn to deep night. Drag to turn it in your hands, pinch to zoom, sweep
/// the slider to change the hour.
struct DollhouseView: View {
    let room: Castelet

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @StateObject private var scene = DollhouseScene()
    @State private var phase: Double = 0.25
    @State private var loadFailed = false
    @State private var showProps = true

    // Gesture accumulators
    @State private var gestureYaw: Float = 0
    @State private var gesturePitch: Float = 0
    @State private var gestureScale: Float = 1

    private var lighting: LightingState { LightingState.at(phase: phase) }

    var body: some View {
        ZStack {
            // Backdrop gradient relit by the current mood — the "studio table" behind the maquette.
            LinearGradient(
                colors: [lighting.backdropTop, lighting.backdropBottom],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.35), value: phase)

            if loadFailed {
                failureView
            } else {
                dollhouse
            }

            VStack {
                topBar
                Spacer()
                if !loadFailed {
                    controlPanel
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .task {
            phase = room.lastLightingPhase
            guard let url = room.resolvedModelURL else {
                loadFailed = true
                return
            }
            await scene.load(url: url)
            loadFailed = !scene.isLoaded
            scene.apply(lighting: LightingState.at(phase: phase))
        }
        .onChange(of: phase) { _, newValue in
            scene.apply(lighting: LightingState.at(phase: newValue))
        }
        .onDisappear {
            room.lastLightingPhase = phase
            try? context.save()
        }
        .statusBarHidden(true)
    }

    // MARK: - The RealityKit maquette

    private var dollhouse: some View {
        RealityView { content in
            // A camera framing the tabletop maquette at a comfortable distance.
            let camera = PerspectiveCamera()
            camera.camera.fieldOfViewInDegrees = 38
            camera.position = SIMD3(0, 0.14, 0.62)
            camera.look(at: SIMD3(0, 0, 0), from: camera.position, relativeTo: nil)
            content.add(camera)
            content.add(scene.root)
        }
        .gesture(rotationDrag)
        .simultaneousGesture(zoomPinch)
        .ignoresSafeArea()
    }

    private var rotationDrag: some Gesture {
        DragGesture()
            .onChanged { value in
                let dy = Float(value.translation.width) * 0.006 - gestureYaw
                let dp = Float(value.translation.height) * 0.006 - gesturePitch
                scene.rotate(deltaYaw: dy, deltaPitch: dp)
                gestureYaw += dy
                gesturePitch += dp
            }
            .onEnded { _ in
                gestureYaw = 0
                gesturePitch = 0
            }
    }

    private var zoomPinch: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scene.zoom(scale: gestureScale * Float(value.magnification))
            }
            .onEnded { value in
                gestureScale = min(max(gestureScale * Float(value.magnification), 0.4), 3.2)
            }
    }

    // MARK: - Chrome

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.headline.weight(.bold))
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            Spacer()
            Text(room.displayName)
                .font(.playbill(18, weight: .semibold))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
            Spacer()
            Button { scene.resetView() } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.headline.weight(.bold))
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Recentrer la vue")
        }
        .foregroundStyle(Theme.inkC)
        .padding(.top, 8)
    }

    private var controlPanel: some View {
        VStack(spacing: 14) {
            // Mood label + props toggle.
            HStack {
                Label(lighting.nearestMood.label, systemImage: lighting.nearestMood.symbol)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    showProps.toggle()
                    scene.setProps(enabled: showProps, darkness: lighting.darkness)
                } label: {
                    Image(systemName: showProps ? "lightbulb.fill" : "lightbulb.slash")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(showProps ? Theme.footlightC : Theme.secondaryC)
                }
                .accessibilityLabel("Petites lampes")
            }
            .foregroundStyle(Theme.inkC)

            // The day→night relight slider.
            HStack(spacing: 12) {
                Image(systemName: "sunrise.fill").foregroundStyle(Theme.secondaryC)
                Slider(value: $phase, in: 0...1)
                    .tint(Theme.brassC)
                Image(systemName: "moon.stars.fill").foregroundStyle(Theme.secondaryC)
            }

            // Quick-jump mood chips.
            HStack(spacing: 8) {
                ForEach(LightingMood.allCases) { mood in
                    Button {
                        withAnimation(.easeInOut(duration: 0.4)) { phase = mood.phase }
                    } label: {
                        Text(mood.label)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(
                                Capsule().fill(
                                    abs(phase - mood.phase) < 0.08
                                        ? Theme.velvetC : Theme.faintC.opacity(0.4)
                                )
                            )
                            .foregroundStyle(
                                abs(phase - mood.phase) < 0.08 ? Color.white : Theme.inkC
                            )
                    }
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Theme.brassC.opacity(0.35), lineWidth: 1)
        )
    }

    private var failureView: some View {
        VStack(spacing: 16) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.8))
            Text("Maquette introuvable")
                .font(.playbill(20))
                .foregroundStyle(.white)
            Text("Le modèle 3D de cette pièce est manquant.")
                .font(.body)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            Button("Retour") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(Theme.velvetC)
        }
        .padding(40)
    }
}
