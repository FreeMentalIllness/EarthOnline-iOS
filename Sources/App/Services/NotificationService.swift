import Foundation
import UIKit
import UserNotifications

/// 本地通知（到期提醒 / 成就解锁提醒）
/// 说明：侧载安装的 App 拿不到推送能力，这里只走本地通知，无需任何 Entitlement。
enum NotificationService {
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
