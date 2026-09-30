import Foundation

// MARK: - 备份数据契约（earth-online-backup.json）
// 字段命名、取值范围与 Android BackupRepository.Payload / Web backup.js / Windows 导出完全一致：
// version / exportedAt / profile / tasks / memos / items / achievements / collections / locations / activities

struct BackupPayload: Codable {
    var version: Int?
    var exportedAt: String?
    var profile: ProfileDTO?
    var tasks: [TaskDTO]?
    var memos: [MemoDTO]?
    var items: [ItemDTO]?
    var achievements: [AchievementDTO]?
    var collections: [CollectionDTO]?
    var locations: [LocationDTO]?
    var activities: [ActivityDTO]?

    enum CodingKeys: String, CodingKey {
        case version, exportedAt, profile, tasks, memos, items, achievements, collections, locations, activities
    }

    init(exportedAt: String? = nil, profile: ProfileDTO? = nil, tasks: [TaskDTO]? = nil,
         memos: [MemoDTO]? = nil, items: [ItemDTO]? = nil, achievements: [AchievementDTO]? = nil,
         collections: [CollectionDTO]? = nil, locations: [LocationDTO]? = nil, activities: [ActivityDTO]? = nil) {
        self.version = 1
        self.exportedAt = exportedAt
        self.profile = profile
        self.tasks = tasks
        self.memos = memos
        self.items = items
        self.achievements = achievements
        self.collections = collections
        self.locations = locations
        self.activities = activities
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version)
        exportedAt = try c.decodeIfPresent(String.self, forKey: .exportedAt)
        profile = try c.decodeIfPresent(ProfileDTO.self, forKey: .profile)
        tasks = try c.decodeIfPresent([TaskDTO].self, forKey: .tasks)
        memos = try c.decodeIfPresent([MemoDTO].self, forKey: .memos)
        items = try c.decodeIfPresent([ItemDTO].self, forKey: .items)
        achievements = try c.decodeIfPresent([AchievementDTO].self, forKey: .achievements)
        collections = try c.decodeIfPresent([CollectionDTO].self, forKey: .collections)
        locations = try c.decodeIfPresent([LocationDTO].self, forKey: .locations)
        activities = try c.decodeIfPresent([ActivityDTO].self, forKey: .activities)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(version, forKey: .version)
        try c.encodeIfPresent(exportedAt, forKey: .exportedAt)
        try c.encodeIfPresent(profile, forKey: .profile)
        try c.encodeIfPresent(tasks, forKey: .tasks)
        try c.encodeIfPresent(memos, forKey: .memos)
        try c.encodeIfPresent(items, forKey: .items)
        try c.encodeIfPresent(achievements, forKey: .achievements)
        try c.encodeIfPresent(collections, forKey: .collections)
        try c.encodeIfPresent(locations, forKey: .locations)
        try c.encodeIfPresent(activities, forKey: .activities)
    }
}

/// Web 端内部封装格式 { state: {...} } 的兼容壳
struct BackupFileWrapper: Codable {
    let state: BackupPayload?
}

struct ProfileDTO: Codable {
    var id: Int?
    var name: String?
    var avatarKey: String?
    var avatarPath: String?
    /// Base64 内联头像（导出时写入，导入时落成沙盒文件）
    var avatarData: String?
    var gender: String?
    var country: String?
    var province: String?
    var signature: String?
    var birthDate: String?
    var xp: Int?
    var customFieldsJson: String?
}

struct TaskDTO: Codable {
    var id: String
    var parentId: String?
    var category: String?
    var title: String?
    var status: String?
    var progress: Int?
    var note: String?
    var dueDate: String?
    var createdAt: String?
    var lastModified: String?
    var doneAt: String?
    /// 契约里是 order（Android sortOrder 列名）
    var order: Int?
}

struct MemoDTO: Codable {
    var id: String
    var text: String?
    var type: String?
    var createdAt: String?
}

struct ItemDTO: Codable {
    var id: String
    var name: String?
    var type: String?
    var description: String?
    var category: String?
    var createdAt: String?
}

struct AchievementDTO: Codable {
    var id: String
    var title: String?
    var desc: String?
    var type: String?
    var autoKey: String?
    var unlocked: Bool?
    var unlockedAt: String?
    var category: String?
}

struct CollectionDTO: Codable {
    var id: String
    var category: String?
    var title: String?
    var note: String?
    var fileMetaJson: String?
    var fileUri: String?
    var createdAt: String?
}

struct LocationDTO: Codable {
    var id: String
    var name: String?
    var lat: Double?
    var lng: Double?
    var date: String?
    var note: String?
    var tagsJson: String?
    /// Web 内部格式用 tags 数组，导入时两边都吃
    var tags: [String]?
}

struct ActivityDTO: Codable {
    var id: String
    var time: String?
    var kind: String?
    var title: String?
}
