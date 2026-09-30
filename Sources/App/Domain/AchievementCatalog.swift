import Foundation

// MARK: - 成就分类（与其他三端完全一致的顺序与 id）

struct AchCategory: Identifiable, Equatable {
    let id: String
    let label: String
    let emoji: String
}

enum AchCategories {
    static let all: [AchCategory] = [
        AchCategory(id: "task", label: "任务", emoji: "📋"),
        AchCategory(id: "bag", label: "背包", emoji: "🎒"),
        AchCategory(id: "collection", label: "收藏", emoji: "📚"),
        AchCategory(id: "map", label: "足迹", emoji: "🗺️"),
        AchCategory(id: "memo", label: "日志", emoji: "📝"),
        AchCategory(id: "growth", label: "成长", emoji: "🌱"),
        AchCategory(id: "general", label: "综合", emoji: "🏅"),
        AchCategory(id: "egg", label: "彩蛋", emoji: "🥚"),
        AchCategory(id: "custom", label: "自定义", emoji: "✍️")
    ]

    static let customId = "custom"
    static let eggId = "egg"
    static let eggMask = "？？？"
    static let eggMaskDesc = "隐藏成就 · 达成条件保密。触发一次，就会自己现身。"

    static func label(_ id: String?) -> String { all.first { $0.id == id }?.label ?? "自定义" }
    static func emoji(_ id: String?) -> String { all.first { $0.id == id }?.emoji ?? "✍️" }
}

// MARK: - 文本 / 时间特征（对齐 Android AchievementCatalog 的工具）

enum TextFeatures {
    static func countEmoji(_ text: String) -> Int {
        var count = 0
        let scalars = Array(text.unicodeScalars)
        var index = 0
        while index < scalars.count {
            let value = Int(scalars[index].value)
            if (0x1F300...0x1FAFF).contains(value) {
                count += 1
                index += 1
                continue
            }
            if (0x2600...0x27BF).contains(value) || (0x2B00...0x2BFF).contains(value) ||
                (0x2190...0x21FF).contains(value) || (0x2300...0x23FF).contains(value) ||
                (0x25A0...0x25FF).contains(value) {
                count += 1
            }
            index += 1
        }
        return count
    }

    static func isEmojiOnly(_ text: String) -> Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard countEmoji(text) >= 2 else { return false }
        let rest = text.filter { $0.isLetter || $0.isNumber || $0.isWhitespace }
        return rest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func contains(_ needles: [String], in text: String) -> Bool {
        let lower = text.lowercased()
        return needles.contains { lower.contains($0.lowercased()) }
    }
}

// MARK: - 规则快照

struct AchStats {
    var tasksDone: Int = 0
    var items: Int = 0
    var collections: Int = 0
    var memos: Int = 0
    var locations: Int = 0
    var daysLived: Int = 0
    var age: Int = 0

    var gender: String = ""
    var am3Memos: Int = 0
    var nightOwlMemos: Int = 0
    var earlyBirdMemos: Int = 0
    var am3TasksDone: Int = 0
    var longTitleTasks: Int = 0
    var emojiTitleTasks: Int = 0
    var periodTitleTasks: Int = 0
    var testTitleTasks: Int = 0
    var overdueOpenTodos: Int = 0
    var maxDoneInDay: Int = 0
    var recordStreak: Int = 0
    var emojiOnlyMemos: Int = 0
    var newYearBirth: Int = 0
}

// MARK: - 自动成就规则

struct AutoRule {
    let key: String
    let title: String
    let desc: String
    let category: String
    let goal: Int
    let test: ((AchStats) -> Bool)?
    let current: (AchStats) -> Int

    init(key: String, title: String, desc: String, category: String, goal: Int,
         test: ((AchStats) -> Bool)? = nil, current: @escaping (AchStats) -> Int = { _ in 0 }) {
        self.key = key
        self.title = title
        self.desc = desc
        self.category = category
        self.goal = goal
        self.test = test
        self.current = current
    }

    func progress(of stats: AchStats) -> Int { min(current(stats), max(goal, 1)) }
    func goalValue() -> Int { max(goal, 1) }
    func isSatisfied(by stats: AchStats) -> Bool { test?(stats) ?? (goal > 0 && current(stats) >= goal) }
}

