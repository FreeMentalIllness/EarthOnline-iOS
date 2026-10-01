import SwiftData
import SwiftUI

struct BackpackView: View {
    @EnvironmentObject private var session: AppSession
    @Query private var items: [BagItem]
    @Query private var collections: [CollectionItem]
    @Query private var categories: [BagCategoryItem]

    @State private var tab: Int = 0
    @State private var search: String = ""
    @State private var selectedCategory: String? = nil
    @State private var showCreate: Bool = false
    @State private var editingItem: BagItem? = nil
    @State private var editingCollection: CollectionItem? = nil
    @State private var showCategoryManager: Bool = false

    private var scope: String { tab == 0 ? "item" : "collection" }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("", selection: $tab) {
                    Text("物品").tag(0)
                    Text("收藏夹").tag(1)
                }
                .pickerStyle(.segmented)
                .onChange(of: tab) { _, _ in selectedCategory = nil }

                categoryBar

                listContainer
            }
            .padding(16)
            .navigationTitle("背包")
            .searchable(text: $search, prompt: "搜索名称或描述")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { showCreate = true } label: { Label(tab == 0 ? "新增物品" : "新增收藏", systemImage: "plus") }
                        Button { showCategoryManager = true } label: { Label("管理分类", systemImage: "folder") }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .sheet(isPresented: $showCreate) {
                if tab == 0 {
                    ItemEditorView(categories: categories.filter { $0.scope == scope }) { name, desc, category in
                        _ = session.repo.addItem(name: name, desc: desc, category: category)
                        session.didMutateData()
                    }
                } else {
                    CollectionEditorView(categories: categories.filter { $0.scope == scope }) { title, note, category in
                        _ = session.repo.addCollection(title: title, note: note, category: category)
                        session.didMutateData()
                    }
                }
            }
            .sheet(isPresented: $showCategoryManager) {
                CategoryManagerView(scope: scope)
            }
            .sheet(item: $editingItem) { item in
                ItemEditorView(categories: categories.filter { $0.scope == scope },
                               initial: ItemEditorView.Draft(name: item.name, desc: item.desc ?? "", category: item.category)) { name, desc, category in
                    item.name = name
                    item.desc = desc
                    item.category = category
                    session.repo.save()
                    session.didMutateData()
                }
            }
            .sheet(item: $editingCollection) { collection in
                CollectionEditorView(categories: categories.filter { $0.scope == scope },
                                     initial: ItemEditorView.Draft(name: collection.title, desc: collection.note ?? "", category: collection.category)) { title, note, category in
                    collection.title = title
                    collection.note = note
                    collection.category = category
                    session.repo.save()
                    session.didMutateData()
                }
            }
        }
    }

    // MARK: 分类筛选

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button { selectedCategory = nil } label: {
                    ChipView(text: "全部", selected: selectedCategory == nil)
                }
                .buttonStyle(.plain)
                Button { selectedCategory = "" } label: {
                    ChipView(text: "未分类", selected: selectedCategory == "")
                }
                .buttonStyle(.plain)
                ForEach(categories.filter { $0.scope == scope }, id: \.persistentModelID) { category in
                    Button { selectedCategory = category.recordId } label: {
                        ChipView(text: category.name, selected: selectedCategory == category.recordId)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: 列表

    @ViewBuilder
    private var listContainer: some View {
        if tab == 0 {
            let list = filteredItems
            if list.isEmpty {
                EmptyStateView(emoji: "🎒", title: "背包空空", subtitle: "记录你拥有的每一件小东西")
                    .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(list, id: \.persistentModelID) { item in
                        Button { editingItem = item } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Text(item.itemType == "virtual" ? "☁️" : "🧺")
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.name).font(.body).foregroundStyle(Theme.textPrimary)
                                    if let desc = item.desc?.nonEmpty {
                                        Text(desc).font(.caption).foregroundStyle(Theme.textSecondary)
                                    }
                                    Text(categoryName(item.category))
                                        .font(.caption2)
                                        .foregroundStyle(Theme.textMuted)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                session.repo.softDelete(item)
                                session.didMutateData()
                            } label: { Label("删除", systemImage: "trash") }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        } else {
            let list = filteredCollections
            if list.isEmpty {
                EmptyStateView(emoji: "📚", title: "还没有收藏", subtitle: "把你舍不得丢的东西存进来")
                    .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(list, id: \.persistentModelID) { collection in
                        Button { editingCollection = collection } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Text("🔖")
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(collection.title).font(.body).foregroundStyle(Theme.textPrimary)
                                    if let note = collection.note?.nonEmpty {
                                        Text(note).font(.caption).foregroundStyle(Theme.textSecondary)
                                    }
                                    Text(categoryName(collection.category))
                                        .font(.caption2)
                                        .foregroundStyle(Theme.textMuted)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                session.repo.softDelete(collection)
                                session.didMutateData()
                            } label: { Label("删除", systemImage: "trash") }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var filteredItems: [BagItem] {
        let keyword = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return items.filter { item in
            guard item.deletedAt == nil else { return false }
            guard matches(categoryId: item.category) else { return false }
            guard !keyword.isEmpty else { return true }
            return item.name.localizedCaseInsensitiveContains(keyword) ||
                (item.desc ?? "").localizedCaseInsensitiveContains(keyword)
        }.sorted { $0.createdAt > $1.createdAt }
    }

    private var filteredCollections: [CollectionItem] {
        let keyword = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return collections.filter { collection in
            guard collection.deletedAt == nil else { return false }
            guard matches(categoryId: collection.category) else { return false }
            guard !keyword.isEmpty else { return true }
            return collection.title.localizedCaseInsensitiveContains(keyword) ||
                (collection.note ?? "").localizedCaseInsensitiveContains(keyword)
        }.sorted { $0.createdAt > $1.createdAt }
    }

    private func matches(categoryId: String?) -> Bool {
        guard let selectedCategory else { return true }
        if selectedCategory.isEmpty { return (categoryId ?? "").isEmpty }
        return categoryId == selectedCategory
    }

    private func categoryName(_ id: String?) -> String {
        guard let id, !id.isEmpty else { return "未分类" }
        return categories.first { $0.recordId == id }?.name ?? "未分类"
    }
}

// MARK: - 编辑器

struct ItemEditorView: View {
    struct Draft {
        var name: String = ""
        var desc: String = ""
        var category: String? = nil
    }

    @Environment(\.dismiss) private var dismiss
    let categories: [BagCategoryItem]
    var initial: Draft? = nil
    var onSave: (String, String?, String?) -> Void

    @State private var name: String = ""
    @State private var desc: String = ""
    @State private var categoryId: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("物品") {
                    TextField("名称", text: $name)
                    TextField("描述（可选）", text: $desc, axis: .vertical)
                }
                Section("分类") {
                    Picker("所属分类", selection: $categoryId) {
                        Text("未分类").tag("")
                        ForEach(categories, id: \.persistentModelID) { category in
                            Text(category.name).tag(category.recordId)
                        }
                    }
                }
            }
            .navigationTitle(initial == nil ? "新增物品" : "编辑物品")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        let cleanedDesc = desc.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(trimmed, cleanedDesc.isEmpty ? nil : cleanedDesc, categoryId.isEmpty ? nil : categoryId)
                        dismiss()
                    }
                }
            }
            .onAppear {
                name = initial?.name ?? ""
                desc = initial?.desc ?? ""
                categoryId = initial?.category ?? ""
            }
        }
    }
}

