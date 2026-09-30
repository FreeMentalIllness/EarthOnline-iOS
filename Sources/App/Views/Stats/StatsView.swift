import Charts
import SwiftData
import SwiftUI

struct StatsView: View {
    @EnvironmentObject private var session: AppSession
    @Query private var memos: [MemoItem]
    @Query private var tasks: [TaskItem]
    @Query private var items: [BagItem]
    @Query private var pins: [LocationPin]
    @Query private var achievements: [AchievementItem]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    overviewGrid
                    xpCard
                    activityChartCard
                    taskCard
                    Spacer(minLength: 20)
                }
                .padding(16)
            }
            .navigationTitle("数据看板")
            .onAppear { session.refresh() }
        }
    }

    // MARK: 概览

    private var overviewGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            StatPillView(emoji: "🗓️", value: "\(session.stats.daysLived)", label: "登陆天数")
            StatPillView(emoji: "✅", value: "\(session.stats.tasksDone)", label: "完成任务")
            StatPillView(emoji: "🎁", value: "\(items.count)", label: "背包物品")
            StatPillView(emoji: "📚", value: "\(session.stats.collections)", label: "收藏")
            StatPillView(emoji: "🗺️", value: "\(pins.count)", label: "足迹")
            StatPillView(emoji: "🔥", value: "\(session.stats.streakDays)", label: "连续记录")
        }
    }

    // MARK: 经验来源

    private var xpCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "经验来源", systemImage: "sparkles")
            Text("总计 \(session.stats.xp) XP")
                .font(.headline)
                .foregroundStyle(Theme.accent)
            let maxValue = max(1, session.stats.xpBreakdown.map { $0.xp }.max() ?? 1)
            ForEach(session.stats.xpBreakdown, id: \.source) { row in
                VStack(spacing: 4) {
                    HStack {
                        Text("\(row.emoji) \(row.source)")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                        Spacer(minLength: 0)
                        Text("\(row.xp) XP")
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(Theme.textPrimary)
                    }
                    LineProgressView(progress: Double(row.xp) / Double(maxValue))
                }
            }
        }
        .eoCard()
    }

    // MARK: 近 7 天日志活跃度

    private var activityChartCard: some View {
        let points = lastSevenDays
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "近 7 天日志", systemImage: "chart.bar")
            if points.allSatisfy({ $0.count == 0 }) {
                EmptyChartHint(text: "近 7 天还没有记录")
            } else {
                Chart(points) { point in
                    BarMark(
                        x: .value("日期", point.label),
                        y: .value("条数", point.count)
                    )
                    .foregroundStyle(Theme.accent)
                    .cornerRadius(4)
                }
                .frame(height: 160)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let int = value.as(Int.self) { Text("\(int)") }
                        }
                    }
                }
            }
        }
        .eoCard()
    }

    private struct DayPoint: Identifiable {
        let id: String
        let label: String
        let count: Int
    }

    private var lastSevenDays: [DayPoint] {
        var buckets: [String: Int] = [:]
        memos.forEach { buckets[DateUtils.dayOfIso($0.createdAt), default: 0] += 1 }
        var keys: [String] = []
        for offset in stride(from: 6, through: 0, by: -1) {
            if let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) {
                keys.append(DateUtils.dayKeyFormatter.string(from: date))
            }
        }
        return keys.map { day in
            let suffix = String(day.suffix(5))
            return DayPoint(id: day, label: suffix, count: buckets[day] ?? 0)
        }
    }

    // MARK: 任务分布

    private var taskCard: some View {
        let counts = taskCounts
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "任务分布", systemImage: "checklist")
            if counts.allSatisfy({ $0.count == 0 }) {
                EmptyChartHint(text: "还没有任务数据")
            } else {
                ForEach(counts) { row in
                    HStack(spacing: 10) {
                        Text(row.emoji)
                        Text(row.label)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textPrimary)
                        Spacer(minLength: 0)
                        Text("\(row.count)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(Theme.textSecondary)
                    }
                    LineProgressView(progress: Double(row.count) / Double(max(1, tasks.count)))
                }
            }
        }
        .eoCard()
    }

    private struct TaskCountRow: Identifiable {
        let id: String
        let label: String
        let emoji: String
        let count: Int
    }

    private var taskCounts: [TaskCountRow] {
        TaskCategory.allCases.map { category in
            TaskCountRow(
                id: category.rawValue,
                label: category.label,
                emoji: category.emoji,
                count: tasks.filter { $0.category == category.rawValue }.count
            )
        } + [TaskCountRow(id: "done", label: "已完成", emoji: "🏁",
                          count: tasks.filter { $0.status == TaskStatus.done.rawValue }.count)]
    }
}
