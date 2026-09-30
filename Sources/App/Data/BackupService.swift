import Foundation
import SwiftData

/// 导入结果统计
struct ImportSummary {
    var inserted: Int = 0
    var updated: Int = 0

    mutating func add(inserted: Int = 0, updated: Int = 0) {
        self.inserted += inserted
        self.updated += updated
    }
}

enum BackupServiceError: Error { case decodeFailed }

/// 备份导出 / 导入 —— 契约与三端完全一致，导入严格按主键合并，绝不整包覆盖
@MainActor
final class BackupService {
    private let repo: Repository

    init(repo: Repository) { self.repo = repo }

    // MARK: - 解码

    static func decode(_ data: Data) throws -> BackupPayload {
        let decoder = JSONDecoder()
        if let flat = try? decoder.decode(BackupPayload.self, from: data), !flat.isEmpty {
            return flat
        }
        if let wrapper = try? decoder.decode(BackupFileWrapper.self, from: data), let state = wrapper.state {
            return state
        }
        throw BackupServiceError.decodeFailed
    }

    // MARK: - 导出

    func exportPayload() -> BackupPayload {
        let profile = repo.profile()
        // 导出前对账 XP，保证导出值与派生口径一致（与 Android BackupRepository.runCatching{reconcile} 同语义）
        _ = Self.derivedXp(for: profile, context: repo.context)
        return BackupPayload(
            exportedAt: DateUtils.isoNow(),
            profile: Self.profileDTO(from: profile),
            tasks: repo.all(TaskItem.self).map { Self.taskDTO(from: $0) },
            memos: repo.all(MemoItem.self).map { Self.memoDTO(from: $0) },
            items: repo.all(BagItem.self).map { Self.itemDTO(from: $0) },
            achievements: repo.all(AchievementItem.self).map { Self.achievementDTO(from: $0) },
            collections: repo.all(CollectionItem.self).map { Self.collectionDTO(from: $0) },
            locations: repo.all(LocationPin.self).map { Self.locationDTO(from: $0) },
            activities: repo.all(ActivityItem.self).map { Self.activityDTO(from: $0) }
        )
    }

    func exportData(pretty: Bool = true) throws -> Data {
        let encoder = JSONEncoder()
        if pretty { encoder.outputFormatting = [.prettyPrinted, .sortedKeys] }
        return try encoder.encode(exportPayload())
    }

    // MARK: - 导入（按主键合并）

