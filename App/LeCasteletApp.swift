import SwiftUI
import SwiftData

@main
struct LeCasteletApp: App {
    init() {
        // Make sure the bundled sample room exists in the galerie on first launch, so the
        // dollhouse is demoable even where scanning isn't possible.
        SampleSeeder.seedIfNeeded(into: CasteletStore.shared.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            GalerieView()
                .modelContainer(CasteletStore.shared)
                .tint(Theme.brassC)
                .preferredColorScheme(nil)
        }
    }
}
