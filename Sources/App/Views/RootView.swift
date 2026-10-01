import SwiftData
import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case tasks
    case backpack
    case discover
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "主页"
        case .tasks: return "任务"
        case .backpack: return "背包"
        case .discover: return "发现"
        case .settings: return "设置"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house"
        case .tasks: return "checkmark.circle"
        case .backpack: return "bag"
        case .discover: return "sparkles"
        case .settings: return "gearshape"
        }
    }

    static func from(_ url: URL) -> AppTab? {
        guard url.scheme == "earthonline" else { return nil }
        switch url.host {
        case "home": return .home
        case "tasks": return .tasks
        case "backpack": return .backpack
        case "achievements", "map", "stats", "ai": return .discover
        case "settings": return .settings
        default: return nil
        }
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var session: AppSession

    @State private var tab: AppTab = .home
    @State private var showCelebration: Bool = false
    @State private var liveActivity = LiveActivityManager()

    var body: some View {
        root
            .background(BackdropView())
            .task {
                if !session.isReady { session.attach(context: context) }
            }
            .onOpenURL { url in
                if let target = AppTab.from(url) { tab = target }
            }
            .environmentObject(liveActivity)
            .onChange(of: scenePhase) { _, phase in
                guard session.isReady else { return }
                if phase == .background, session.settings.autoSync {
                    let sync = session.sync
                    Task { await sync?.push() }
                }
                if phase == .active {
                    Task { await session.sync?.pullIfNeeded() }
                }
            }
            .onChange(of: session.celebrated.count) { _, count in
                showCelebration = count > 0
            }
            .sheet(isPresented: $showCelebration) {
                CelebrationView(items: session.celebrated) {
                    session.celebrated = []
                    showCelebration = false
                }
            }
    }

    @ViewBuilder
    private var root: some View {
        if !session.isReady {
            LaunchView()
        } else if !session.settings.onboardingDone {
            OnboardingView { session.settings.onboardingDone = true; session.refresh() }
        } else {
            TabView(selection: $tab) {
                HomeView()
                    .tabItem { Label(AppTab.home.title, systemImage: AppTab.home.icon) }
                    .tag(AppTab.home)
                TasksView()
                    .tabItem { Label(AppTab.tasks.title, systemImage: AppTab.tasks.icon) }
                    .tag(AppTab.tasks)
                BackpackView()
                    .tabItem { Label(AppTab.backpack.title, systemImage: AppTab.backpack.icon) }
                    .tag(AppTab.backpack)
                DiscoverView()
                    .tabItem { Label(AppTab.discover.title, systemImage: AppTab.discover.icon) }
                    .tag(AppTab.discover)
                SettingsView()
                    .tabItem { Label(AppTab.settings.title, systemImage: AppTab.settings.icon) }
                    .tag(AppTab.settings)
            }
            .onChange(of: tab) { _, newValue in
                if newValue == .home { session.refresh() }
            }
        }
    }
}

/// 首页背景：壁纸（含不透明度）或纯色兜底
struct BackdropView: View {
    @EnvironmentObject private var session: AppSession

    var body: some View {
        ZStack {
            Theme.background
            if let path = session.settings.wallpaperPath.nonEmpty,
               let data = LocalFileStore.load(path),
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .opacity(session.settings.wallpaperAlpha)
                    .ignoresSafeArea()
            }
        }
        .ignoresSafeArea()
    }
}

struct LaunchView: View {
    var body: some View {
        VStack(spacing: 10) {
            Text("🌏").font(.system(size: 56))
            Text("地球Online")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
    }
}

struct CelebrationView: View {
    let items: [AchievementItem]
    var onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(items, id: \.persistentModelID) { item in
                        HStack(alignment: .top, spacing: 12) {
                            Text(AchCategories.emoji(item.category)).font(.largeTitle)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title).font(.headline).foregroundStyle(Theme.textPrimary)
                                Text(item.achDesc).font(.footnote).foregroundStyle(Theme.textSecondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .eoCard()
                    }
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("成就解锁 🏅")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("太好了", action: onClose)
                }
            }
        }
    }
}

extension String {
    /// 空串 → nil，避免把「没设置」当成有效值写死
    var nonEmpty: String? { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self }
}