    func importPayload(_ payload: BackupPayload) -> ImportSummary {
        var summary = ImportSummary()
        if let profile = payload.profile { mergeProfile(profile) }

        for dto in payload.tasks ?? [] {
            if let existing = repo.all(TaskItem.self).first(where: { $0.recordId == dto.id }) {
                apply(dto, to: existing)
                summary.add(updated: 1)
            } else {
                let created = TaskItem(title: dto.title ?? "", category: dto.category ?? TaskCategory.todo.rawValue)
                created.recordId = dto.id
                repo.context.insert(created)
                apply(dto, to: created)
                summary.add(inserted: 1)
            }
        }

        for dto in payload.memos ?? [] {
            if let existing = repo.all(MemoItem.self).first(where: { $0.recordId == dto.id }) {
                existing.text = dto.text ?? existing.text
                existing.type = dto.type ?? existing.type
                existing.createdAt = dto.createdAt ?? existing.createdAt
                summary.add(updated: 1)
            } else {
                let created = MemoItem(text: dto.text ?? "", type: dto.type ?? MemoType.note.rawValue)
                created.recordId = dto.id
                created.createdAt = dto.createdAt ?? DateUtils.isoNow()
                repo.context.insert(created)
                summary.add(inserted: 1)
            }
        }

        for dto in payload.items ?? [] {
            if let existing = repo.all(BagItem.self).first(where: { $0.recordId == dto.id }) {
                existing.name = dto.name ?? existing.name
                existing.itemType = dto.type ?? existing.itemType
                existing.desc = dto.description ?? existing.desc
                existing.category = dto.category ?? existing.category
                summary.add(updated: 1)
            } else {
                let created = BagItem(name: dto.name ?? "", itemType: dto.type ?? "physical", category: dto.category)
                created.recordId = dto.id
                created.desc = dto.description
                created.createdAt = dto.createdAt ?? DateUtils.todayKey()
                repo.context.insert(created)
                summary.add(inserted: 1)
            }
        }

        for dto in payload.achievements ?? [] {
            if let existing = repo.all(AchievementItem.self).first(where: { $0.recordId == dto.id }) {
                existing.title = dto.title ?? existing.title
                existing.achDesc = dto.desc ?? existing.achDesc
                existing.category = dto.category ?? existing.category
                existing.unlocked = dto.unlocked ?? existing.unlocked
                existing.unlockedAt = dto.unlockedAt ?? existing.unlockedAt
                summary.add(updated: 1)
            } else {
                let created = AchievementItem(title: dto.title ?? "", achDesc: dto.desc ?? "",
                                              type: dto.type ?? "manual", autoKey: dto.autoKey, category: dto.category)
                created.recordId = dto.id
                created.unlocked = dto.unlocked ?? false
                created.unlockedAt = dto.unlockedAt
                repo.context.insert(created)
                summary.add(inserted: 1)
            }
        }

        for dto in payload.collections ?? [] {
            if let existing = repo.all(CollectionItem.self).first(where: { $0.recordId == dto.id }) {
                existing.title = dto.title ?? existing.title
                existing.note = dto.note ?? existing.note
                existing.category = dto.category ?? existing.category
                existing.fileMetaJson = dto.fileMetaJson ?? existing.fileMetaJson
                existing.fileUri = dto.fileUri ?? existing.fileUri
                summary.add(updated: 1)
            } else {
                let created = CollectionItem(title: dto.title ?? "", category: dto.category)
                created.recordId = dto.id
                created.note = dto.note
                created.fileMetaJson = dto.fileMetaJson
                created.fileUri = dto.fileUri
                created.createdAt = dto.createdAt ?? DateUtils.todayKey()
                repo.context.insert(created)
                summary.add(inserted: 1)
            }
        }

        for dto in payload.locations ?? [] {
            if let existing = repo.all(LocationPin.self).first(where: { $0.recordId == dto.id }) {
                existing.name = dto.name ?? existing.name
                existing.lat = dto.lat ?? existing.lat
                existing.lng = dto.lng ?? existing.lng
                existing.date = dto.date ?? existing.date
                existing.note = dto.note ?? existing.note
                if let tagsJson = dto.tagsJson { existing.tagsJson = tagsJson }
                if let tags = dto.tags, tagsJson(from: dto) == nil { existing.tags = tags }
                summary.add(updated: 1)
            } else {
                let created = LocationPin(name: dto.name ?? "", lat: dto.lat ?? 0, lng: dto.lng ?? 0)
                created.recordId = dto.id
                created.date = dto.date ?? DateUtils.todayKey()
                created.note = dto.note
                if let tagsJson = dto.tagsJson {
                    created.tagsJson = tagsJson
                } else if let tags = dto.tags {
                    created.tags = tags
                }
                repo.context.insert(created)
                summary.add(inserted: 1)
            }
        }

        for dto in payload.activities ?? [] {
            if let existing = repo.all(ActivityItem.self).first(where: { $0.recordId == dto.id }) {
                existing.time = dto.time ?? existing.time
                existing.kind = dto.kind ?? existing.kind
                existing.title = dto.title ?? existing.title
                summary.add(updated: 1)
            } else {
                let created = ActivityItem(kind: dto.kind ?? ActivityKind.task.rawValue, title: dto.title ?? "")
                created.recordId = dto.id
                created.time = dto.time ?? DateUtils.isoNow()
                repo.context.insert(created)
                summary.add(inserted: 1)
            }
        }

        repo.save()
        return summary
    }

    func importData(_ data: Data) throws -> ImportSummary {
        try importPayload(Self.decode(data))
    }

    // MARK: - 内部：profile

    private func tagsJson(from dto: LocationDTO) -> String? { dto.tagsJson }

    private func mergeProfile(_ dto: ProfileDTO) {
        let profile = repo.profile()
        if let name = dto.name, !name.isEmpty { profile.name = name }
        if let key = dto.avatarKey, !key.isEmpty { profile.avatarKey = key }
        if let gender = dto.gender, !gender.isEmpty { profile.gender = gender }
        if let country = dto.country, !country.isEmpty { profile.country = country }
        if let province = dto.province, !province.isEmpty { profile.province = province }
        if let signature = dto.signature, !signature.isEmpty { profile.signature = signature }
        if let birth = dto.birthDate, !birth.isEmpty { profile.birthDate = birth }
        if let xp = dto.xp, xp > 0 { profile.xp = xp }
        if let fields = dto.customFieldsJson, !fields.isEmpty { profile.customFieldsJson = fields }
        // 头像字节 → 沙盒原图文件（不重编码）
        if let base64 = dto.avatarData, let data = Data(base64Encoded: base64), !data.isEmpty {
            if let relative = LocalFileStore.save(data, into: "avatar", filename: "avatar.jpg") {
                profile.avatarPath = relative
            }
        }
    }

