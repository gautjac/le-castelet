#!/usr/bin/env swift

// Builds the bundled sample room (`Sample/SampleRoom.usdz`) so the dollhouse + relight
// experience is fully demoable without a LiDAR scan (Simulator, non-Pro devices).
//
// We assemble a small furnished room out of box primitives in a SceneKit scene — four walls,
// a floor, a door opening, a window, plus a few "objects" (a table, two chairs, a bed, a rug)
// — then export the whole scene to USDZ via SceneKit's USDZ writer. The proportions roughly
// match what RoomPlan would hand us (metres, Y-up), so the in-app loader, auto-fit and
// thumbnail renderer treat it exactly like a scanned room.
//
// Run from the project root:  swift scripts/make-sample-room.swift

import SceneKit
import ModelIO
import SceneKit.ModelIO
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outURL = root.appendingPathComponent("Sample/SampleRoom.usdz")
try? FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(),
                                         withIntermediateDirectories: true)

let scene = SCNScene()

// Palette — warm plaster walls, oak floor, soft furnishings.
func mat(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, rough: CGFloat = 0.85, metal: CGFloat = 0) -> SCNMaterial {
    let m = SCNMaterial()
    m.lightingModel = .physicallyBased
    m.diffuse.contents = NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
    m.roughness.contents = rough
    m.metalness.contents = metal
    return m
}

let plaster = mat(0.93, 0.89, 0.81)
let oak     = mat(0.62, 0.44, 0.27, rough: 0.7)
let wood    = mat(0.50, 0.33, 0.20, rough: 0.6)
let fabric  = mat(0.30, 0.42, 0.52)         // upholstery blue
let rugCol  = mat(0.72, 0.27, 0.24)         // a warm red rug
let linen   = mat(0.88, 0.86, 0.80)
let glass   = mat(0.55, 0.70, 0.80, rough: 0.1)

// Room dimensions (metres).
let W: CGFloat = 4.2   // x
let D: CGFloat = 3.4   // z
let H: CGFloat = 2.6   // y
let t: CGFloat = 0.08  // wall thickness

func box(_ w: CGFloat, _ h: CGFloat, _ l: CGFloat, _ m: SCNMaterial,
         _ x: CGFloat, _ y: CGFloat, _ z: CGFloat, name: String) -> SCNNode {
    let b = SCNBox(width: w, height: h, length: l, chamferRadius: 0.01)
    b.firstMaterial = m
    let n = SCNNode(geometry: b)
    n.position = SCNVector3(x, y, z)
    n.name = name
    return n
}

// Floor.
scene.rootNode.addChildNode(box(W, t, D, oak, 0, t/2, 0, name: "Floor"))

// Back wall (solid).
scene.rootNode.addChildNode(box(W, H, t, plaster, 0, H/2, -D/2, name: "Wall_Back"))

// Front wall with a door opening: build it as two posts + a lintel, leaving a gap.
let doorW: CGFloat = 0.95
let doorH: CGFloat = 2.05
let sideW = (W - doorW) / 2
scene.rootNode.addChildNode(box(sideW, H, t, plaster, -(doorW/2 + sideW/2), H/2, D/2, name: "Wall_Front_L"))
scene.rootNode.addChildNode(box(sideW, H, t, plaster,  (doorW/2 + sideW/2), H/2, D/2, name: "Wall_Front_R"))
scene.rootNode.addChildNode(box(doorW, H - doorH, t, plaster, 0, doorH + (H - doorH)/2, D/2, name: "Wall_Front_Lintel"))

// Left wall (solid).
scene.rootNode.addChildNode(box(t, H, D, plaster, -W/2, H/2, 0, name: "Wall_Left"))

