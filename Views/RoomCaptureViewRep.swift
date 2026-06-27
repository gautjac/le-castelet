import SwiftUI

#if canImport(RoomPlan) && !targetEnvironment(simulator)
import RoomPlan

/// SwiftUI wrapper around RoomPlan's `RoomCaptureView`. It runs the live scanning session,
/// hands the finished `CapturedRoom` back to the controller, and signals completion.
///
/// Compiled only where RoomPlan is available **and** we're not in the Simulator (RoomPlan's
/// capture view can't run there). Everywhere else the scan flow shows the sample-room
/// fallback instead, so this file's absence is by design — nothing references it on
/// unsupported targets.
@available(iOS 16.0, *)
struct RoomCaptureViewRep: UIViewRepresentable {
    @ObservedObject var controller: RoomScanController
    /// Bound true by the parent to stop the session (the user tapped "Terminé").
    let stopTrigger: Bool
    /// Called once the session finishes processing, with success/failure.
    let onFinished: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller, onFinished: onFinished)
    }

    func makeUIView(context: Context) -> RoomCaptureView {
        let view = RoomCaptureView(frame: .zero)
        view.captureSession.delegate = context.coordinator
        view.delegate = context.coordinator
        context.coordinator.captureView = view

        var config = RoomCaptureSession.Configuration()
        config.isCoachingEnabled = true
        view.captureSession.run(configuration: config)
        controller.phase = .scanning
        return view
    }

    func updateUIView(_ uiView: RoomCaptureView, context: Context) {
        if stopTrigger && !context.coordinator.didStop {
            context.coordinator.didStop = true
            uiView.captureSession.stop()
            controller.phase = .processing
        }
    }

    // An explicit Objective-C name keeps the runtime name stable. RoomPlan's delegate
    // protocols are Obj-C protocols, and a *nested* NSObject subclass otherwise gets a
    // mangled, unstable name that the compiler rejects ("unstable name when archiving via
    // NSCoding"). This only surfaces in a real device build — the Simulator excludes this
    // whole file via the `#if`, which is how it slipped through a Simulator-only check.
    @MainActor
    @objc(LeCasteletRoomCaptureCoordinator)
    final class Coordinator: NSObject, RoomCaptureViewDelegate, RoomCaptureSessionDelegate {
        let controller: RoomScanController
        let onFinished: (Bool) -> Void
        weak var captureView: RoomCaptureView?
        var didStop = false

        init(controller: RoomScanController, onFinished: @escaping (Bool) -> Void) {
            self.controller = controller
            self.onFinished = onFinished
        }

        // RoomCaptureView post-processes the raw scan into a final CapturedRoom. We let it run
        // its default processing (return true) and capture the result below.
        nonisolated func captureView(shouldPresent roomDataForProcessing: CapturedRoomData,
                                     error: Error?) -> Bool {
            return true
        }

        nonisolated func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
            Task { @MainActor in
                if let error {
                    controller.phase = .failed(error.localizedDescription)
                    onFinished(false)
                    return
                }
                controller.store(capturedRoom: processedResult)
                controller.phase = .finished
                onFinished(true)
            }
        }
    }
}
#endif
