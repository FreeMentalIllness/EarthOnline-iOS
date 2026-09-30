import ActivityKit
import SwiftUI
import WidgetKit

/// 灵动岛 + 锁屏实时活动（小组件 Extension 承载 UI，App 侧负责更新数据）
struct EarthOnlineLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: EarthOnlineAttributes.self) { context in
            let state = context.state
            HStack(spacing: 12) {
                Text(state.emoji).font(.title)
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(red: 0.12, green: 0.10, blue: 0.08))
                    Text(state.detail)
                        .font(.caption)
                        .foregroundStyle(Color(red: 0.48, green: 0.45, blue: 0.41))
                }
                Spacer(minLength: 0)
                VStack(spacing: 4) {
                    Text("Lv.\(state.level)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color(red: 0.83, green: 0.64, blue: 0.45))
                    ProgressView(value: state.progress)
                        .progressViewStyle(.linear)
                        .frame(width: 72)
                        .tint(Color(red: 0.83, green: 0.64, blue: 0.45))
                }
            }
            .padding(14)
            .activityBackgroundTint(Color(red: 0.97, green: 0.96, blue: 0.95))
            .activitySystemActionForegroundColor(Color(red: 0.12, green: 0.10, blue: 0.08))
            .widgetURL(URL(string: "earthonline://home"))
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(state.emoji).font(.title2)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(state.title).font(.caption.weight(.semibold))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Lv.\(state.level)").font(.caption2.monospacedDigit())
                        Text(state.detail).font(.caption2)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: state.progress)
                        .tint(Color(red: 0.83, green: 0.64, blue: 0.45))
                }
            } compactLeading: {
                Text(state.emoji)
            } compactTrailing: {
                Text("\(Int(state.progress * 100))%")
                    .font(.caption2.monospacedDigit())
            } minimal: {
                Text(state.emoji)
            }
            .widgetURL(URL(string: "earthonline://tasks"))
        }
    }
}
