import SwiftUI

@main
struct PiliPlusApp: App {
    @State private var environment = AppEnvironment.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .preferredColorScheme(environment.settings.appearance.colorScheme)
        }
        .modelContainer(environment.modelContainer)
    }
}
