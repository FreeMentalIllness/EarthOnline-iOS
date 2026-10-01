import PhotosUI
import SwiftUI

/// v1.0.5 记忆相册：老照片收藏（触发隐藏成就 egg_memory_album）
struct MemoryAlbumView: View {
    @EnvironmentObject private var session: AppSession

    @State private var selection: [PhotosPickerItem] = []
    @State private var isImporting: Bool = false
    @State private var notice: String = ""

    private var photos: [CollectionItem] {
        session.repo.active(CollectionItem.self)
            .filter { $0.category == "memory_album" }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        ScrollView {
            albumContent
                .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("记忆相册")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                PhotosPicker(selection: $selection, maxSelectionCount: 20, selectionBehavior: .ordered, matching: .images, photoLibrary: .shared()) {
                    if isImporting {
                        ProgressView()
                    } else {
                        Image(systemName: "plus")
                    }
                }
                .disabled(isImporting)
            }
        }
        .onChange(of: selection) { _, newValue in
            guard !newValue.isEmpty, !isImporting else { return }
            Task { await importPhotos(newValue) }
        }
        .alert(notice, isPresented: Binding(get: { !notice.isEmpty }, set: { _ in notice = "" })) {
            Button("知道了") { notice = "" }
        }
    }

    @ViewBuilder
    private var albumContent: some View {
        if photos.isEmpty {
            EmptyStateView(emoji: "🖼️", title: "相册还没有照片",
                           subtitle: "导入第一张老照片，唤醒一段旧时光")
                .padding(.top, 40)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
                ForEach(photos, id: \.persistentModelID) { entry in
                    photoCell(entry)
                }
            }
        }
    }

    private func photoCell(_ entry: CollectionItem) -> some View {
        let image: UIImage? = entry.fileUri.flatMap { LocalFileStore.load($0) }.flatMap(UIImage.init(data:))
        return VStack(spacing: 4) {
            Group {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    ZStack {
                        Theme.accentSoft
                        Text("🖼️")
                    }
                }
            }
            .frame(width: 104, height: 104)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.border, lineWidth: 1))
            Text(entry.title)
                .font(.caption2)
                .foregroundStyle(Theme.textMuted)
                .lineLimit(1)
        }
        .contextMenu {
            Button(role: .destructive) {
                if let path = entry.fileUri { LocalFileStore.delete(path) }
                session.repo.softDelete(entry)
                session.didMutateData()
            } label: {
                Label("移入回收站", systemImage: "trash")
            }
        }
    }

    private func importPhotos(_ items: [PhotosPickerItem]) async {
        await MainActor.run { isImporting = true }
        var ok = 0
        var lastRelative: String? = nil
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let filename = "memory_\(Int(Date().timeIntervalSince1970 * 1000))_\(ok).jpg"
                if let relative = LocalFileStore.save(data, into: "memory", filename: filename) {
                    _ = session.repo.addCollection(
                        title: "老照片 · \(DateUtils.todayKey())",
                        note: nil,
                        category: "memory_album",
                        fileUri: relative,
                        fileMetaJson: "{\"source\":\"memory_album\"}"
                    )
                    lastRelative = relative
                    ok += 1
                }
            }
        }
        await MainActor.run {
            isImporting = false
            selection = []
            if ok > 0 {
                session.didMutateData()
                notice = ok == 1 ? "已收入相册" : "已收入 \(ok) 张照片"
            } else {
                notice = "照片保存失败，请重试"
            }
        }
    }
}
