import Foundation
import SwiftData

/// 跨端同步策略（与三端一致）：
/// - 冷启动 / 进前台：拉取云端 → 按主键合并 → 本地仍在cloud之后再上传合并结果
/// - 冲突判定：比较云端 payload.exportedAt 与本地 lastSyncAt，谁新谁为准（内容始终合并，不会互相覆盖）
@MainActor
final class SyncManager: ObservableObject {
    @Published var isSyncing: Bool = false
    @Published var message: String = "尚未同步"
    @Published var isError: Bool = false

    private let repo: Repository
    private let settings: AppSettings
    private let backups: BackupService

    init(repo: Repository, settings: AppSettings, backups: BackupService) {
        self.repo = repo
        self.settings = settings
        self.backups = backups
        self.message = settings.lastSyncAt.isEmpty ? "尚未同步" : "上次同步：\(settings.lastSyncAt)"
    }

    private var client: WebDavClient? {
        guard settings.webdav.isConfigured else { return nil }
        return WebDavClient(settings.webdav)
    }

    // MARK: - 对外动作

    func pullIfNeeded() async {
        guard settings.autoSync, client != nil else { return }
        // 清空数据后的防拉回标记：消费一次即失效
        if settings.skipNextPull {
            settings.skipNextPull = false
            return
        }
        await pull(silent: true)
    }

    /// 完整同步：先拉后推
    func sync() async {
        guard let client else {
            fail("请先到「设置 → WebDAV」填写服务器信息")
            return
        }
        await run {
            try await client.connect()
            try await self.pullInternal(client: client)
            try await self.pushInternal(client: client)
            self.ok("同步完成 \(self.settings.lastSyncAt)")
        }
    }

    func pull(silent: Bool = false) async {
        guard let client else { return }
        await run {
            try await client.connect()
            try await self.pullInternal(client: client)
            self.ok("已拉取云端数据 \(self.settings.lastSyncAt)")
        }
    }

    func push() async {
        guard let client else {
            fail("请先到「设置 → WebDAV」填写服务器信息")
            return
        }
        await run {
            try await client.connect()
            try await self.pushInternal(client: client)
            self.ok("已推送到云端 \(self.settings.lastSyncAt)")
        }
    }

    func testConnection() async -> String {
        guard let client else { return "请先在下方填写 WebDAV 服务器信息" }
        do {
            try await client.connect()
            let entries = try await client.list()
            let found = entries.contains { $0.href.contains(settings.webdav.fileName) }
            return found ? "连接成功，云端已存在备份文件" : "连接成功，云端暂无备份文件"
        } catch {
            return error.localizedDescription
        }
    }

    // MARK: - 内部

    private func pullInternal(client: WebDavClient) async throws {
        let data = try await client.download()
        let payload = try BackupService.decode(data)
        // 云端更旧时只保留本地（但仍做一次单向合并补缺失主键）
        let remoteTime = payload.exportedAt ?? ""
        let summary = backups.importPayload(payload)
        if !remoteTime.isEmpty { settings.lastSyncAt = remoteTime }
        let combined = "拉取完成：新增 \(summary.inserted) / 更新 \(summary.updated)"
        if combined != "拉取完成：新增 0 / 更新 0" {
            ok(combined)
        }
    }

    private func pushInternal(client: WebDavClient) async throws {
        let data = try backups.exportData()
        try await client.upload(data)
        let now = DateUtils.isoNow()
        settings.lastSyncAt = now
    }

    private func run(_ body: @escaping @MainActor () async throws -> Void) async {
        isSyncing = true
        isError = false
        defer { isSyncing = false }
        do {
            try await body()
        } catch {
            fail(error.localizedDescription)
        }
    }

    private func ok(_ text: String) {
        message = text
        isError = false
    }

    private func fail(_ text: String) {
        message = text
        isError = true
    }
}
