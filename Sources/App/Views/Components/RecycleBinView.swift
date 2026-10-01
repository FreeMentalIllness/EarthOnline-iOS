import SwiftUI

/// v1.0.5 回收站：软删除条目 30 天内可恢复，超期自动清理
struct RecycleBinView: View {
    @EnvironmentObject private var session: AppSession
    @State private var notice: String = ""
    @State private var showEmptyConfirm: Bool = false

    var body: some View {
        let items = session.repo.recycleBin()
        List {
            Section {
                if items.isEmpty {
                    EmptyStateView(emoji: "🗑️", title: "回收站是空的",
                                   subtitle: "删除的任务 / 日志 / 物品 / 收藏 / 足迹会在这里保留 30 天")
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, entry in
                        binRow(entry)
                    }
                }
            } header: {
                Text("已删除（\(items.count) 项，保留 \(Repository.recycleBinRetentionDays) 天）")
            } footer: {
                Text("删除先进回收站，不会同步到其他端；超期条目在启动时自动清理。")
            }
            if !items.isEmpty {
                Section {
                    Button(role: .destructive) { showEmptyConfirm = true } label: {
                        Label("清空回收站", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("回收站")
        .alert(notice, isPresented: Binding(get: { !notice.isEmpty }, set: { _ in notice = "" })) {
            Button("知道了") { notice = "" }
        }
        .alert("清空回收站？", isPresented: $showEmptyConfirm) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                session.repo.emptyRecycleBin()
                session.didMutateData()
                notice = "回收站已清空"
            }
        } message: {
            Text("此操作物理删除全部回收站条目，不可恢复。")
        }
    }

    @ViewBuilder
    private func binRow(_ entry: SoftDeletable) -> some View {
        let meta = describe(entry)
        HStack(spacing: 10) {
            Text(meta.emoji).font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(meta.title)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                if let deletedAt = entry.deletedAt {
                    let daysLeft = max(0, Repository.recycleBinRetentionDays - DateUtils.daysBetween(from: deletedAt))
                    Text("剩余 \(daysLeft) 天 · 删除于 \(DateUtils.dayOfIso(DateUtils.isoFormatter.string(from: deletedAt)))")
                        .font(.caption2)
                        .foregroundStyle(Theme.textMuted)
                }
            }
            Spacer(minLength: 0)
            Button {
                session.repo.restore(entry)
                session.didMutateData()
                notice = "已恢复：\(meta.title)"
            } label: {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                session.repo.purge(entry)
                notice = "已彻底删除"
            } label: {
                Image(systemName: "xmark.circle")
                    .font(.title3)
                    .foregroundStyle(Theme.textMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    private func describe(_ entry: SoftDeletable) -> (emoji: String, title: String) {
        switch entry {
        case let task as TaskItem: return ("🎯", task.title)
        case let memo as MemoItem: return ("📝", memo.text)
        case let item as BagItem: return ("🎒", item.name)
        case let collection as CollectionItem: return ("📚", collection.title)
        case let pin as LocationPin: return ("🗺️", pin.name)
        default: return ("❔", "未知条目")
        }
    }
}
