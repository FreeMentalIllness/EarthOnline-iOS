import SwiftUI

/// 「发现」页：把低频但重要的模块收在这里，Tab 数量保持在 5 个以内
struct DiscoverView: View {
    @EnvironmentObject private var session: AppSession

    var body: some View {
        NavigationStack {
            List {
                Section("成长") {
                    row(emoji: "🏅", title: "成就", subtitle: "共 \(session.stats.achievements) 枚已解锁") { AchievementsView() }
                    row(emoji: "📊", title: "数据看板", subtitle: "XP、记录密度与任务分布") { StatsView() }
                    row(emoji: "🪪", title: "人生卡片", subtitle: "生成长图分享今日的你") { LifeCardShareView() }
                }
                Section("世界") {
                    row(emoji: "🗺️", title: "世界足迹", subtitle: "\(session.stats.locations) 个坐标") { MapScreen() }
                    row(emoji: "🖼️", title: "记忆相册", subtitle: "老照片与旧时光") { MemoryAlbumView() }
                    row(emoji: "🤖", title: "AI 伙伴", subtitle: "总结、鼓励、聊天") { AIView() }
                }
                Section("系统能力") {
                    row(emoji: "🔍", title: "全局搜索", subtitle: "一框查遍五类数据") { GlobalSearchView() }
                    liveActivityRow
                    widgetRow
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("发现")
            .onAppear { session.refresh() }
        }
    }

    private func row<Destination: View>(emoji: String, title: String, subtitle: String,
                                        @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                Text(emoji).font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.body).foregroundStyle(Theme.textPrimary)
                    Text(subtitle).font(.caption2).foregroundStyle(Theme.textMuted)
                }
            }
        }
    }

    @ViewBuilder
    private var liveActivityRow: some View {
        Toggle(isOn: Binding(
            get: { liveActivity.isRunning },
            set: { newValue in
                if newValue { liveActivity.start(stats: session.stats) } else { liveActivity.end() }
            }
        )) {
            Label("灵动岛实时活动", systemImage: "waveform")
        }
        .disabled(!liveActivity.supported)
    }

    private var widgetRow: some View {
        let reachable = SharedStore.containerURL() != nil
        return VStack(alignment: .leading, spacing: 4) {
            Text("桌面小组件")
                .font(.body)
                .foregroundStyle(Theme.textPrimary)
            Text(reachable ? "已启用数据共享，组件会显示实时状态" : "未启用 App Group，组件显示静态卡片（深链可回 App）")
                .font(.caption2)
                .foregroundStyle(Theme.textMuted)
        }
        .padding(.vertical, 4)
    }

    @EnvironmentObject private var liveActivity: LiveActivityManager
}
