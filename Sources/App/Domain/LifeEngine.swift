import Foundation
import SwiftData

/// 派生指标快照（主页 / 数据看板 / 小组件共用同一口径）
struct LifeStats {
    var level: Int = 0
    var xp: Int = 0
    var nextLevelProgress: Double = 0
    var title: String = XpRules.defaultTitle
    var daysLived: Int = 0
    var tasksDone: Int = 0
    var openTasks: Int = 0
    var todayDone: Int = 0
    var memos: Int = 0
    var items: Int = 0
    var collections: Int = 0
    var achievements: Int = 0
    var locations: Int = 0
    var streakDays: Int = 0
    var xpBreakdown: [XpRules.Breakdown] = []
}

/// 数据派生引擎（与 Android XpRules / 报告的派生口径保持一致）
@MainActor
final class LifeEngine {
    private let repo: Repository

    init(repo: Repository) { self.repo = repo }

    func stats(settings: AppSettings) -> LifeStats {
        let profile = repo.profile()
        let tasks = repo.all(TaskItem.self)
        let memos = repo.all(MemoItem.self)
        let items = repo.all(BagItem.self)
        let collections = repo.all(CollectionItem.self)
        let pins = repo.all(LocationPin.self)
        let achievements = repo.all(AchievementItem.self)

        let tasksDone = tasks.filter { $0.doneAt != nil }.count
        let unlockedAchievements = achievements.filter { $0.unlocked }.count
        let today = DateUtils.todayKey()
        let todayDone = tasks.filter { DateUtils.dayOfIso($0.doneAt ?? "") == today }.count
        let xp = XpRules.totalXp(tasksDone: tasksDone, achievements: unlockedAchievements, memos: memos.count,
                                 locations: pins.count, items: items.count)
        profile.xp = xp

        var result = LifeStats()
        result.level = DateUtils.age(from: profile.birthDate)
        result.xp = xp
        result.nextLevelProgress = DateUtils.nextBirthdayProgress(from: profile.birthDate)
        result.title = XpRules.title(custom: settings.customTitle)
        result.daysLived = DateUtils.daysLived(from: profile.birthDate)
        result.tasksDone = tasksDone
        result.openTasks = tasks.filter { $0.status != TaskStatus.done.rawValue }.count
        result.todayDone = todayDone
        result.memos = memos.count
        result.items = items.count
        result.collections = collections.count
        result.achievements = unlockedAchievements
        result.locations = pins.count
        result.streakDays = DateUtils.longestStreak(days: memos.map { DateUtils.dayOfIso($0.createdAt) })
        result.xpBreakdown = XpRules.breakdown(tasksDone: tasksDone, achievements: unlockedAchievements,
                                               memos: memos.count, locations: pins.count, items: items.count)
        repo.save()
        return result
    }

    // MARK: - 成就判定

    func achievementStats() -> AchStats {
        let profile = repo.profile()
        let tasks = repo.all(TaskItem.self)
        let memos = repo.all(MemoItem.self)
        let items = repo.all(BagItem.self)
        let collections = repo.all(CollectionItem.self)
        let pins = repo.all(LocationPin.self)

        var stats = AchStats()
        stats.tasksDone = tasks.filter { $0.doneAt != nil }.count
        stats.items = items.count
        stats.collections = collections.count
        stats.memos = memos.count
        stats.locations = pins.count
        stats.daysLived = DateUtils.daysLived(from: profile.birthDate)
        stats.age = DateUtils.age(from: profile.birthDate)
        stats.gender = profile.gender

        stats.am3Memos = memos.filter { DateUtils.hourOfIso($0.createdAt) == 3 }.count
        stats.nightOwlMemos = memos.filter { (0..<5).contains(DateUtils.hourOfIso($0.createdAt) ?? -1) }.count
        stats.earlyBirdMemos = memos.filter { (5..<7).contains(DateUtils.hourOfIso($0.createdAt) ?? -1) }.count
        stats.am3TasksDone = tasks.filter { DateUtils.hourOfIso($0.doneAt ?? "") == 3 }.count
        stats.longTitleTasks = tasks.filter { $0.title.count >= 30 }.count
        stats.emojiTitleTasks = tasks.filter { TextFeatures.countEmoji($0.title) >= 5 }.count
        stats.periodTitleTasks = tasks.filter { $0.title.hasSuffix("。") }.count
        stats.testTitleTasks = tasks.filter { TextFeatures.contains(["测试", "test"], in: $0.title) }.count

        let today = DateUtils.todayKey()
        stats.overdueOpenTodos = tasks.filter {
            $0.category == TaskCategory.todo.rawValue && $0.status != TaskStatus.done.rawValue &&
                ($0.dueDate ?? "") < today && !($0.dueDate ?? "").isEmpty
        }.count

        var perDay: [String: Int] = [:]
        tasks.filter { $0.doneAt != nil && !($0.doneAt ?? "").isEmpty }
            .forEach { perDay[DateUtils.dayOfIso($0.doneAt ?? ""), default: 0] += 1 }
        stats.maxDoneInDay = perDay.values.max() ?? 0
        stats.recordStreak = DateUtils.longestStreak(days: memos.map { DateUtils.dayOfIso($0.createdAt) })
        stats.emojiOnlyMemos = memos.filter { TextFeatures.isEmojiOnly($0.text) }.count
        stats.newYearBirth = profile.birthDate.hasSuffix("01-01") ? 1 : 0
        return stats
    }

    func eventSources() -> AchievementEventSources {
        var sources = AchievementEventSources()
        sources.doneAtList = repo.all(TaskItem.self).compactMap { $0.doneAt }
        sources.itemCreatedList = repo.all(BagItem.self).map { $0.createdAt }
        sources.collectionCreatedList = repo.all(CollectionItem.self).map { $0.createdAt }
        sources.memoCreatedList = repo.all(MemoItem.self).map { $0.createdAt }
        sources.locationDateList = repo.all(LocationPin.self).map { $0.date }
        sources.birthDate = repo.profile().birthDate
        return sources
    }

    /// 跑一遍自动成就：补齐行 + 判定解锁，返回本次新解锁的成就
    @discardableResult
    func evaluateAchievements() -> [AchievementItem] {
        let stats = achievementStats()
        let sources = eventSources()
        let existing = repo.all(AchievementItem.self)
        var unlockedNow: [AchievementItem] = []

        for rule in AutoRules.all {
            if let found = existing.first(where: { $0.autoKey == rule.key }) {
                guard found.unlocked == false else { continue }
                guard rule.isSatisfied(by: stats) else { continue }
                found.unlocked = true
                found.unlockedAt = sources.eventAt(for: rule.key) ?? DateUtils.isoNow()
                let event = XpEventItem(kind: "ach", amount: XpRules.achievement, reason: "解锁成就：\(rule.title)")
                repo.context.insert(event)
                repo.logActivity(kind: .ach, title: "解锁成就：\(rule.title)")
                unlockedNow.append(found)
                continue
            }
            guard rule.isSatisfied(by: stats) else { continue }
            let item = AchievementItem(title: rule.title, achDesc: rule.desc, type: "auto",
                                       autoKey: rule.key, category: rule.category)
            item.unlocked = true
            item.unlockedAt = sources.eventAt(for: rule.key) ?? DateUtils.isoNow()
            repo.context.insert(item)
            let event = XpEventItem(kind: "ach", amount: XpRules.achievement, reason: "解锁成就：\(rule.title)")
            repo.context.insert(event)
            repo.logActivity(kind: .ach, title: "解锁成就：\(rule.title)")
            unlockedNow.append(item)
        }
        repo.save()
        return unlockedNow
    }
}
