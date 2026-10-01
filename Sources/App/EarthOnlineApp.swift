import SwiftData
import SwiftUI
import UserNotifications

@main
struct EarthOnlineApp: App {
    @StateObject private var session = AppSession()
    private let container = AppContainer.makeContainer()
    /// 本地通知响应路由（灵感接力等）
    @StateObject private var notificationRouter = NotificationRouterHolder()

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .environmentObject(session)
                .preferredColorScheme(preferredScheme)
                .onAppear {
                    UNUserNotificationCenter.current().delegate = notificationRouter.router
                }
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

/// 持有 delegate 的壳（delegate 必须常驻强引用）
@MainActor
final class NotificationRouterHolder: ObservableObject {
    let router = NotificationRouter()
}
