import Foundation

/// 应用设置 —— 键名与 Android DataStore 保持一致，方便跨端理解
enum SettingKeys {
    static let onboardingDone = "onboarding_done"
    static let theme = "earth_theme"
    static let wallpaper = "earth_wallpaper"
    static let wallpaperAlpha = "earth_wallpaper_alpha"
    static let notify = "earth_notify"
    static let aiConfig = "ai_config"
    static let webdavConfig = "webdav_config"
    static let autoSync = "earth_autosync"
    static let lastSync = "earth_last_sync"
    static let hideDoneTasks = "hide_done_tasks"
    static let achSound = "earth_ach_sound"
    static let customTimeline = "custom_timeline_events"
    static let homeFeedFilter = "home_feed_filter"
    static let homeFeedLimit = "home_feed_limit"
    static let homeQuickEntries = "home_quick_entries"
    static let customTitle = "custom_title"
    static let skipNextPull = "skip_next_pull"
    static let lastAutoPull = "last_auto_pull_at"
    static let lastCelebratedLevel = "last_celebrated_level"
}

enum AppThemeMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
}

struct AiConfig: Codable, Equatable {
    var baseUrl: String = ""
    var apiKey: String = ""
    var model: String = ""
}

struct WebDavConfig: Codable, Equatable {
    var baseUrl: String = ""
    var user: String = ""
    var password: String = ""
    var remoteDir: String = "EarthOnline"
    var fileName: String = "earth-online-backup.json"

    var isConfigured: Bool { !baseUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

/// 界面设置（ObservableObject + UserDefaults，跨视图共享）
final class AppSettings: ObservableObject {
    private let store: UserDefaults

    init(store: UserDefaults = .standard) {
        self.store = store
        self.mode = AppThemeMode(rawValue: store.string(forKey: SettingKeys.theme) ?? "system") ?? .system
        self.wallpaperPath = store.string(forKey: SettingKeys.wallpaper) ?? ""
        self.wallpaperAlpha = store.object(forKey: SettingKeys.wallpaperAlpha) as? Double ?? 0.35
        self.notifyEnabled = store.object(forKey: SettingKeys.notify) as? Bool ?? false
        self.autoSync = store.object(forKey: SettingKeys.autoSync) as? Bool ?? true
        self.hideDoneTasks = store.object(forKey: SettingKeys.hideDoneTasks) as? Bool ?? false
        self.achSound = store.object(forKey: SettingKeys.achSound) as? Bool ?? true
        self.onboardingDone = store.object(forKey: SettingKeys.onboardingDone) as? Bool ?? false
        self.homeFeedLimit = store.object(forKey: SettingKeys.homeFeedLimit) as? Int ?? 3
        self.customTitle = store.string(forKey: SettingKeys.customTitle) ?? ""
        self.lastSyncAt = store.string(forKey: SettingKeys.lastSync) ?? ""
        self.lastCelebratedLevel = store.object(forKey: SettingKeys.lastCelebratedLevel) as? Int ?? -1
        self.ai = AppSettings.decode(AiConfig.self, from: store.string(forKey: SettingKeys.aiConfig)) ?? AiConfig()
        self.webdav = AppSettings.decode(WebDavConfig.self, from: store.string(forKey: SettingKeys.webdavConfig)) ?? WebDavConfig()
        self.customTimeline = AppSettings.decode([TimelineEvent].self, from: store.string(forKey: SettingKeys.customTimeline)) ?? []
        self.homeQuickEntries = Set(AppSettings.decode([String].self, from: store.string(forKey: SettingKeys.homeQuickEntries)) ?? [])
    }

    @Published var mode: AppThemeMode { didSet { store.set(mode.rawValue, forKey: SettingKeys.theme) } }
    @Published var wallpaperPath: String { didSet { store.set(wallpaperPath, forKey: SettingKeys.wallpaper) } }
    @Published var wallpaperAlpha: Double { didSet { store.set(wallpaperAlpha, forKey: SettingKeys.wallpaperAlpha) } }
    @Published var notifyEnabled: Bool { didSet { store.set(notifyEnabled, forKey: SettingKeys.notify) } }
    @Published var autoSync: Bool { didSet { store.set(autoSync, forKey: SettingKeys.autoSync) } }
    @Published var hideDoneTasks: Bool { didSet { store.set(hideDoneTasks, forKey: SettingKeys.hideDoneTasks) } }
    @Published var achSound: Bool { didSet { store.set(achSound, forKey: SettingKeys.achSound) } }
    @Published var onboardingDone: Bool { didSet { store.set(onboardingDone, forKey: SettingKeys.onboardingDone) } }
    @Published var homeFeedLimit: Int { didSet { store.set(homeFeedLimit, forKey: SettingKeys.homeFeedLimit) } }
    @Published var customTitle: String { didSet { store.set(customTitle, forKey: SettingKeys.customTitle) } }
    @Published var lastSyncAt: String { didSet { store.set(lastSyncAt, forKey: SettingKeys.lastSync) } }
    @Published var lastCelebratedLevel: Int { didSet { store.set(lastCelebratedLevel, forKey: SettingKeys.lastCelebratedLevel) } }
    @Published var ai: AiConfig { didSet { persistCodable(ai, key: SettingKeys.aiConfig) } }
    @Published var webdav: WebDavConfig { didSet { persistCodable(webdav, key: SettingKeys.webdavConfig) } }
    @Published var customTimeline: [TimelineEvent] { didSet { persistCodable(customTimeline, key: SettingKeys.customTimeline) } }
    @Published var homeQuickEntries: Set<String> { didSet { persistCodable(Array(homeQuickEntries), key: SettingKeys.homeQuickEntries) } }

    // MARK: - 工具

    private func persistCodable<T: Encodable>(_ value: T, key: String) {
        store.set(AppSettings.encode(value), forKey: key)
    }

    private static func encode<T: Encodable>(_ value: T) -> String? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func decode<T: Decodable>(_ type: T.Type, from text: String?) -> T? {
        guard let text, let data = text.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    var skipNextPull: Bool {
        get { store.object(forKey: SettingKeys.skipNextPull) as? Bool ?? false }
        set { store.set(newValue, forKey: SettingKeys.skipNextPull) }
    }

    /// 上次自动拉取时间戳（节流用：进前台不每次都打网络）
    var lastAutoPullAt: TimeInterval {
        get { store.object(forKey: SettingKeys.lastAutoPull) as? Double ?? 0 }
        set { store.set(newValue, forKey: SettingKeys.lastAutoPull) }
    }

    /// 清空用户数据键（等价于 Android clearUserDataKeys）
    func clearUserDataKeys() {
        store.removeObject(forKey: SettingKeys.customTimeline)
        store.removeObject(forKey: SettingKeys.homeFeedFilter)
        store.removeObject(forKey: SettingKeys.homeFeedLimit)
        store.removeObject(forKey: SettingKeys.homeQuickEntries)
        store.removeObject(forKey: SettingKeys.customTitle)
        store.removeObject(forKey: SettingKeys.lastCelebratedLevel)
        homeFeedLimit = 3
        customTimeline = []
        homeQuickEntries = []
        customTitle = ""
        lastCelebratedLevel = -1
    }
}

/// 主页「人生时间轴」自定义里程碑
struct TimelineEvent: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var title: String
    var date: String
    var emoji: String = "✨"
}
