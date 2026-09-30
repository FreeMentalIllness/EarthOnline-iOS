import Foundation

/// 经验值换算规则 —— iOS 端唯一口径，常量与 Android util/XpRules.kt 完全一致
enum XpRules {
    static let taskDone = 10
    static let achievement = 50
    static let memo = 5
    static let location = 8
    static let item = 3
    static let photo = 2
    static let customMilestone = 15

    static let defaultTitle = "旅行者"

    static func totalXp(tasksDone: Int, achievements: Int, memos: Int,
                        locations: Int, items: Int = 0, photos: Int = 0) -> Int {
        tasksDone * taskDone + achievements * achievement + memos * memo +
            locations * location + items * item + photos * photo
    }

    static func streakBonus(streakDays: Int) -> Int {
        switch streakDays {
        case 60...: return 120
        case 30...: return 50
        case 14...: return 30
        case 7...: return 20
        case 3...: return 5
        default: return 0
        }
    }

    static func title(custom: String?) -> String {
        let trimmed = (custom ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultTitle : String(trimmed.prefix(12))
    }

    /// 各来源明细（数据看板用）
    struct Breakdown {
        let source: String
        let emoji: String
        let xp: Int
    }

    static func breakdown(tasksDone: Int, achievements: Int, memos: Int, locations: Int, items: Int) -> [Breakdown] {
        [
            Breakdown(source: "任务完成", emoji: "✅", xp: tasksDone * taskDone),
            Breakdown(source: "成就解锁", emoji: "🏅", xp: achievements * achievement),
            Breakdown(source: "世界日志", emoji: "📝", xp: memos * memo),
            Breakdown(source: "世界足迹", emoji: "🗺️", xp: locations * location),
            Breakdown(source: "背包物品", emoji: "🎒", xp: items * item)
        ]
    }
}
