import Foundation

/// 主 App 侧：把派生快照写进共享容器（无 App Group 时自动跳过）
enum WidgetBridge {
    static func write(stats: LifeStats, name: String) {
        var snapshot = WidgetSnapshot()
        snapshot.updatedAt = DateUtils.isoNow()
        snapshot.name = name
        snapshot.level = stats.level
        snapshot.xp = stats.xp
        snapshot.nextLevelProgress = stats.nextLevelProgress
        snapshot.openTasks = stats.openTasks
        snapshot.todayDone = stats.todayDone
        snapshot.streakDays = stats.streakDays
        snapshot.daysLived = stats.daysLived
        snapshot.memos = stats.memos
        snapshot.locations = stats.locations
        snapshot.items = stats.items
        snapshot.usingSharedContainer = SharedStore.containerURL() != nil
        SharedStore.save(snapshot)
    }
}
