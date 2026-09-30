import Foundation

// MARK: - 主 App 与小组件之间的数据快照
//
// 说明（重要）：iOS 上 App 与 Extension 共享数据的正路是 App Group，
// 但 App Group 需要在签名里带 com.apple.security.application-groups，
// 免费 Apple ID / SideStore 场景下大概率拿不到授权，反而会导致安装失败。
// 因此这里的读取一律做「尽力而为」：拿得到容器就写，拿不到就返回 nil，
// 小组件降级展示静态卡片 + 深链入口，绝不因为共享失败而崩或白屏。

struct WidgetSnapshot: Codable, Equatable {
    var updatedAt: String = ""
    var name: String = ""
    var level: Int = 0
    var xp: Int = 0
    var nextLevelProgress: Double = 0
    var openTasks: Int = 0
    var todayDone: Int = 0
    var streakDays: Int = 0
    var daysLived: Int = 0
    var memos: Int = 0
    var locations: Int = 0
    var items: Int = 0
    var usingSharedContainer: Bool = false

    static var placeholder: WidgetSnapshot {
        var value = WidgetSnapshot()
        value.name = "旅行者"
        value.level = 0
        value.openTasks = 0
        return value
    }
}

enum SharedStore {
    static let appGroupId = "group.com.example.earthonline.shared"
    static let fileName = "widget_snapshot.json"

    static func containerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
    }

    static func save(_ snapshot: WidgetSnapshot) {
        guard let dir = containerURL() else { return }
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: dir.appendingPathComponent(fileName), options: .atomic)
        } catch {
            // 共享容器不可用时静默跳过：降级由小组件侧处理
        }
    }

    static func load() -> WidgetSnapshot? {
        guard let dir = containerURL() else { return nil }
        do {
            let data = try Data(contentsOf: dir.appendingPathComponent(fileName))
            return try JSONDecoder().decode(WidgetSnapshot.self, from: data)
        } catch {
            return nil
        }
    }
}
