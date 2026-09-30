import PhotosUI
import SwiftData
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var session: AppSession
    @Query private var profiles: [ProfileItem]

    @State private var davUrl: String = ""
    @State private var davUser: String = ""
    @State private var davPass: String = ""
    @State private var davDir: String = ""
    @State private var davFile: String = ""
    @State private var davHint: String = ""

    @State private var aiBase: String = ""
    @State private var aiKey: String = ""
    @State private var aiModel: String = ""

    @State private var showClearConfirm: Bool = false
    @State private var showImporter: Bool = false
    @State private var exportURL: URL? = nil
    @State private var showShare: Bool = false
    @State private var notice: String = ""

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                appearanceSection
                generalSection
                aiSection
                webdavSection
                dataSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("设置")
            .onAppear(perform: load)
            .alert(notice, isPresented: Binding(get: { !notice.isEmpty }, set: { _ in notice = "" })) {
                Button("知道了") { notice = "" }
            }
            .alert("确认清空全部数据？", isPresented: $showClearConfirm) {
                Button("取消", role: .cancel) {}
                Button("清空", role: .destructive) {
                    session.clearAllData()
                    notice = "已清空本地数据（App 设置保留，自动同步已挂起一次）"
                }
            } message: {
                Text("会删除任务 / 背包 / 收藏 / 足迹 / 日志 / 成就与头像图片。相当于 Web 端的 resetAllData，操作不可撤销。")
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    guard url.startAccessingSecurityScopedResource() else { return }
                    defer { url.stopAccessingSecurityScopedResource() }
                    do {
                        let data = try Data(contentsOf: url)
                        let summary = try session.backups.importData(data)
                        session.refresh()
                        notice = "导入完成：新增 \(summary.inserted) / 更新 \(summary.updated)"
                    } catch {
                        notice = "导入失败：\(error.localizedDescription)"
                    }
                case .failure(let error):
                    notice = "选择文件失败：\(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: 资料

    private var profileSection: some View {
        Section {
            if let profile = profiles.first {
                NavigationLink(destination: ProfileEditView(profile: profile)) {
                    HStack(spacing: 12) {
                        AvatarView(avatarKey: profile.avatarKey,
                                   image: avatarImage(profile), size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.name.isEmpty ? "未设置昵称" : profile.name)
                                .foregroundStyle(Theme.textPrimary)
                            Text(profile.birthDate.isEmpty ? "未设置出生日期" : "生日 \(profile.birthDate)")
                                .font(.caption)
                                .foregroundStyle(Theme.textMuted)
                        }
                    }
                }
            }
            NavigationLink(destination: TitleSettingsView()) {
                Label("自定义称号", systemImage: "rosette")
            }
        } header: { Text("个人信息") }
    }

    private func avatarImage(_ profile: ProfileItem) -> UIImage? {
        guard let path = profile.avatarPath, let data = LocalFileStore.load(path) else { return nil }
        return UIImage(data: data)
    }

    // MARK: 外观

    private var appearanceSection: some View {
        Section {
            Picker("主题模式", selection: Binding(
                get: { session.settings.mode },
                set: { session.settings.mode = $0 }
            )) {
                ForEach(AppThemeMode.allCases) { mode in Text(mode.label).tag(mode) }
            }
            PhotoPickerView(title: "选择壁纸") { data in
                if let relative = LocalFileStore.save(data, into: "wallpaper", filename: "wallpaper.jpg") {
                    session.settings.wallpaperPath = relative
                }
            }
            if !session.settings.wallpaperPath.isEmpty {
                VStack(alignment: .leading) {
                    Text("壁纸不透明度 \(Int(session.settings.wallpaperAlpha * 100))%")
                    Slider(value: Binding(get: { session.settings.wallpaperAlpha },
                                          set: { session.settings.wallpaperAlpha = $0 }), in: 0.05...0.9)
                        .tint(Theme.accent)
                }
                Button(role: .destructive) {
                    if let path = session.settings.wallpaperPath.nonEmpty { LocalFileStore.delete(path) }
                    session.settings.wallpaperPath = ""
                } label: { Text("移除壁纸") }
            }
        } header: { Text("外观") }
    }

    // MARK: 通用

    private var generalSection: some View {
        Section {
            Toggle("到期提醒", isOn: Binding(get: { session.settings.notifyEnabled },
                                            set: { newValue in
                session.settings.notifyEnabled = newValue
                if newValue {
                    Task { _ = await NotificationService.requestAuthorization() }
                }
            }))
            Toggle("成就解锁音效/提醒", isOn: Binding(get: { session.settings.achSound },
                                                set: { session.settings.achSound = $0 }))
            Toggle("任务页隐藏已完成", isOn: Binding(get: { session.settings.hideDoneTasks },
                                             set: { session.settings.hideDoneTasks = $0 }))
            Stepper("首页动态条数：\(session.settings.homeFeedLimit == 0 ? "不限" : "\(session.settings.homeFeedLimit)")",
                    value: Binding(get: { session.settings.homeFeedLimit },
                                   set: { session.settings.homeFeedLimit = $0 }), in: 0...20)
        } header: { Text("通用") }
    }

    // MARK: AI

    private var aiSection: some View {
        Section {
            TextField("接口地址（Base URL）", text: $aiBase)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("模型名", text: $aiModel)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            SecureField("API Key", text: $aiKey)
            Button("保存 AI 配置") {
                session.settings.ai = AiConfig(baseUrl: aiBase.trimmingCharacters(in: .whitespacesAndNewlines),
                                               apiKey: aiKey.trimmingCharacters(in: .whitespacesAndNewlines),
                                               model: aiModel.trimmingCharacters(in: .whitespacesAndNewlines))
                notice = "AI 配置已保存"
            }
        } header: { Text("AI 助手") } footer: {
            Text("兼容 OpenAI /v1/chat/completions 接口；接口地址、模型与密钥只保存在本机。")
        }
    }

    // MARK: WebDAV

    private var webdavSection: some View {
        Section {
            TextField("服务器地址", text: $davUrl)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("账号", text: $davUser)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            SecureField("密码", text: $davPass)
            TextField("远程目录", text: $davDir)
            TextField("文件名", text: $davFile)
            Toggle("自动同步（进前台拉取 / 切后台推送）",
                   isOn: Binding(get: { session.settings.autoSync }, set: { session.settings.autoSync = $0 }))
            Button {
                Task {
                    saveWebdav()
                    davHint = "连接测试中…"
                    davHint = await session.sync.testConnection()
                }
            } label: { Text("测试连接") }
            HStack {
                Button {
                    saveWebdav()
                    Task { await session.sync.push() }
                    observeSync()
                } label: { Text("立即推送") }
                Spacer()
                Button {
                    saveWebdav()
                    Task { await session.sync.pull() }
                    observeSync()
                } label: { Text("立即拉取") }
            }
            if !davHint.isEmpty || !session.sync.message.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(davHint.isEmpty ? session.sync.message : davHint)
                        .font(.caption)
                        .foregroundStyle(session.sync.isError ? .red : Theme.textSecondary)
                    Text("上次同步：\(session.settings.lastSyncAt.isEmpty ? "从未" : session.settings.lastSyncAt)")
                        .font(.caption2)
                        .foregroundStyle(Theme.textMuted)
                }
            }
        } header: { Text("WebDAV 同步") } footer: {
            Text("四端共用 earth-online-backup.json，导入按主键合并，不会整包覆盖。")
        }
    }

    // MARK: 数据

    private var dataSection: some View {
        Section {
            Button {
                do {
                    let data = try session.backups.exportData()
                    if let url = LocalFileStore.exportToDocuments(data) {
                        exportURL = url
                        showShare = true
                    }
                } catch {
                    notice = "导出失败：\(error.localizedDescription)"
                }
            } label: { Label("导出备份（earth-online-backup.json）", systemImage: "square.and.arrow.up") }
            Button { showImporter = true } label: { Label("从备份文件导入", systemImage: "square.and.arrow.down") }
            Button(role: .destructive) { showClearConfirm = true } label: { Label("清空全部数据", systemImage: "trash") }
        } header: { Text("数据管理") } footer: {
            Text("导出后会写入「文件 App → EarthOnline」目录，可通过 iTunes/访达直接拷出；跨端推荐用 WebDAV。")
        }
        .sheet(isPresented: $showShare) {
            if let exportURL {
                ShareSheet(items: [exportURL])
            }
        }
    }

    // MARK: 关于

    private var aboutSection: some View {
        Section {
            LabeledContent("版本", value: appVersion)
            LabeledContent("Bundle ID", value: Bundle.main.bundleIdentifier ?? "-")
            LabeledContent("地图后端", value: MapBackendResolver.useAMap ? "高德 AMap" : "系统 MapKit")
            LabeledContent("数据共享", value: SharedStore.containerURL() == nil ? "未启用 App Group" : "App Group 已启用")
        } header: { Text("关于") } footer: {
            Text("地球Online v1.0.4 · Web / Android / Windows / iOS 四端同源")
        }
    }

    private var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "\(short) (\(build))"
    }

    // MARK: 内部

    private func load() {
        davUrl = session.settings.webdav.baseUrl
        davUser = session.settings.webdav.user
        davPass = session.settings.webdav.password
        davDir = session.settings.webdav.remoteDir
        davFile = session.settings.webdav.fileName
        aiBase = session.settings.ai.baseUrl
        aiKey = session.settings.ai.apiKey
        aiModel = session.settings.ai.model
    }

    private func saveWebdav() {
        session.settings.webdav = WebDavConfig(
            baseUrl: davUrl.trimmingCharacters(in: .whitespacesAndNewlines),
            user: davUser.trimmingCharacters(in: .whitespacesAndNewlines),
            password: davPass,
            remoteDir: davDir.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "EarthOnline" : davDir.trimmingCharacters(in: .whitespacesAndNewlines),
            fileName: davFile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "earth-online-backup.json" : davFile.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private func observeSync() {
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run { davHint = session.sync.message }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct TitleSettingsView: View {
    @EnvironmentObject private var session: AppSession
    @State private var text: String = ""

    var body: some View {
        Form {
            Section("自定义称号") {
                TextField("最多 12 个字", text: $text)
                    .onChange(of: text) { newValue in
                        session.settings.customTitle = String(newValue.prefix(12))
                    }
            }
            Section {
                Text("留空则显示默认称号「旅行者」")
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
            }
        }
        .onAppear { text = session.settings.customTitle }
        .navigationTitle("称号")
    }
}
