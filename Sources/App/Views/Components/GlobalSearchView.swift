import SwiftData
import SwiftUI

/// v1.0.5 全局搜索：任务 / 日志 / 物品 / 收藏 / 足迹 一框通查
struct GlobalSearchView: View {
    @EnvironmentObject private var session: AppSession
    @State private var keyword: String = ""
    @State private var editing: TaskItem? = nil

    private var query: String {
        keyword.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        List {
            if query.isEmpty {
                Section {
                    EmptyStateView(emoji: "🔍", title: "输入关键词开始搜索",
                                   subtitle: "覆盖任务、世界日志、背包、收藏与足迹")
                        .listRowBackground(Color.clear)
                }
            } else {
                taskSection
                memoSection
                itemSection
                collectionSection
                locationSection
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("全局搜索")
        .searchable(text: $keyword, prompt: "搜索所有数据")
    }

    // MARK: - 各分区

    private var taskSection: some View {
        let hits = session.repo.active(TaskItem.self).filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            ($0.note ?? "").localizedCaseInsensitiveContains(query)
        }
        return Section("任务（\(hits.count)）") {
            if hits.isEmpty { hintRow }
            ForEach(hits, id: \.persistentModelID) { task in
                Button {
                    editing = task
                } label: {
                    row(emoji: task.status == TaskStatus.done.rawValue ? "✅" : "🎯",
                        title: task.title, detail: task.note ?? "")
                }
            }
        }
        .sheet(item: $editing) { task in TaskDetailView(task: task) }
    }

    private var memoSection: some View {
        let hits = session.repo.active(MemoItem.self).filter { $0.text.localizedCaseInsensitiveContains(query) }
        return Section("世界日志（\(hits.count)）") {
            if hits.isEmpty { hintRow }
            ForEach(hits, id: \.persistentModelID) { memo in
                row(emoji: "📝", title: memo.text, detail: DateUtils.relative(memo.createdAt))
            }
        }
    }

    private var itemSection: some View {
        let hits = session.repo.active(BagItem.self).filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            ($0.desc ?? "").localizedCaseInsensitiveContains(query)
        }
        return Section("背包物品（\(hits.count)）") {
            if hits.isEmpty { hintRow }
            ForEach(hits, id: \.persistentModelID) { item in
                row(emoji: "🎒", title: item.name, detail: item.desc ?? "")
            }
        }
    }

    private var collectionSection: some View {
        let hits = session.repo.active(CollectionItem.self).filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            ($0.note ?? "").localizedCaseInsensitiveContains(query)
        }
        return Section("收藏（\(hits.count)）") {
            if hits.isEmpty { hintRow }
            ForEach(hits, id: \.persistentModelID) { item in
                row(emoji: "📚", title: item.title, detail: item.note ?? "")
            }
        }
    }

    private var locationSection: some View {
        let hits = session.repo.active(LocationPin.self).filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            ($0.note ?? "").localizedCaseInsensitiveContains(query)
        }
        return Section("足迹（\(hits.count)）") {
            if hits.isEmpty { hintRow }
            ForEach(hits, id: \.persistentModelID) { pin in
                row(emoji: "🗺️", title: pin.name,
                    detail: "\(String(format: "%.4f", pin.lat)), \(String(format: "%.4f", pin.lng))")
            }
        }
    }

    private var hintRow: some View {
        Text("无匹配结果")
            .font(.footnote)
            .foregroundStyle(Theme.textMuted)
    }

    private func row(emoji: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(emoji) \(title)")
                .font(.subheadline)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
            if !detail.isEmpty {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(Theme.textMuted)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}
