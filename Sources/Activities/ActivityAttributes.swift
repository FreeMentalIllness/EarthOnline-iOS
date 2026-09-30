import Foundation
import ActivityKit

/// 灵动岛 / 锁屏实时活动的数据契约
/// 注意：Live Activity 的内容由 App 进程主动推送，因此不需要 App Group 也能拿到实时数据。
struct EarthOnlineAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var emoji: String
        var title: String
        var detail: String
        var progress: Double
        var level: Int
    }

    var sessionTitle: String
}