// Right wall with a window: posts + sill + header, glass pane in the gap.
let winW: CGFloat = 1.3, winH: CGFloat = 1.1, winSill: CGFloat = 0.95
let rSide = (D - winW) / 2
scene.rootNode.addChildNode(box(t, H, rSide, plaster, W/2, H/2, -(winW/2 + rSide/2), name: "Wall_Right_A"))
scene.rootNode.addChildNode(box(t, H, rSide, plaster, W/2, H/2,  (winW/2 + rSide/2), name: "Wall_Right_B"))
scene.rootNode.addChildNode(box(t, winSill, winW, plaster, W/2, winSill/2, 0, name: "Wall_Right_Sill"))
let headH = H - (winSill + winH)
scene.rootNode.addChildNode(box(t, headH, winW, plaster, W/2, winSill + winH + headH/2, 0, name: "Wall_Right_Header"))
scene.rootNode.addChildNode(box(0.02, winH, winW, glass, W/2, winSill + winH/2, 0, name: "Window"))

// --- Furniture ("objects" RoomPlan would detect) ---

// A rug centred on the floor.
scene.rootNode.addChildNode(box(2.2, 0.012, 1.5, rugCol, -0.2, t + 0.008, 0.3, name: "Rug"))

// A table.
let tableTopY: CGFloat = 0.74
let table = SCNNode(); table.name = "Table"
table.addChildNode(box(1.2, 0.05, 0.75, wood, 0, tableTopY, 0, name: "TableTop"))
for (dx, dz) in [(-0.52, -0.32), (0.52, -0.32), (-0.52, 0.32), (0.52, 0.32)] {
    table.addChildNode(box(0.06, tableTopY, 0.06, wood, CGFloat(dx), tableTopY/2, CGFloat(dz), name: "Leg"))
}
table.position = SCNVector3(-0.2, 0, 0.2)
scene.rootNode.addChildNode(table)

// Two chairs.
func chair(x: CGFloat, z: CGFloat, name: String) -> SCNNode {
    let c = SCNNode(); c.name = name
    let seatY: CGFloat = 0.45
    c.addChildNode(box(0.42, 0.05, 0.42, fabric, 0, seatY, 0, name: "Seat"))
    c.addChildNode(box(0.42, 0.5, 0.05, fabric, 0, seatY + 0.27, -0.18, name: "Back"))
    for (dx, dz) in [(-0.17, -0.17), (0.17, -0.17), (-0.17, 0.17), (0.17, 0.17)] {
        c.addChildNode(box(0.04, seatY, 0.04, wood, CGFloat(dx), seatY/2, CGFloat(dz), name: "ChairLeg"))
    }
    c.position = SCNVector3(x, 0, z)
    return c
}
scene.rootNode.addChildNode(chair(x: -0.2, z: 0.95, name: "Chair_A"))
let chairB = chair(x: -0.2, z: -0.55, name: "Chair_B")
chairB.eulerAngles = SCNVector3(0, Float.pi, 0)
scene.rootNode.addChildNode(chairB)

// A small bed / daybed against the back-left corner.
let bed = SCNNode(); bed.name = "Bed"
bed.addChildNode(box(1.9, 0.3, 0.95, wood, 0, 0.15, 0, name: "BedFrame"))
bed.addChildNode(box(1.85, 0.18, 0.9, linen, 0, 0.36, 0, name: "Mattress"))
bed.addChildNode(box(0.5, 0.16, 0.4, linen, -0.62, 0.5, 0, name: "Pillow"))
bed.position = SCNVector3(W/2 - 1.1, 0, -D/2 + 0.6)
scene.rootNode.addChildNode(bed)

// A lamp in the corner — its glow is added live by the app, but the body reads as an object.
let lamp = SCNNode(); lamp.name = "Lamp"
lamp.addChildNode(box(0.06, 1.2, 0.06, wood, 0, 0.6, 0, name: "LampStem"))
let shade = SCNSphere(radius: 0.16); shade.firstMaterial = mat(0.95, 0.82, 0.55)
let shadeNode = SCNNode(geometry: shade); shadeNode.position = SCNVector3(0, 1.25, 0)
lamp.addChildNode(shadeNode)
lamp.position = SCNVector3(-W/2 + 0.4, 0, -D/2 + 0.4)
scene.rootNode.addChildNode(lamp)

// Export to USDZ.
let ok = scene.write(to: outURL, options: nil, delegate: nil, progressHandler: nil)
if ok {
    print("Wrote \(outURL.path)")
} else {
    fputs("Failed to write USDZ\n", stderr)
    exit(1)
}