struct CollectionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let categories: [BagCategoryItem]
    var initial: ItemEditorView.Draft? = nil
    var onSave: (String, String?, String?) -> Void

    @State private var title: String = ""
    @State private var note: String = ""
    @State private var categoryId: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("收藏项") {
                    TextField("标题", text: $title)
                    TextField("备注（可选）", text: $note, axis: .vertical)
                }
                Section("分类") {
                    Picker("所属分类", selection: $categoryId) {
                        Text("未分类").tag("")
                        ForEach(categories, id: \.persistentModelID) { category in
                            Text(category.name).tag(category.recordId)
                        }
                    }
                }
            }
            .navigationTitle(initial == nil ? "新增收藏" : "编辑收藏")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        let cleaned = note.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(trimmed, cleaned.isEmpty ? nil : cleaned, categoryId.isEmpty ? nil : categoryId)
                        dismiss()
                    }
                }
            }
            .onAppear {
                title = initial?.name ?? ""
                note = initial?.desc ?? ""
                categoryId = initial?.category ?? ""
            }
        }
    }
}

// MARK: - 分类管理

struct CategoryManagerView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @Query private var categories: [BagCategoryItem]

    let scope: String
    @State private var newName: String = ""

    var body: some View {
        NavigationStack {
            List {
                Section("新建分类") {
                    HStack {
                        TextField("分类名称", text: $newName)
                        Button("添加") {
                            let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            _ = session.repo.addCategory(name: trimmed, scope: scope)
                            newName = ""
                            session.didMutateData()
                        }
                        .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                Section("已有分类") {
                    ForEach(categories.filter { $0.scope == scope }.sorted { $0.sortOrder < $1.sortOrder },
                            id: \.persistentModelID) { category in
                        Text(category.name)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    session.repo.deleteCategory(category)
                                    session.didMutateData()
                                } label: { Label("删除", systemImage: "trash") }
                            }
                    }
                }
                Section {
                    Text("删除分类不会删除条目，条目会回落为「未分类」")
                        .font(.caption)
                        .foregroundStyle(Theme.textMuted)
                }
            }
            .navigationTitle("管理分类")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } } }
        }
    }
}
