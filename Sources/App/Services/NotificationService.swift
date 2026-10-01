import Foundation
import UIKit
import UserNotifications

/// 本地通知（到期提醒 / 成就解锁提醒 / 同步完成 / 灵感接力）
/// 说明：侧载安装的 App 拿不到推送能力，这里只走本地通知，无需任何 Entitlement。
enum NotificationService {
    static let inspirationKind = "inspiration"

    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    static func notify(title: String, body: String, delay: TimeInterval = 1) {
        guard UserDefaults.standard.object(forKey: SettingKeys.notify) as? Bool == true else {
            // 未开启提醒时，仅允许成就解锁即时提醒（轻量反馈，不强打扰策略）
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
            schedule(title: title, body: body, trigger: trigger)
            return
        }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
        schedule(title: title, body: body, trigger: trigger)
    }

    /// 灵感接力：先收进通知，稍后点按即可一键转待办
    static func scheduleInspiration(_ text: String, delay: TimeInterval = 1) {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            let content = UNMutableNotificationContent()
            content.title = "灵感接力 💡"
            content.body = text
            content.sound = .default
            content.userInfo = ["kind": inspirationKind, "text": text]
            let request = UNNotificationRequest(identifier: "inspiration-\(UUID().uuidString)", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }

    static func scheduleDueReminder(id: String, title: String, dueDay: String) {
        guard let iso = DateUtils.dayToIso(dueDay),
              let date = DateUtils.isoFormatter.date(from: iso) else { return }
        let ahead = date.addingTimeInterval(-2 * 3600)
        guard ahead > Date() else { return }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            let content = UNMutableNotificationContent()
            content.title = "任务即将到期"
            content.body = title
            content.sound = .default
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: ahead)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: "task-\(id)", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }

    static func cancelReminder(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["task-\(id)"])
    }

    private static func schedule(title: String, body: String, trigger: UNNotificationTrigger) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }
}

extension Notification.Name {
    static let inspirationTapped = Notification.Name("inspiration_tapped")
    static let syncCompleted = Notification.Name("sync_completed")
}

/// 通知响应路由：点按「灵感接力」通知 → 广播给 App 转待办
final class NotificationRouter: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        guard info["kind"] as? String == NotificationService.inspirationKind,
              let text = info["text"] as? String, !text.isEmpty else { return }
        await MainActor.run {
            NotificationCenter.default.post(name: .inspirationTapped, object: text)
        }
    }
}
