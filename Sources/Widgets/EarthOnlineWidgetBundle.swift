import SwiftUI
import UIKit
import WidgetKit

@main
struct EarthOnlineWidgetBundle: WidgetBundle {
    var body: some Widget {
        StatusWidget()
        EarthOnlineLiveActivity()
    }
}

// MARK: - 时间线

struct StatusEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct StatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatusEntry {
        StatusEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (StatusEntry) -> Void) {
        completion(StatusEntry(date: Date(), snapshot: SharedStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatusEntry>) -> Void) {
        let entry = StatusEntry(date: Date(), snapshot: SharedStore.load())
        // 30 分钟刷新一次即可（写入侧是 App 内的关键操作触发）
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - 组件本体

struct StatusWidget: Widget {
    let kind: String = "EarthOnlineStatus"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StatusProvider()) { entry in
            StatusWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("地球Online · 状态")
        .description("等级、待办数量与今日进度")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct StatusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StatusEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            dataView(snapshot)
                .widgetURL(URL(string: "earthonline://home"))
        } else {
            fallbackView
                .widgetURL(URL(string: "earthonline://home"))
        }
    }

    // MARK: 有共享数据时

    private func dataView(_ snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("🌏")
                Text(snapshot.name.isEmpty ? "旅行者" : snapshot.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WidgetColors.textPrimary)
                Spacer(minLength: 0)
            }
            Text("Lv.\(snapshot.level)")
                .font(.title2.weight(.bold))
                .foregroundStyle(WidgetColors.accent)
            Text("\(snapshot.xp) XP · 第 \(snapshot.daysLived) 天")
                .font(.caption)
                .foregroundStyle(WidgetColors.textSecondary)
            if family == .systemMedium {
                HStack(spacing: 12) {
                    metric(value: snapshot.openTasks, label: "待办")
                    metric(value: snapshot.todayDone, label: "今日完成")
                    metric(value: snapshot.memos, label: "日志")
                    metric(value: snapshot.locations, label: "足迹")
                    Spacer(minLength: 0)
                }
                .padding(.top, 2)
            } else {
                Text("待办 \(snapshot.openTasks) · 今日 \(snapshot.todayDone)")
                    .font(.caption)
                    .foregroundStyle(WidgetColors.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
    }

    private func metric(value: Int, label: String) -> some View {
        VStack(spacing: 1) {
            Text("\(value)")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(WidgetColors.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(WidgetColors.textMuted)
        }
    }

    // MARK: 无共享数据（未开 App Group）时的降级卡片

    private var fallbackView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("🌏")
                Text("地球Online")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WidgetColors.textPrimary)
            }
            Text("打开 App 查看今日状态")
                .font(.caption)
                .foregroundStyle(WidgetColors.textSecondary)
            Spacer(minLength: 0)
            Text("启用 App Group 后这里会显示实时数据")
                .font(.caption2)
                .foregroundStyle(WidgetColors.textMuted)
        }
        .padding(14)
    }
}

/// 深浅模式自适应取色（与主 App Theme 基线一致）：
/// 容器背景用系统 .fill.tertiary 会跟随深色模式，文字若固定深色在深色下不可读
enum WidgetColors {
    static let background = Color.eoDynamic(light: 0.973, green: 0.965, blue: 0.949,
                                            dark: 0.086, greenD: 0.078, blueD: 0.059)
    static let card = Color.eoDynamic(light: 1.0, green: 1.0, blue: 1.0,
                                      dark: 0.118, greenD: 0.102, blueD: 0.086)
    static let textPrimary = Color.eoDynamic(light: 0.118, green: 0.102, blue: 0.086,
                                             dark: 0.925, greenD: 0.906, blueD: 0.878)
    static let textSecondary = Color.eoDynamic(light: 0.478, green: 0.447, blue: 0.408,
                                               dark: 0.663, greenD: 0.627, blueD: 0.580)
    static let textMuted = Color.eoDynamic(light: 0.690, green: 0.659, blue: 0.616,
                                           dark: 0.435, greenD: 0.404, blueD: 0.365)
    static let accent = Color(red: 0.831, green: 0.639, blue: 0.451)
}

private extension Color {
    /// 按深浅模式返回不同 RGBA（组件扩展不依赖主 App 的 Theme）
    static func eoDynamic(light: Double, green: Double, blue: Double,
                          dark: Double, greenD: Double, blueD: Double) -> Color {
        Color(UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(red: dark, green: greenD, blue: blueD, alpha: 1)
            }
            return UIColor(red: light, green: green, blue: blue, alpha: 1)
        })
    }
}
