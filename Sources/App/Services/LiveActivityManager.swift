import ActivityKit
import Foundation
import SwiftUI

/// 实时活动的启停与更新（运行在主 App 进程，天然读到最新数据）
@MainActor
final class LiveActivityManager: ObservableObject {
    @Published var isRunning: Bool = false

    private var activity: Activity<EarthOnlineAttributes>?

    var supported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func start(stats: LifeStats, emoji: String = "🌏") {
        guard supported else { return }
        guard activity == nil else { return }
        let attributes = EarthOnlineAttributes(sessionTitle: "地球Online")
        let state = EarthOnlineAttributes.ContentState(
            emoji: emoji,
            title: "Lv.\(stats.level) · \(stats.title)",
            detail: "今日完成 \(stats.todayDone) · 待办 \(stats.openTasks)",
            progress: stats.nextLevelProgress,
            level: stats.level
        )
        do {
            activity = try Activity.request(attributes: attributes, contentState: state, pushType: nil)
            isRunning = true
        } catch {
            isRunning = false
        }
    }

    func update(stats: LifeStats, emoji: String = "🌏") {
        guard let activity else { return }
        let state = EarthOnlineAttributes.ContentState(
            emoji: emoji,
            title: "Lv.\(stats.level) · \(stats.title)",
            detail: "今日完成 \(stats.todayDone) · 待办 \(stats.openTasks)",
            progress: stats.nextLevelProgress,
            level: stats.level
        )
        Task {
            await activity.update(using: state)
        }
    }

    func end() {
        guard let activity else { return }
        let state = EarthOnlineAttributes.ContentState(emoji: "🏁", title: "本次冒险到此为止",
                                                       detail: "随时回来继续", progress: 1, level: 0)
        Task {
            await activity.end(using: state, dismissalPolicy: .immediate)
        }
        self.activity = nil
        isRunning = false
    }
}
