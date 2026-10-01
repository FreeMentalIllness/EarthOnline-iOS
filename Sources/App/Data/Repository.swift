import Foundation
import SwiftData

/// 数据读写收口层（SwiftData 版 Repository）
/// 说明：数据量是个人级规模（百～千条），统一内存过滤，避免 #Predicate 在跨 Swift 版本时的兼容坑。
@MainActor
final class Repository: ObservableObject {
    let context: ModelContext

    init(context: ModelContext) { self.context = context }

    // MARK: - 基础读写

    func all<T: PersistentModel>(_ type: T.Type) -> [T] {
        (try? context.fetch(FetchDescriptor<T>())) ?? []
    }

    func save() {
        try? context.save()
    }

    func delete<T: PersistentModel>(_ object: T) {
        context.delete(object)
        save()
    }

    // MARK: - 回收站（v1.0.5：删除先进回收站，30 天可恢复）

    static let recycleBinRetentionDays = 30

    /// 只看未删除数据（导出 / 统计 / UI 一律走这里）
    func active<T: SoftDeletable>(_ type: T.Type) -> [T] {
        all(type).filter { $0.deletedAt == nil }
    }

    /// 回收站内容（按删除时间倒序）
    func recycleBin() -> [SoftDeletable] {
        var merged: [SoftDeletable] = []
        merged.append(contentsOf: all(TaskItem.self).filter { $0.deletedAt != nil })
        merged.append(contentsOf: all(MemoItem.self).filter { $0.deletedAt != nil })
        merged.append(contentsOf: all(BagItem.self).filter { $0.deletedAt != nil })
        merged.append(contentsOf: all(CollectionItem.self).filter { $0.deletedAt != nil })
        merged.append(contentsOf: all(LocationPin.self).filter { $0.deletedAt != nil })
        return merged.sorted { ($0.deletedAt ?? Date.distantPast) > ($1.deletedAt ?? Date.distantPast) }
    }

    func softDelete(_ object: SoftDeletable) {
        object.deletedAt = Date()
        save()
    }

    func softDeleteAll(_ objects: [SoftDeletable]) {
        objects.forEach { $0.deletedAt = Date() }
        save()
    }

    func restore(_ object: SoftDeletable) {
        object.deletedAt = nil
        save()
    }

    func purge(_ object: SoftDeletable) {
        context.delete(object)
        save()
    }

    /// 清空回收站（物理删除）
    func emptyRecycleBin() {
        recycleBin().forEach { context.delete($0) }
        save()
    }

    /// 启动时清理超过保留期的回收站条目
    func purgeExpiredDeleted() {
        let cutoff = Date().addingTimeInterval(-Double(Self.recycleBinRetentionDays) * 86400)
        recycleBin().filter { ($0.deletedAt ?? Date()) < cutoff }.forEach { context.delete($0) }
        save()
    }

    // MARK: - 个人资料

    @discardableResult
    func profile() -> ProfileItem {
        if let existing = all(ProfileItem.self).first { return existing }
        let created = ProfileItem()
        context.insert(created)
        save()
        return created
    }

    // MARK: - 任务

