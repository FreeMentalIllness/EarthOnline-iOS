import SwiftData
import SwiftUI

/// 会话级依赖总线：仓库、备份、同步、派生引擎、设置
/// 说明：必须拿到 SwiftUI 注入的 ModelContext（与 @Query 同一个上下文）后再初始化，
///      否则写入与刷新会分成两个世界，界面不跟着更新。
@MainActor
final class AppSession: ObservableObject {
    let settings = AppSettings()

    var repo: Repository!
    var backups: BackupService!
    var sync: SyncManager!
    var engine: LifeEngine!

    @Published var isReady: Bool = false
    @Published var stats = LifeStats()
    @Published var celebrated: [AchievementItem] = []
    /// 版本检查（SideStore 约束：仅提示引导，不做应用内更新）
    @Published var isCheckingUpdate: Bool = false
    @Published var updateAlert: UpdateAlert?

    func attach(context: ModelContext) {
        guard !isReady else { return }
        repo = Repository(context: context)
        backups = BackupService(repo: repo)
        sync = SyncManager(repo: repo, settings: settings, backups: backups)
        engine = LifeEngine(repo: repo)
        isReady = true
        refresh()
        Task { await sync.pullIfNeeded() }
    }

    func refresh() {
        guard isReady else { return }
        // 每次派生前先跑一次成就判定，保证 XP 与成就行的最新状态
        let unlocked = engine.evaluateAchievements()
        stats = engine.stats(settings: settings)
        if !unlocked.isEmpty {
            celebrated = unlocked
            NotificationService.notify(title: "成就解锁 🏅", body: unlocked.map { $0.title }.joined(separator: "、"))
        }
        WidgetBridge.write(stats: stats, name: repo.profile().name)
    }

    /// 数据发生变更后的统一收口：刷新派生值 → 按需自动推送
    func didMutateData() {
        guard isReady else { return }
        stats = engine.stats(settings: settings)
        WidgetBridge.write(stats: stats, name: repo.profile().name)
        guard settings.autoSync else { return }
        Task { await sync.push() }
    }

    func clearAllData() {
        guard isReady else { return }
        repo.clearAllData()
        settings.clearUserDataKeys()
        // 防同步拉回：下一次冷启动自动拉取被跳过一次
        settings.skipNextPull = true
        stats = engine.stats(settings: settings)
        WidgetBridge.write(stats: stats, name: "")
    }
}
