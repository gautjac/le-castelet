# Le Castelet

Numérisez une pièce réelle et tenez-la dans la paume de votre main comme une petite **maquette**
de théâtre que vous faites tourner, zoomez et **rééclairez de l'aube à la nuit**.

A native iOS app for the Atelier — a toy-theatre / dollhouse built on **RoomPlan + RealityKit**.

## Ce que ça fait

1. **Numériser** — `RoomCaptureView` (RoomPlan) scanne une pièce avec le LiDAR, puis exporte
   le `CapturedRoom` en USDZ sur le disque.
2. **La maquette (signature)** — la pièce numérisée devient un petit modèle 3D posé sur une
   table, dans une `RealityView` (RealityKit). On la **tourne / pince / zoome** comme une
   maquette qu'on retourne dans ses mains. Un curseur **jour → crépuscule → nuit** rééclaire la
   même pièce (lumière directionnelle chaude/froide + ambiance), et de petites lampes (lampe,
   âtre) s'allument la nuit.
3. **Galerie** — une grille des pièces sauvegardées (vignette rendue + nom + stats). Toucher une
   carte rouvre la maquette. Les USDZ vivent dans Application Support ; les métadonnées dans
   SwiftData (local).
4. **Repli gracieux** — RoomPlan exige un appareil LiDAR et ne numérise pas dans le simulateur.
   L'app détecte le matériel non supporté (`RoomCaptureSession.isSupported`) et propose une
   **pièce d'exemple** intégrée au bundle, pour que toute l'expérience maquette / rééclairage
   soit pleinement démontrable sans numériser. Jamais de crash sur matériel non supporté.

## Architecture

- **`Model/`** — `Castelet` (SwiftData, local only), `CasteletStorage` (USDZ sur disque),
  `CasteletStore` (ModelContainer avec repli en mémoire), `SampleSeeder` (sème l'exemple).
- **`Engine/`** — `LightingMood` / `LightingState` (les 4 ambiances interpolées),
  `RoomScanController` (export RoomPlan → USDZ, gardé `#if canImport(RoomPlan)`),
  `DollhouseScene` (le graphe RealityKit : platine, rig d'éclairage, lampes, gestes),
  `ThumbnailRenderer` (snapshot SceneKit hors-écran pour la galerie).
- **`Views/`** — `GalerieView`, `DollhouseView` (la signature), `ScanFlowView`,
  `RoomCaptureViewRep` (wrapper RoomPlan, compilé hors simulateur seulement).

## Identité visuelle

Un petit castelet chaleureux : rouge rideau (velours), or laiton, papier crème de scène, police
serif « playbill ». L'icône est une arche de proscenium dorée encadrant une maisonnette sur une
scène éclairée.

## Construire

```bash
cd ~/Claude/apps/le-castelet
xcodegen generate
xcodebuild -project LeCastelet.xcodeproj -scheme LeCastelet \
  -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```

Régénérer l'exemple : `swift scripts/make-sample-room.swift`
Régénérer l'icône : `swift scripts/make-icon.swift`

## Caveats

- **La numérisation demande un appareil LiDAR** (iPhone Pro / iPad Pro). Le simulateur et les
  appareils non-Pro utilisent la pièce d'exemple intégrée — tout le reste fonctionne.
- iOS 26.0+ (SDK iOS 27, Xcode 27). Cible `LeCastelet`, bundle `com.jac.LeCastelet`.