private func multiCount(_ s: AchStats, threshold: Int) -> Int {
    [s.tasksDone >= threshold, s.items >= threshold, s.collections >= threshold,
     s.memos >= threshold, s.locations >= threshold].filter { $0 }.count
}

enum AutoRules {
    static let all: [AutoRule] = [
        // 任务
        AutoRule(key: "first_task", title: "初出茅庐", desc: "完成你的第一个任务", category: "task", goal: 1, current: { $0.tasksDone }),
        AutoRule(key: "five_tasks", title: "渐入佳境", desc: "累计完成 5 个任务", category: "task", goal: 5, current: { $0.tasksDone }),
        AutoRule(key: "ten_tasks", title: "小有成就", desc: "累计完成 10 个任务", category: "task", goal: 10, current: { $0.tasksDone }),
        AutoRule(key: "thirty_tasks", title: "三十而立", desc: "累计完成 30 个任务", category: "task", goal: 30, current: { $0.tasksDone }),
        AutoRule(key: "fifty_tasks", title: "任务大师", desc: "累计完成 50 个任务", category: "task", goal: 50, current: { $0.tasksDone }),
        AutoRule(key: "hundred_tasks", title: "百炼成钢", desc: "累计完成 100 个任务", category: "task", goal: 100, current: { $0.tasksDone }),
        // 背包
        AutoRule(key: "first_item", title: "初拾一物", desc: "拾取你的第一个物品", category: "bag", goal: 1, current: { $0.items }),
        AutoRule(key: "ten_items", title: "背包满满", desc: "累计收集 10 个物品", category: "bag", goal: 10, current: { $0.items }),
        AutoRule(key: "fifty_items", title: "移动仓库", desc: "累计收集 50 个物品", category: "bag", goal: 50, current: { $0.items }),
        // 收藏
        AutoRule(key: "first_collection", title: "珍藏", desc: "完成第一次收藏", category: "collection", goal: 1, current: { $0.collections }),
        AutoRule(key: "ten_collections", title: "博览群书", desc: "累计 10 条收藏", category: "collection", goal: 10, current: { $0.collections }),
        AutoRule(key: "fifty_collections", title: "收藏大家", desc: "累计 50 条收藏", category: "collection", goal: 50, current: { $0.collections }),
        // 足迹
        AutoRule(key: "first_location", title: "探索者", desc: "记录第一个足迹", category: "map", goal: 1, current: { $0.locations }),
        AutoRule(key: "five_locations", title: "走南闯北", desc: "记录 5 个足迹", category: "map", goal: 5, current: { $0.locations }),
        AutoRule(key: "twenty_locations", title: "环游世界", desc: "记录 20 个足迹", category: "map", goal: 20, current: { $0.locations }),
        // 日志
        AutoRule(key: "first_memo", title: "记录者", desc: "写下第一条世界日志", category: "memo", goal: 1, current: { $0.memos }),
        AutoRule(key: "ten_memos", title: "笔耕不辍", desc: "累计 10 条世界日志", category: "memo", goal: 10, current: { $0.memos }),
        AutoRule(key: "fifty_memos", title: "生活诗人", desc: "累计 50 条世界日志", category: "memo", goal: 50, current: { $0.memos }),
        // 成长
        AutoRule(key: "day_100", title: "百日之约", desc: "来到地球满 100 天", category: "growth", goal: 100, current: { $0.daysLived }),
        AutoRule(key: "day_365", title: "一周岁", desc: "来到地球满 365 天", category: "growth", goal: 365, current: { $0.daysLived }),
        AutoRule(key: "day_1000", title: "千日之行", desc: "来到地球满 1000 天", category: "growth", goal: 1000, current: { $0.daysLived }),
        AutoRule(key: "day_5000", title: "万水千山", desc: "来到地球满 5000 天", category: "growth", goal: 5000, current: { $0.daysLived }),
        AutoRule(key: "day_10000", title: "万日玩家", desc: "来到地球满 10000 天", category: "growth", goal: 10000, current: { $0.daysLived }),
        AutoRule(key: "adult_18", title: "成年礼", desc: "等级（周岁）达到 18", category: "growth", goal: 18, current: { $0.age }),
        // 综合
        AutoRule(key: "all_rounder", title: "全能玩家", desc: "任务 / 物品 / 收藏 / 日志 / 足迹各至少 1", category: "general",
                 goal: 5, test: { multiCount($0, threshold: 1) == 5 }, current: { multiCount($0, threshold: 1) }),
        AutoRule(key: "five_star", title: "五光十色", desc: "任务20 · 物品20 · 收藏10 · 日志10 · 足迹5", category: "general",
                 goal: 5,
                 test: { $0.tasksDone >= 20 && $0.items >= 20 && $0.collections >= 10 && $0.memos >= 10 && $0.locations >= 5 },
                 current: { [$0.tasksDone >= 20, $0.items >= 20, $0.collections >= 10, $0.memos >= 10, $0.locations >= 5].filter { $0 }.count }),
        AutoRule(key: "grand_slam", title: "大满贯", desc: "任务 / 物品 / 收藏 / 日志 / 足迹各达到 20", category: "general",
                 goal: 5, test: { multiCount($0, threshold: 20) == 5 }, current: { multiCount($0, threshold: 20) }),
        // 彩蛋
        AutoRule(key: "egg_walmart", title: "购物袋玩家", desc: "把性别设置成「沃尔玛购物袋」", category: "egg",
                 goal: 1, test: { $0.gender == "walmart" }, current: { $0.gender == "walmart" ? 1 : 0 }),
        AutoRule(key: "egg_gender_fluid", title: "性别是流动的", desc: "性别选一个更离谱的答案", category: "egg",
                 goal: 1, test: { $0.gender == "helicopter" || $0.gender == "potato" },
                 current: { ($0.gender == "helicopter" || $0.gender == "potato") ? 1 : 0 }),
        AutoRule(key: "egg_3am", title: "凌晨三点俱乐部", desc: "在凌晨 3 点写下一条世界日志", category: "egg", goal: 1, current: { $0.am3Memos }),
        AutoRule(key: "egg_night_owl", title: "夜猫子", desc: "累计 3 条写于 0~5 点的日志", category: "egg", goal: 3, current: { $0.nightOwlMemos }),
        AutoRule(key: "egg_early_bird", title: "早起的鸟儿", desc: "累计 3 条写于 5~7 点的日志", category: "egg", goal: 3, current: { $0.earlyBirdMemos }),
        AutoRule(key: "egg_midnight_task", title: "肝帝", desc: "在凌晨 3 点完成一个任务", category: "egg", goal: 1, current: { $0.am3TasksDone }),
        AutoRule(key: "egg_long_title", title: "一句话说不完", desc: "给任务起一个 ≥30 字的标题", category: "egg", goal: 1, current: { $0.longTitleTasks }),
        AutoRule(key: "egg_emoji_title", title: "表情包本人", desc: "任务标题里塞进 ≥5 个 emoji", category: "egg", goal: 1, current: { $0.emojiTitleTasks }),
        AutoRule(key: "egg_period_title", title: "句号强迫症", desc: "累计 3 个以「。」结尾的任务标题", category: "egg", goal: 3, current: { $0.periodTitleTasks }),
        AutoRule(key: "egg_test_title", title: "测试工程师", desc: "累计 3 个名字里带「测试」的任务", category: "egg", goal: 3, current: { $0.testTitleTasks }),
        AutoRule(key: "egg_overdue", title: "拖延症晚期", desc: "同时挂着 5 个逾期待办", category: "egg", goal: 5, current: { $0.overdueOpenTodos }),
        AutoRule(key: "egg_marathon", title: "一日十杀", desc: "同一天里完成 10 个任务", category: "egg", goal: 10, current: { $0.maxDoneInDay }),
        AutoRule(key: "egg_streak_7", title: "七日之约", desc: "连续 7 天记录世界日志", category: "egg", goal: 7, current: { $0.recordStreak }),
        AutoRule(key: "egg_streak_30", title: "一个月不断更", desc: "连续 30 天记录世界日志", category: "egg", goal: 30, current: { $0.recordStreak }),
        AutoRule(key: "egg_streak_365", title: "全年无休", desc: "连续 365 天记录世界日志", category: "egg", goal: 365, current: { $0.recordStreak }),
        AutoRule(key: "egg_memo_emoji", title: "此时无声胜有声", desc: "写一条只有表情的日志", category: "egg", goal: 1, current: { $0.emojiOnlyMemos }),
        AutoRule(key: "egg_newyear", title: "元旦宝宝", desc: "生日是 1 月 1 日", category: "egg", goal: 1, current: { $0.newYearBirth })
    ]

