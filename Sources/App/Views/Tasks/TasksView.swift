import SwiftData
import SwiftUI

struct TasksView: View {
    @EnvironmentObject private var session: AppSession
    @Query private var allTasks: [TaskItem]

    @State private var category: TaskCategory = .todo
    @State private var search: String = ""
    @State private var editing: TaskItem? = nil
    @State private var showCreate: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("分类", selection: $category) {
                    ForEach(TaskCategory.allCases) { item in
                        Text(item.label).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("隐藏已完成", isOn: Binding(
                    get: { session.settings.hideDoneTasks },
                    set: { session.settings.hideDoneTasks = $0 }
                ))
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)

                content
            }
            .padding(16)
            .navigationTitle("任务")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showCreate = true } label: { Image(systemName: "plus") }
                }
            }
            .searchable(text: $search, prompt: "搜索任务")
            .sheet(isPresented: $showCreate) {
                TaskEditorView(category: category) { title, category, dueDate, note in
                    _ = session.repo.addTask(title: title, category: category, dueDate: dueDate, note: note)
                    session.didMutateData()
                }
            }
            .sheet(item: $editing) { task in
                TaskDetailView(task: task)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        let list = filteredTasks
        if list.isEmpty {
            EmptyStateView(emoji: "📋", title: "这里还没有任务",
                           subtitle: "点右上角加号，从一件小事开始")
                .frame(maxHeight: .infinity)
        } else {
            List {
                ForEach(list, id: \.persistentModelID) { task in
                    TaskRow(task: task)
                        .contentShape(Rectangle())
                        .onTapGesture { editing = task }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                session.repo.delete(task)
                                session.didMutateData()
                            } label: { Label("删除", systemImage: "trash") }
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private var filteredTasks: [TaskItem] {
        let keyword = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return allTasks.filter { task in
            guard task.category == category.rawValue else { return false }
            if session.settings.hideDoneTasks && task.status == TaskStatus.done.rawValue { return false }
            guard !keyword.isEmpty else { return true }
            return task.title.localizedCaseInsensitiveContains(keyword) ||
                (task.note ?? "").localizedCaseInsensitiveContains(keyword)
        }
        .sorted { lhs, rhs in
            let lhsOpen = lhs.status != TaskStatus.done.rawValue
            let rhsOpen = rhs.status != TaskStatus.done.rawValue
            if lhsOpen != rhsOpen { return lhsOpen }
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.createdAt < rhs.createdAt
        }
    }
}

struct TaskRow: View {
    @EnvironmentObject private var session: AppSession
    let task: TaskItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                session.repo.toggleTaskDone(task)
                session.didMutateData()
            } label: {
                Image(systemName: task.status == TaskStatus.done.rawValue ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.status == TaskStatus.done.rawValue ? Theme.accent : Theme.textMuted)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body)
                    .foregroundStyle(task.status == TaskStatus.done.rawValue ? Theme.textMuted : Theme.textPrimary)
                    .strikethrough(task.status == TaskStatus.done.rawValue, color: Theme.textMuted)
                HStack(spacing: 8) {
                    Text(TaskStatus(rawValue: task.status)?.label ?? "")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                    if let due = task.dueDate?.nonEmpty {
                        Text("截止 \(due)")
                            .font(.caption2)
                            .foregroundStyle(due < DateUtils.todayKey() ? .red : Theme.textMuted)
                    }
                    if task.progress > 0 && task.status != TaskStatus.done.rawValue {
                        Text("\(task.progress)%")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(Theme.textMuted)
                    }
                }
                if task.progress > 0 && task.status != TaskStatus.done.rawValue {
                    LineProgressView(progress: Double(task.progress) / 100)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - 详情

struct TaskDetailView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss

    let task: TaskItem

    @State private var title: String = ""
    @State private var status: TaskStatus = .planning
    @State private var progress: Double = 0
    @State private var note: String = ""
    @State private var dueEnabled: Bool = false
    @State private var dueDate: Date = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("标题") {
                    TextField("任务标题", text: $title)
                }
                Section("状态") {
                    Picker("状态", selection: $status) {
                        ForEach(TaskStatus.allCases) { item in Text(item.label).tag(item) }
                    }
                    VStack(alignment: .leading) {
                        Text("进度 \(Int(progress))%")
                        Slider(value: $progress, in: 0...100, step: 5)
                            .tint(Theme.accent)
                    }
                }
                Section("备注") {
                    TextEditor(text: $note).frame(minHeight: 90)
                }
                Section("截止日期") {
                    Toggle("设置截止日期", isOn: $dueEnabled)
                    if dueEnabled {
                        DatePicker("截止", selection: $dueDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("任务详情")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        title = task.title
        status = TaskStatus(rawValue: task.status) ?? .planning
        progress = Double(task.progress)
        note = task.note ?? ""
        if let due = task.dueDate, let date = DateUtils.parseDay(due) {
            dueEnabled = true
            dueDate = date
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        session.repo.updateTask(task, title: trimmed, status: status, progress: Int(progress),
                                note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                                dueDate: dueEnabled ? DateUtils.dayKeyFormatter.string(from: dueDate) : "")
        if dueEnabled, session.settings.notifyEnabled {
            NotificationService.scheduleDueReminder(id: task.recordId, title: trimmed,
                                                    dueDay: DateUtils.dayKeyFormatter.string(from: dueDate))
        }
        session.didMutateData()
        dismiss()
    }
}

// MARK: - 新建

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss

    var category: TaskCategory
    var onCreate: (String, TaskCategory, String?, String?) -> Void

    @State private var title: String = ""
    @State private var selected: TaskCategory
    @State private var dueEnabled: Bool = false
    @State private var dueDate: Date = Date()
    @State private var note: String = ""

    init(category: TaskCategory, onCreate: @escaping (String, TaskCategory, String?, String?) -> Void) {
        self.category = category
        self.onCreate = onCreate
        _selected = State(initialValue: category)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("新任务") {
                    TextField("标题", text: $title)
                    Picker("分类", selection: $selected) {
                        ForEach(TaskCategory.allCases) { item in Text(item.label).tag(item) }
                    }
                }
                Section("截止日期") {
                    Toggle("设置截止日期", isOn: $dueEnabled)
                    if dueEnabled { DatePicker("截止", selection: $dueDate, displayedComponents: .date) }
                }
                Section("备注") {
                    TextEditor(text: $note).frame(minHeight: 80)
                }
            }
            .navigationTitle("新建任务")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        let due = dueEnabled ? DateUtils.dayKeyFormatter.string(from: dueDate) : nil
                        let cleanedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
                        onCreate(trimmed, selected, due, cleanedNote.isEmpty ? nil : cleanedNote)
                        dismiss()
                    }
                }
            }
        }
    }
}
