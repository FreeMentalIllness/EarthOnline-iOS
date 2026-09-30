import AppIntents
import Foundation
import SwiftData

// App Intents 跑在 App 进程里，直接用同一套 SwiftData 容器读写，不需要 App Group。

private func makeRepository() -> Repository {
    let container = AppContainer.makeContainer()
    let context = ModelContext(container)
    return Repository(context: context)
}

struct AddMemoIntent: AppIntent {
    static var title: LocalizedStringResource = "写一条世界日志"
    static var description = IntentDescription("向「地球Online」的世界日志追加一条记录")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "内容")
    var text: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let repo = makeRepository()
        repo.addMemo(text: text)
        return .result(value: "已记录：\(text)")
    }
}

struct AddTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "新建任务"
    static var description = IntentDescription("在「地球Online」里添加一个主线 / 支线 / 待办任务")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "任务标题")
    var taskTitle: String

    @Parameter(title: "类型", default: .todo)
    var category: TaskCategoryEntity

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let repo = makeRepository()
        let mapped: TaskCategory
        switch category {
        case .main: mapped = .main
        case .side: mapped = .side
        case .todo: mapped = .todo
        }
        repo.addTask(title: taskTitle, category: mapped)
        return .result(value: "已添加任务：\(taskTitle)")
    }
}

struct TodaySummaryIntent: AppIntent {
    static var title: LocalizedStringResource = "今日战报"
    static var description = IntentDescription("读取当前等级、待办数量与今日完成任务数")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let repo = makeRepository()
        let profile = repo.profile()
        let level = DateUtils.age(from: profile.birthDate)
        let tasks = repo.all(TaskItem.self)
        let open = tasks.filter { $0.status != TaskStatus.done.rawValue }.count
        let today = DateUtils.todayKey()
        let done = tasks.filter { DateUtils.dayOfIso($0.doneAt ?? "") == today }.count
        return .result(value: "Lv.\(level)，待办 \(open) 项，今日完成 \(done) 项")
    }
}

/// 供「新建任务」意图使用的枚举参数（AppEntity）
enum TaskCategoryEntity: String, AppEnum, CaseIterable, Sendable {
    case main
    case side
    case todo

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "任务类型"
    static var caseDisplayRepresentations: [TaskCategoryEntity: DisplayRepresentation] = [
        .main: "主线任务",
        .side: "支线任务",
        .todo: "待办 ToDo"
    ]
}

struct EarthOnlineShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: AddMemoIntent(),
                    phrases: ["用\(.applicationName)记一笔", "\(.applicationName)写日志"],
                    shortTitle: "写世界日志",
                    systemImageName: "pencil")
        AppShortcut(intent: TodaySummaryIntent(),
                    phrases: ["\(.applicationName)今日战报", "\(.applicationName)状态"],
                    shortTitle: "今日战报",
                    systemImageName: "chart.bar")
    }
}
