import Foundation
import SwiftData

// MARK: - 个人资料（对应 profile 表，全库仅一行，id 固定为 1）

@Model
final class ProfileItem {
    @Attribute(.unique) var recordId: Int = 1
    var name: String = ""
    var avatarKey: String = ""
    var avatarPath: String? = nil
    var gender: String = ""
    var country: String = ""
    var province: String = ""
    var signature: String = ""
    var birthDate: String = ""
    var xp: Int = 0
    var customFieldsJson: String = ""

    init() {}
}

// MARK: - 经验流水（对应 xp_events 表，仅审计，不参与 XP 计算）

@Model
final class XpEventItem {
    @Attribute(.unique) var recordId: String = UUID().uuidString
    var kind: String = "custom"
    var amount: Int = 0
    var reason: String = ""
    var createdAt: String = DateUtils.isoNow()
    var date: String = DateUtils.todayKey()

    init(kind: String, amount: Int, reason: String, createdAt: String? = nil, date: String? = nil) {
        self.kind = kind
        self.amount = amount
        self.reason = reason
        self.createdAt = createdAt ?? DateUtils.isoNow()
        self.date = date ?? DateUtils.todayKey()
    }
}

// MARK: - 任务（对应 tasks 表）

@Model
final class TaskItem {
    @Attribute(.unique) var recordId: String = UUID().uuidString
    var parentId: String? = nil
    var category: String = TaskCategory.todo.rawValue
    var title: String = ""
    var status: String = TaskStatus.planning.rawValue
    var progress: Int = 0
    var note: String? = nil
    var dueDate: String? = nil
    var createdAt: String = DateUtils.todayKey()
    var lastModified: String = DateUtils.todayKey()
    var doneAt: String? = nil
    var sortOrder: Int = 0

    init(title: String, category: String, status: String = TaskStatus.planning.rawValue) {
        self.title = title
        self.category = category
        self.status = status
    }
}

// MARK: - 世界日志（对应 memos 表）

@Model
final class MemoItem {
    @Attribute(.unique) var recordId: String = UUID().uuidString
    var text: String = ""
    var type: String = MemoType.note.rawValue
    var createdAt: String = DateUtils.isoNow()

    init(text: String, type: String = MemoType.note.rawValue) {
        self.text = text
        self.type = type
    }
}

// MARK: - 背包物品（对应 items 表）

@Model
final class BagItem {
    @Attribute(.unique) var recordId: String = UUID().uuidString
    var name: String = ""
    var itemType: String = "physical"
    var desc: String? = nil
    var category: String? = nil
    var createdAt: String = DateUtils.todayKey()

    init(name: String, itemType: String = "physical", category: String? = nil) {
        self.name = name
        self.itemType = itemType
        self.category = category
    }
}

// MARK: - 成就（对应 achievements 表）

@Model
final class AchievementItem {
    @Attribute(.unique) var recordId: String = UUID().uuidString
    var title: String = ""
    var achDesc: String = ""
    var type: String = "manual"
    var autoKey: String? = nil
    var unlocked: Bool = false
    var unlockedAt: String? = nil
    var category: String? = nil

    init(title: String, achDesc: String, type: String = "manual", autoKey: String? = nil, category: String? = "custom") {
        self.title = title
        self.achDesc = achDesc
        self.type = type
        self.autoKey = autoKey
        self.category = category
    }
}

// MARK: - 收藏（对应 collections 表）

@Model
final class CollectionItem {
    @Attribute(.unique) var recordId: String = UUID().uuidString
    var category: String? = nil
    var title: String = ""
    var note: String? = nil
    var fileMetaJson: String? = nil
    var fileUri: String? = nil
    var createdAt: String = DateUtils.todayKey()

    init(title: String, category: String? = nil) {
        self.title = title
        self.category = category
    }
}

// MARK: - 足迹（对应 locations 表）

@Model
final class LocationPin {
    @Attribute(.unique) var recordId: String = UUID().uuidString
    var name: String = ""
    var lat: Double = 0
    var lng: Double = 0
    var date: String = DateUtils.todayKey()
    var note: String? = nil
    var tagsJson: String? = nil

    init(name: String, lat: Double, lng: Double) {
        self.name = name
        self.lat = lat
        self.lng = lng
    }

    var tags: [String] {
        get {
            guard let data = tagsJson?.data(using: .utf8) else { return [] }
            let list = try? JSONDecoder().decode([String].self, from: data)
            return list ?? []
        }
        set {
            let data = try? JSONEncoder().encode(Array(newValue.prefix(30)))
            tagsJson = data.flatMap { String(data: $0, encoding: .utf8) }
        }
    }
}

// MARK: - 最近动态（对应 activities 表，最多 50 条）

@Model
final class ActivityItem {
    @Attribute(.unique) var recordId: String = UUID().uuidString
    var time: String = DateUtils.isoNow()
    var kind: String = "task"
    var title: String = ""

    init(kind: String, title: String, time: String? = nil) {
        self.kind = kind
        self.title = title
        self.time = time ?? DateUtils.isoNow()
    }
}

// MARK: - 背包/收藏分类（对应 bag_categories 表）

@Model
final class BagCategoryItem {
    @Attribute(.unique) var recordId: String = UUID().uuidString
    var name: String = ""
    var scope: String = "item"
    var sortOrder: Int = 0

    init(name: String, scope: String, sortOrder: Int = 0) {
        self.name = name
        self.scope = scope
        self.sortOrder = sortOrder
    }
}