    static func rule(_ key: String) -> AutoRule? { all.first { $0.key == key } }
}

// MARK: - 真实事件时间源（用于回填 unlockedAt）

struct AchievementEventSources {
    var doneAtList: [String] = []
    var itemCreatedList: [String] = []
    var collectionCreatedList: [String] = []
    var memoCreatedList: [String] = []
    var locationDateList: [String] = []
    var birthDate: String? = nil

    private func nth(_ list: [String], _ n: Int) -> String? {
        let cleaned = list.filter { !$0.isEmpty }.sorted()
        guard cleaned.count >= n else { return nil }
        return cleaned[n - 1]
    }

    func eventAt(for key: String) -> String? {
        switch key {
        case "first_task": return nth(doneAtList, 1)
        case "five_tasks": return nth(doneAtList, 5)
        case "ten_tasks": return nth(doneAtList, 10)
        case "thirty_tasks": return nth(doneAtList, 30)
        case "fifty_tasks": return nth(doneAtList, 50)
        case "hundred_tasks": return nth(doneAtList, 100)
        case "first_item": return DateUtils.dayToIso(nth(itemCreatedList, 1) ?? "")
        case "ten_items": return DateUtils.dayToIso(nth(itemCreatedList, 10) ?? "")
        case "fifty_items": return DateUtils.dayToIso(nth(itemCreatedList, 50) ?? "")
        case "first_collection": return DateUtils.dayToIso(nth(collectionCreatedList, 1) ?? "")
        case "ten_collections": return DateUtils.dayToIso(nth(collectionCreatedList, 10) ?? "")
        case "fifty_collections": return DateUtils.dayToIso(nth(collectionCreatedList, 50) ?? "")
        case "first_location": return DateUtils.dayToIso(nth(locationDateList, 1) ?? "")
        case "five_locations": return DateUtils.dayToIso(nth(locationDateList, 5) ?? "")
        case "twenty_locations": return DateUtils.dayToIso(nth(locationDateList, 20) ?? "")
        case "first_memo": return nth(memoCreatedList, 1)
        case "ten_memos": return nth(memoCreatedList, 10)
        case "fifty_memos": return nth(memoCreatedList, 50)
        case "day_100": return DateUtils.birthPlusDays(birthDate ?? "", days: 100).flatMap { DateUtils.dayToIso($0) }
        case "day_365": return DateUtils.birthPlusDays(birthDate ?? "", days: 365).flatMap { DateUtils.dayToIso($0) }
        case "day_1000": return DateUtils.birthPlusDays(birthDate ?? "", days: 1000).flatMap { DateUtils.dayToIso($0) }
        case "day_5000": return DateUtils.birthPlusDays(birthDate ?? "", days: 5000).flatMap { DateUtils.dayToIso($0) }
        case "day_10000": return DateUtils.birthPlusDays(birthDate ?? "", days: 10000).flatMap { DateUtils.dayToIso($0) }
        case "adult_18": return DateUtils.birthPlusYears(birthDate ?? "", years: 18).flatMap { DateUtils.dayToIso($0) }
        case "all_rounder", "five_star", "grand_slam":
            let candidates = [
                nth(doneAtList, 1),
                DateUtils.dayToIso(nth(itemCreatedList, 1) ?? ""),
                DateUtils.dayToIso(nth(collectionCreatedList, 1) ?? ""),
                nth(memoCreatedList, 1),
                DateUtils.dayToIso(nth(locationDateList, 1) ?? "")
            ].compactMap { $0 }.filter { !$0.isEmpty }.sorted()
            return candidates.first
        default: return nil
        }
    }
}
