import Foundation
import SwiftData

/// SwiftData 容器（等价 Android Room / Windows EF Core 的数据层入口）
enum AppContainer {
    static let schema = Schema([
        ProfileItem.self,
        XpEventItem.self,
        TaskItem.self,
        MemoItem.self,
        BagItem.self,
        AchievementItem.self,
        CollectionItem.self,
        LocationPin.self,
        ActivityItem.self,
        BagCategoryItem.self
    ])

    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        if inMemory {
            return try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        }
        // 物理存储放在 Application Support，避免被系统清理文档目录时牵连
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("EarthOnline", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("earth_online.store")
        let config = ModelConfiguration(url: url, allowsSave: true)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            // 兜底：库损坏时重建，宁可丢本地缓存也不能白屏
            try? FileManager.default.removeItem(at: url)
            return try! ModelContainer(for: schema, configurations: config)
        }
    }
}
