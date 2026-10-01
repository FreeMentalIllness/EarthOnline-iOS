import Foundation

// MARK: - 枚举（原始值与 Android / Web / Windows 三端一致）

enum TaskCategory: String, CaseIterable, Identifiable {
    case main = "main"
    case side = "side"
    case todo = "todo"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .main: return "主线任务"
        case .side: return "支线任务"
        case .todo: return "待办 ToDo"
        }
    }

    var emoji: String {
        switch self {
        case .main: return "🎯"
        case .side: return "🌿"
        case .todo: return "✅"
        }
    }
}

enum TaskStatus: String, CaseIterable, Identifiable {
    case planning = "planning"
    case active = "active"
    case paused = "paused"
    case done = "done"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .planning: return "筹划中"
        case .active: return "进行中"
        case .paused: return "已搁置"
        case .done: return "已完成"
        }
    }
}

enum MemoType: String, CaseIterable, Identifiable {
    case note = "note"
    case important = "important"
    case idea = "idea"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .note: return "碎碎念"
        case .important: return "重要"
        case .idea: return "灵感"
        }
    }

    var emoji: String {
        switch self {
        case .note: return "📝"
        case .important: return "⭐️"
        case .idea: return "💡"
        }
    }
}

enum ActivityKind: String, CaseIterable, Identifiable {
    case task = "task"
    case ach = "ach"
    case item = "item"
    case memo = "memo"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .task: return "✅"
        case .ach: return "🏅"
        case .item: return "🎒"
        case .memo: return "📝"
        }
    }
}

// MARK: - 日期工具

enum DateUtils {
    static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func todayKey() -> String { dayKeyFormatter.string(from: Date()) }

    static func isoNow() -> String { isoFormatter.string(from: Date()) }

    /// 日键 → ISO（中午 12 点，避免跨时区边界偏移）
    static func dayToIso(_ day: String) -> String? {
        let source = day.count > 10 ? String(day.prefix(10)) : day
        guard let date = dayKeyFormatter.date(from: source) else { return nil }
        let noon = Calendar.current.startOfDay(for: date).addingTimeInterval(12 * 3600)
        return isoFormatter.string(from: noon)
    }

    /// ISO → 本地日键
    static func dayOfIso(_ iso: String) -> String {
        guard let date = isoFormatter.date(from: iso) else { return todayKey() }
        return dayKeyFormatter.string(from: date)
    }

    /// ISO → 本地小时（0-23）
    static func hourOfIso(_ iso: String) -> Int? {
        guard let date = isoFormatter.date(from: iso) else { return nil }
        return Calendar.current.component(.hour, from: date)
    }

    /// 相差天数（自然日）
    static func daysBetween(from start: Date, to end: Date = Date()) -> Int {
        let cal = Calendar.current
        let a = cal.startOfDay(for: start)
        let b = cal.startOfDay(for: end)
        return cal.dateComponents([.day], from: a, to: b).day ?? 0
    }

    /// 有效期 ≥7 天开头的日期字符串（如 2026-09-22）解析为 Date
    static func parseDay(_ day: String) -> Date? { dayKeyFormatter.date(from: day) }

    /// 周岁（等级）
    static func age(from birthDate: String) -> Int {
        guard let birth = parseDay(birthDate) else { return 0 }
        let comps = Calendar.current.dateComponents([.year], from: birth, to: Date())
        return max(0, comps.year ?? 0)
    }

    /// 存活天数
    static func daysLived(from birthDate: String) -> Int {
        guard let birth = parseDay(birthDate) else { return 0 }
        return max(0, daysBetween(from: birth))
    }

    /// 距下一个生日的进度 0~1
    static func nextBirthdayProgress(from birthDate: String) -> Double {
        guard let birth = parseDay(birthDate) else { return 0 }
        let cal = Calendar.current
        let age = self.age(from: birthDate)
        guard let last = cal.date(byAdding: .year, value: age, to: birth),
              let next = cal.date(byAdding: .year, value: age + 1, to: birth) else { return 0 }
        let total = next.timeIntervalSince(last)
        guard total > 0 else { return 0 }
        return min(1, max(0, Date().timeIntervalSince(last) / total))
    }

    /// birthDate + N 天的日键
    static func birthPlusDays(_ birthDate: String, days: Int) -> String? {
        guard let birth = parseDay(birthDate) else { return nil }
        guard let date = Calendar.current.date(byAdding: .day, value: days, to: birth) else { return nil }
        return dayKeyFormatter.string(from: date)
    }

    /// birthDate + N 年（日键）
    static func birthPlusYears(_ birthDate: String, years: Int) -> String? {
        guard let birth = parseDay(birthDate) else { return nil }
        guard let date = Calendar.current.date(byAdding: .year, value: years, to: birth) else { return nil }
        return dayKeyFormatter.string(from: date)
    }

    /// 最长连续记录天数
    static func longestStreak(days: [String]) -> Int {
        let sorted = Array(Set(days.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty })).sorted()
        var best = 0
        var current = 0
        var previous: Date? = nil
        for day in sorted {
            guard let date = dayKeyFormatter.date(from: day) else { continue }
            if let previous, let delta = Calendar.current.dateComponents([.day], from: previous, to: date).day, delta == 1 {
                current += 1
            } else {
                current = 1
            }
            previous = date
            best = max(best, current)
        }
        return best
    }

    /// 当前连续记录天数（截至今天；今天还没记录也容忍昨日衔接）
    static func currentStreak(days: [String]) -> Int {
        let sorted = Array(Set(days.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty })).sorted()
        guard let last = sorted.last, let lastDate = dayKeyFormatter.date(from: last) else { return 0 }
        // 今天或昨天有记录才可能算「连续中」
        guard daysBetween(from: lastDate) <= 1 else { return 0 }
        var streak = 1
        var cursor = lastDate
        for day in sorted.dropLast().reversed() {
            guard let date = dayKeyFormatter.date(from: day),
                  let delta = Calendar.current.dateComponents([.day], from: date, to: cursor).day, delta == 1 else { break }
            streak += 1
            cursor = date
        }
        return streak
    }

    /// 日键的「月-日」后缀（历年今日匹配用）
    static func monthDay(of day: String) -> String {
        day.count >= 10 ? String(day.suffix(5)) : ""
    }

    /// 时段问候（带一句心情后缀的活力短语由调用方拼接）
    static func moodFlavor(_ mood: String) -> String {
        switch mood {
        case "great": return "状态拉满，去创造点什么"
        case "good": return "顺风局，稳住节奏"
        case "normal": return "平平淡淡也是真实日常"
        case "tired": return "累了就慢一点，记录也是一种休息"
        case "down": return "低气压会过去的，先记一笔"
        default: return ""
        }
    }

    /// 相对时间中文描述
    static func relative(_ iso: String) -> String {
        guard let date = isoFormatter.date(from: iso) else { return "" }
        let delta = Int(Date().timeIntervalSince(date))
        if delta < 60 { return "刚刚" }
        if delta < 3600 { return "\(delta / 60) 分钟前" }
        if delta < 86400 { return "\(delta / 3600) 小时前" }
        if delta < 86400 * 30 { return "\(delta / 86400) 天前" }
        if delta < 86400 * 365 { return "\(delta / (86400 * 30)) 个月前" }
        return "\(delta / (86400 * 365)) 年前"
    }

    /// 时段问候
    static func greeting(date: Date = Date()) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<11: return "早上好"
        case 11..<13: return "中午好"
        case 13..<18: return "下午好"
        case 18..<23: return "晚上好"
        default: return "夜深了"
        }
    }
}
