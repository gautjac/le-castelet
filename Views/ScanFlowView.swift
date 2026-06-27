import SwiftUI
import SwiftData

/// Orchestrates capturing a new room. On a LiDAR device it presents RoomPlan's live scanner;
/// elsewhere it shows a graceful explanation and lets the user add the bundled sample room so
/// the dollhouse experience is never blocked by hardware.
struct ScanFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @StateObject private var controller = RoomScanController()
    @State private var stopTrigger = false
    @State private var didScan = false
    @State private var saving = false
    @State private var roomName = ""
    @State private var showNamePrompt = false
    @State private var pendingMetrics = RoomMetrics()
    @State private var pendingUUID = UUID()
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if RoomScanController.isSupported {
                scannerFlow
            } else {
                UnsupportedFallbackView(
                    onAddSample: addSample,
                    onClose: { dismiss() }
                )
            }
        }
        .alert("Nommer la pièce", isPresented: $showNamePrompt) {
            TextField("Le salon, la chambre…", text: $roomName)
            Button("Annuler", role: .cancel) { dismiss() }
            Button("Enregistrer") { finishSave() }
        } message: {
            Text("Votre maquette est prête.")
        }
        .alert("Numérisation", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Live scanner (LiDAR devices)

    @ViewBuilder
    private var scannerFlow: some View {
        #if canImport(RoomPlan) && !targetEnvironment(simulator)
        if #available(iOS 16.0, *) {
            ZStack {
                RoomCaptureViewRep(
                    controller: controller,
                    stopTrigger: stopTrigger,
                    onFinished: handleScanFinished
                )
                .ignoresSafeArea()

                VStack {
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.headline.weight(.bold))
                                .padding(12)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        Spacer()
                    }
                    .padding()

                    Spacer()

                    instructionBanner

                    Button {
                        stopTrigger = true
                    } label: {
                        Label("Terminé", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.velvetC)
                    .disabled(controller.phase == .processing || saving)
                    .padding()
                }

                if controller.phase == .processing || saving {
                    processingOverlay
                }
            }
        } else {
            UnsupportedFallbackView(onAddSample: addSample, onClose: { dismiss() })
        }
        #else
        UnsupportedFallbackView(onAddSample: addSample, onClose: { dismiss() })
        #endif
    }

    private var instructionBanner: some View {
        Text("Balayez lentement la pièce — murs, ouvertures et meubles.")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.bottom, 8)
    }

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView().controlSize(.large).tint(.white)
                Text("On monte la maquette…")
                    .font(.playbill(18))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Outcomes

    private func handleScanFinished(_ success: Bool) {
        guard success else {
            if case let .failed(msg) = controller.phase { errorMessage = msg }
            else { errorMessage = "La numérisation a échoué." }
            return
        }
        Task {
            saving = true
            do {
                pendingUUID = UUID()
                let metrics = try await controller.exportCapturedRoom(uuid: pendingUUID)
                pendingMetrics = metrics
                saving = false
                roomName = ""
                showNamePrompt = true
            } catch {
                saving = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func finishSave() {
        let filename = "\(pendingUUID.uuidString).usdz"
        let castelet = Castelet(
            uuid: pendingUUID,
            name: roomName,
            modelFilename: filename,
            floorAreaSquareMetres: pendingMetrics.floorArea,
            wallCount: pendingMetrics.wallCount,
            objectCount: pendingMetrics.objectCount
        )
        context.insert(castelet)
        // Render a thumbnail off the saved model in the background.
        let url = CasteletStorage.existingModelURL(filename: filename)
        try? context.save()
        if let url {
            ThumbnailRenderer.render(modelURL: url) { data in
                castelet.thumbnailData = data
                try? context.save()
            }
        }
        dismiss()
    }

    // MARK: - Fallback: add the bundled sample

    private func addSample() {
        // Ensure a sample exists (it normally seeds on launch); if the user deleted it or it
        // never seeded, re-create it here so the fallback always yields a usable room.
        SampleSeeder.seedIfNeeded(into: context)
        dismiss()
    }
}

/// Shown on devices that can't scan (Simulator, non-LiDAR). Explains why, and offers the
/// bundled sample room so the dollhouse + relight experience is fully demoable.
private struct UnsupportedFallbackView: View {
    var onAddSample: () -> Void
    var onClose: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.velvetDeepC, .black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "iphone.gen3.slash")
                    .font(.system(size: 60))
                    .foregroundStyle(Theme.brassC)
                Text("Numérisation indisponible")
                    .font(.playbill(24))
                    .foregroundStyle(.white)
                Text("La numérisation de pièce demande un appareil\néquipé d'un capteur LiDAR (iPhone Pro / iPad Pro).\nLe simulateur ne peut pas numériser.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.85))

                Button(action: onAddSample) {
                    Label("Ouvrir la pièce d'exemple", systemImage: "sparkles")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.velvetC)
                .padding(.top, 6)

                Button("Fermer", action: onClose)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(32)
        }
    }
}
