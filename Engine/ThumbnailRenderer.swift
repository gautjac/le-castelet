import Foundation
import UIKit
import SceneKit
import OSLog

/// Renders a small PNG thumbnail of a USDZ room model for the galerie card.
///
/// SceneKit's offscreen `SCNRenderer` is the simplest way to snapshot a USDZ without standing
/// up a full RealityKit scene: it loads the model, frames it with a default camera, and
/// renders a single frame. The render is dispatched off the main thread; the completion is
/// delivered back on the main actor so the caller can write it to SwiftData safely.
enum ThumbnailRenderer {
    static func render(modelURL: URL, size: CGSize = CGSize(width: 480, height: 360),
                       completion: @escaping @MainActor (Data?) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let data = snapshot(modelURL: modelURL, size: size)
            Task { @MainActor in completion(data) }
        }
    }

    private static func snapshot(modelURL: URL, size: CGSize) -> Data? {
        guard let scene = try? SCNScene(url: modelURL, options: [.checkConsistency: false]) else {
            casteletLog.error("Thumbnail: could not load scene")
            return nil
        }

        // Frame the model with a camera looking down at a pleasing 3/4 angle.
        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.fieldOfView = 45
        cameraNode.camera = camera

        let (minB, maxB) = scene.rootNode.boundingBox
        let center = SCNVector3((minB.x + maxB.x) / 2, (minB.y + maxB.y) / 2, (minB.z + maxB.z) / 2)
        let extent = SCNVector3(maxB.x - minB.x, maxB.y - minB.y, maxB.z - minB.z)
        let radius = max(extent.x, max(extent.y, extent.z))
        let dist = radius * 1.9 + 0.5

        cameraNode.position = SCNVector3(center.x + dist * 0.7,
                                         center.y + dist * 0.8,
                                         center.z + dist * 0.7)
        cameraNode.look(at: center)
        scene.rootNode.addChildNode(cameraNode)

        // Warm key + soft ambient so the maquette reads on the card.
        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 900
        key.light?.color = UIColor(red: 1.0, green: 0.93, blue: 0.82, alpha: 1)
        key.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 5, 0)
        scene.rootNode.addChildNode(key)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 450
        ambient.light?.color = UIColor(red: 0.5, green: 0.52, blue: 0.6, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        let renderer = SCNRenderer(device: nil, options: nil)
        renderer.scene = scene
        renderer.pointOfView = cameraNode

        let image = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
        return image.pngData()
    }
}