    func tasks(category: TaskCategory? = nil, includeDone: Bool = true) -> [TaskItem] {
        let list = all(TaskItem.self).filter { task in
            guard let category else { return true }
            return task.category == category.rawValue
        }
        let filtered = includeDone ? list : list.filter { $0.status != TaskStatus.done.rawValue }
        return filtered.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.createdAt < rhs.createdAt
        }
    }

    func addTask(title: String, category: TaskCategory, dueDate: String? = nil, note: String? = nil, parentId: String? = nil) -> TaskItem {
        let task = TaskItem(title: title, category: category.rawValue)
        task.dueDate = dueDate
        task.note = note
        task.parentId = parentId
        task.sortOrder = (all(TaskItem.self).map { $0.sortOrder }.max() ?? 0) + 1
        context.insert(task)
        save()
        return task
    }

    func updateTask(_ task: TaskItem, title: String? = nil, status: TaskStatus? = nil,
                    progress: Int? = nil, note: String? = nil, dueDate: String? = nil) {
        if let title { task.title = title }
        if let status { task.status = status.rawValue }
        if let progress { task.progress = min(100, max(0, progress)) }
        if let note { task.note = note }
        if let dueDate { task.dueDate = dueDate.isEmpty ? nil : dueDate }
        task.lastModified = DateUtils.todayKey()
        save()
    }

    /// 完成 / 撤销完成（doneAt 是「完成任务数」的唯一口径，非 done 必须为 nil）
    func toggleTaskDone(_ task: TaskItem) {
        if task.status == TaskStatus.done.rawValue {
            let undone = XpEventItem(kind: "task", amount: -XpRules.taskDone, reason: "撤销完成：\(task.title)")
            context.insert(undone)
            task.status = TaskStatus.active.rawValue
            task.doneAt = nil
            task.progress = max(0, task.progress)
        } else {
            let now = DateUtils.isoNow()
            let event = XpEventItem(kind: "task", amount: XpRules.taskDone, reason: "完成任务：\(task.title)")
            context.insert(event)
            task.status = TaskStatus.done.rawValue
            task.doneAt = now
            task.progress = 100
            logActivity(kind: .task, title: "完成任务：\(task.title)")
        }
        task.lastModified = DateUtils.todayKey()
        save()
    }

    // MARK: - 世界日志

    func memos(type: MemoType? = nil) -> [MemoItem] {
        let list = all(MemoItem.self)
        let filtered = list.filter { memo in
            guard let type else { return true }
            return memo.type == type.rawValue
        }
        return filtered.sorted { $0.createdAt > $1.createdAt }
    }

    func addMemo(text: String, type: MemoType = .note) -> MemoItem {
        let memo = MemoItem(text: text, type: type.rawValue)
        context.insert(memo)
        let event = XpEventItem(kind: "memo", amount: XpRules.memo, reason: "记录世界日志")
        context.insert(event)
        logActivity(kind: .memo, title: text)
        save()
        return memo
    }

    // MARK: - 背包物品

    func addItem(name: String, desc: String? = nil, category: String? = nil, itemType: String = "physical") -> BagItem {
        let item = BagItem(name: name, itemType: itemType, category: category)
        item.desc = desc
        context.insert(item)
        let event = XpEventItem(kind: "item", amount: XpRules.item, reason: "拾取物品：\(name)")
        context.insert(event)
        logActivity(kind: .item, title: "拾取物品：\(name)")
        save()
        return item
    }

    func addCollection(title: String, note: String? = nil, category: String? = nil,
                       fileUri: String? = nil, fileMetaJson: String? = nil) -> CollectionItem {
        let collection = CollectionItem(title: title, category: category)
        collection.note = note
        collection.fileUri = fileUri
        collection.fileMetaJson = fileMetaJson
        context.insert(collection)
        save()
        return collection
    }

    // MARK: - 足迹

    func addLocation(name: String, lat: Double, lng: Double, date: String = DateUtils.todayKey(),
                     note: String? = nil, tags: [String] = []) -> LocationPin {
        let pin = LocationPin(name: name, lat: lat, lng: lng)
        pin.date = date
        pin.note = note
        pin.tags = tags
        context.insert(pin)
        let event = XpEventItem(kind: "location", amount: XpRules.location, reason: "新增足迹：\(name)")
        context.insert(event)
        save()
        return pin
    }

    // MARK: - 成就

    @discardableResult
    func unlockAchievement(id: String, title: String, desc: String, category: String, at: String? = nil) -> Bool {
        let list = all(AchievementItem.self)
        if let existing = list.first(where: { $0.recordId == id }) {
            guard existing.unlocked == false else { return false }
            existing.unlocked = true
            existing.unlockedAt = at ?? DateUtils.isoNow()
            let event = XpEventItem(kind: "ach", amount: XpRules.achievement, reason: "解锁成就：\(title)")
            context.insert(event)
            logActivity(kind: .ach, title: "解锁成就：\(title)")
            save()
            return true
        }
        let created = AchievementItem(title: title, achDesc: desc, type: "auto", autoKey: id, category: category)
        created.unlocked = true
        created.unlockedAt = at ?? DateUtils.isoNow()
        context.insert(created)
        let event = XpEventItem(kind: "ach", amount: XpRules.achievement, reason: "解锁成就：\(title)")
        context.insert(event)
        logActivity(kind: .ach, title: "解锁成就：\(title)")
        save()
        return true
    }

    func addManualAchievement(title: String, desc: String, category: String = "custom") {
        let item = AchievementItem(title: title, achDesc: desc, type: "manual", autoKey: nil, category: category)
        context.insert(item)
        save()
    }

    // MARK: - 分类

    func categories(scope: String) -> [BagCategoryItem] {
        all(BagCategoryItem.self)
            .filter { $0.scope == scope }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func addCategory(name: String, scope: String) -> BagCategoryItem {
        let existing = all(BagCategoryItem.self).filter { $0.scope == scope }
        let category = BagCategoryItem(name: name, scope: scope, sortOrder: (existing.map { $0.sortOrder }.max() ?? -1) + 1)
        context.insert(category)
        save()
        return category
    }

    /// 删除分类：引用它的条目回落为「未分类」，条目本身保留（三端一致语义）
    func deleteCategory(_ category: BagCategoryItem) {
        let id = category.recordId
        if category.scope == "item" {
            all(BagItem.self).filter { $0.category == id }.forEach { $0.category = nil }
        } else {
            all(CollectionItem.self).filter { $0.category == id }.forEach { $0.category = nil }
        }
        delete(category)
    }

    // MARK: - 最近动态（环形裁剪 50 条，与三端一致）

    func logActivity(kind: ActivityKind, title: String) {
        let item = ActivityItem(kind: kind.rawValue, title: title)
        context.insert(item)
        let sorted = all(ActivityItem.self).sorted { $0.time > $1.time }
        if sorted.count > 50 {
            sorted.dropFirst(50).forEach { context.delete($0) }
        }
        save()
    }

    func recentActivities(limit: Int = 3) -> [ActivityItem] {
        let list = all(ActivityItem.self).sorted { $0.time > $1.time }
        guard limit > 0 else { return list }
        return Array(list.prefix(limit))
    }

    // MARK: - 清空数据（保留 App 设置，与 Android clearAllData / Web resetAllData 同语义）

    func clearAllData() {
        all(TaskItem.self).forEach { context.delete($0) }
        all(MemoItem.self).forEach { context.delete($0) }
        all(BagItem.self).forEach { context.delete($0) }
        all(AchievementItem.self).forEach { context.delete($0) }
        all(CollectionItem.self).forEach { context.delete($0) }
        all(LocationPin.self).forEach { context.delete($0) }
        all(ActivityItem.self).forEach { context.delete($0) }
        all(BagCategoryItem.self).forEach { context.delete($0) }
        all(XpEventItem.self).forEach { context.delete($0) }
        all(ProfileItem.self).forEach { context.delete($0) }
        // 重建空种子资料行，避免「行缺失 = 未初始化」的语义误判
        context.insert(ProfileItem())
        try? LocalFileStore.deleteAllContent()
        save()
    }
}