    // MARK: - 内部：DTO 转换

    private static func profileDTO(from item: ProfileItem) -> ProfileDTO {
        var dto = ProfileDTO()
        dto.id = item.recordId
        dto.name = item.name
        dto.avatarKey = item.avatarKey
        dto.avatarPath = item.avatarPath
        dto.gender = item.gender
        dto.country = item.country
        dto.province = item.province
        dto.signature = item.signature
        dto.birthDate = item.birthDate
        dto.xp = item.xp
        dto.customFieldsJson = item.customFieldsJson
        if let path = item.avatarPath, let data = LocalFileStore.load(path) {
            dto.avatarData = data.base64EncodedString()
        }
        return dto
    }

    /// 导出前对账 XP：保持与 profile.xp 单一事实源一致
    static func derivedXp(for profile: ProfileItem, context: ModelContext) -> Int {
        let tasksDone = ((try? context.fetch(FetchDescriptor<TaskItem>())) ?? []).filter { $0.doneAt != nil }.count
        let achievements = ((try? context.fetch(FetchDescriptor<AchievementItem>())) ?? []).filter { $0.unlocked }.count
        let memos = ((try? context.fetch(FetchDescriptor<MemoItem>())) ?? []).count
        let locations = ((try? context.fetch(FetchDescriptor<LocationPin>())) ?? []).count
        let items = ((try? context.fetch(FetchDescriptor<BagItem>())) ?? []).count
        let xp = XpRules.totalXp(tasksDone: tasksDone, achievements: achievements, memos: memos, locations: locations, items: items)
        profile.xp = xp
        return xp
    }

    private static func taskDTO(from item: TaskItem) -> TaskDTO {
        TaskDTO(id: item.recordId, parentId: item.parentId, category: item.category, title: item.title,
                status: item.status, progress: item.progress, note: item.note, dueDate: item.dueDate,
                createdAt: item.createdAt, lastModified: item.lastModified, doneAt: item.doneAt, order: item.sortOrder)
    }

    private func apply(_ dto: TaskDTO, to item: TaskItem) {
        item.parentId = dto.parentId ?? item.parentId
        item.title = dto.title ?? item.title
        item.status = dto.status ?? item.status
        item.progress = dto.progress ?? item.progress
        item.note = dto.note ?? item.note
        item.dueDate = dto.dueDate ?? item.dueDate
        item.createdAt = dto.createdAt ?? item.createdAt
        item.lastModified = dto.lastModified ?? item.lastModified
        item.doneAt = dto.doneAt ?? item.doneAt
        item.sortOrder = dto.order ?? item.sortOrder
    }

    private static func memoDTO(from item: MemoItem) -> MemoDTO {
        MemoDTO(id: item.recordId, text: item.text, type: item.type, createdAt: item.createdAt)
    }

    private static func itemDTO(from item: BagItem) -> ItemDTO {
        ItemDTO(id: item.recordId, name: item.name, type: item.itemType, description: item.desc,
                category: item.category, createdAt: item.createdAt)
    }

    private static func achievementDTO(from item: AchievementItem) -> AchievementDTO {
        AchievementDTO(id: item.recordId, title: item.title, desc: item.achDesc, type: item.type,
                       autoKey: item.autoKey, unlocked: item.unlocked, unlockedAt: item.unlockedAt, category: item.category)
    }

    private static func collectionDTO(from item: CollectionItem) -> CollectionDTO {
        CollectionDTO(id: item.recordId, category: item.category, title: item.title, note: item.note,
                      fileMetaJson: item.fileMetaJson, fileUri: item.fileUri, createdAt: item.createdAt)
    }

    private static func locationDTO(from item: LocationPin) -> LocationDTO {
        LocationDTO(id: item.recordId, name: item.name, lat: item.lat, lng: item.lng, date: item.date,
                    note: item.note, tagsJson: item.tagsJson, tags: item.tags.isEmpty ? nil : item.tags)
    }

    private static func activityDTO(from item: ActivityItem) -> ActivityDTO {
        ActivityDTO(id: item.recordId, time: item.time, kind: item.kind, title: item.title)
    }
}

extension BackupPayload {
    /// 是否含有任一业务字段（用于判断 flat 解码是否真的拿到了数据）
    var isEmpty: Bool {
        profile == nil && (tasks == nil) && (memos == nil) && (items == nil) &&
            (achievements == nil) && (collections == nil) && (locations == nil) && (activities == nil)
    }
}
