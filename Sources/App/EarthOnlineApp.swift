import SwiftData
import SwiftUI

@main
struct EarthOnlineApp: App {
    @StateObject private var session = AppSession()
    private let container = AppContainer.makeContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .environmentObject(session)
                .preferredColorScheme(preferredScheme)
        }
    }

    private var preferredScheme: ColorScheme? {
        switch session.settings.mode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
