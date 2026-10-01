import PhotosUI
import SwiftData
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var session: AppSession
    @EnvironmentObject private var liveActivity: LiveActivityManager

    @Query(sort: [SortDescriptor(\ActivityItem.time, order: .reverse)]) private var activities: [ActivityItem]
    @Query(sort: [SortDescriptor(\MemoItem.createdAt, order: .reverse)]) private var memos: [MemoItem]
    @Query private var tasks: [TaskItem]
    @Query private var profiles: [ProfileItem]
    @Query private var pins: [LocationPin]

    @State private var quickLog: String = ""
    @State private var memoType: MemoType = .note
    @State private var showProfileSheet: Bool = false
    @State private var showThrowback: Bool = false

    private var profile: ProfileItem? { profiles.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    greetingSection
                    moodChips
                    levelCard
                    quickEntries
                    quickLogCard
                    throwbackCard
                    timelineCard
                    recentFeedCard
                    Spacer(minLength: 24)
                }
                .padding(16)
            }
            .navigationTitle("主页")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        toggleLiveActivity()
                    } label: {
                        Image(systemName: liveActivity.isRunning ? "waveform.circle.fill" : "waveform")
                            .foregroundStyle(liveActivity.isRunning ? Theme.accent : Theme.textSecondary)
                    }
                    .disabled(!liveActivity.supported)
                }
            }
            .background(Color.clear)
            .onAppear { session.refresh() }
            .sheet(isPresented: $showProfileSheet) {
                if let profile {
                    ProfileEditView(profile: profile)
                }
            }
        }
    }

    // MARK: - 区块

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(DateUtils.greeting())，\(displayName)")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("今天是你在地球的第 \(max(0, session.stats.daysLived)) 天 · 连续记录 \(session.stats.currentStreak) 天（最高 \(session.stats.streakDays) 天）")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
            let flavor = DateUtils.moodFlavor(session.settings.moodToday)
            if !flavor.isEmpty {
                Text(flavor)
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 今日心情（v1.0.5：动态问候语的时间段 + 心情）
    private var moodChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                moodChip("great", "😄 状态拉满")
                moodChip("good", "🙂 顺风局")
                moodChip("normal", "😐 平平淡淡")
                moodChip("tired", "😪 有点累")
                moodChip("down", "🌧️ 低气压")
            }
        }
    }

    private func moodChip(_ key: String, _ label: String) -> some View {
        Button {
            session.settings.moodToday = session.settings.moodToday == key ? "" : key
        } label: {
            ChipView(text: label, selected: session.settings.moodToday == key)
        }
        .buttonStyle(.plain)
    }

    private var levelCard: some View {
        Button { showProfileSheet = true } label: {
            HStack(alignment: .center, spacing: 14) {
                avatarView
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("Lv.\(session.stats.level)")
                            .font(.headline)
                            .foregroundStyle(Theme.accent)
                        Text(session.stats.title)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textPrimary)
                    }
                    Text("\(session.stats.xp) XP")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                    LineProgressView(progress: session.stats.nextLevelProgress)
                    Text("距离下一个生日 \(Int((1 - session.stats.nextLevelProgress) * 100))%")
                        .font(.caption2)
                        .foregroundStyle(Theme.textMuted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
            }
            .eoCard()
        }
        .buttonStyle(.plain)
    }

    private var avatarView: some View {
        let image: UIImage? = {
            guard let path = profile?.avatarPath, let data = LocalFileStore.load(path) else { return nil }
            return UIImage(data: data)
        }()
        return AvatarView(avatarKey: profile?.avatarKey ?? "", image: image, size: 58)
    }

    private var quickEntries: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "速览", systemImage: "square.grid.2x2")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
                entry("任务", emoji: "🎯", subtitle: "\(session.stats.openTasks) 项进行中") { TasksView() }
                entry("背包", emoji: "🎒", subtitle: "\(session.stats.items) 件物品") { BackpackView() }
                entry("成就", emoji: "🏅", subtitle: "\(session.stats.achievements) 枚已解锁") { AchievementsView() }
                entry("足迹", emoji: "🗺️", subtitle: "\(session.stats.locations) 个坐标") { MapScreen() }
                entry("看板", emoji: "📊", subtitle: "数据概览") { StatsView() }
                entry("AI 伙伴", emoji: "🤖", subtitle: "随时聊两句") { AIView() }
                entry("人生卡片", emoji: "🪪", subtitle: "生成长图分享") { LifeCardShareView() }
            }
        }
    }

    private func entry<Destination: View>(_ title: String, emoji: String, subtitle: String,
                                          @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink(destination: destination) {
            VStack(alignment: .leading, spacing: 6) {
                Text(emoji).font(.title3)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(Theme.textMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: 世界日志速记

    private var quickLogCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "世界日志", systemImage: "text.bubble")
            HStack(spacing: 8) {
                ForEach(MemoType.allCases) { type in
                    Button {
                        memoType = type
                    } label: {
                        ChipView(text: "\(type.emoji) \(type.label)", selected: memoType == type)
                    }
                    .buttonStyle(.plain)
                }
            }
            TextField("此刻的想法……", text: $quickLog, axis: .vertical)
                .lineLimit(2...4)
                .padding(12)
                .background(Theme.surfaceSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            HStack {
                Button {
                    let text = quickLog.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    session.repo.addMemo(text: text, type: memoType)
                    // 灵感接力：灵感类日志 1 小时后本地提醒，点按即可转待办
                    if memoType == .idea {
                        NotificationService.scheduleInspiration(text, delay: 3600)
                    }
                    quickLog = ""
                    session.didMutateData()
                } label: {
                    Label("记一笔", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                Spacer()
                if let last = memos.first(where: { $0.deletedAt == nil }) {
                    Text("上一条：\(DateUtils.relative(last.createdAt))")
                        .font(.caption2)
                        .foregroundStyle(Theme.textMuted)
                }
            }
        }
    }

    // MARK: 人生时间轴

    private var timelineCard: some View {
        let events = timelineEvents
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "人生时间轴", systemImage: "timeline.selection",
                          actionTitle: "添加") { addTimelineEvent() }
            if events.isEmpty {
                EmptyStateView(emoji: "🛤️", title: "还没有里程碑",
                               subtitle: "设置出生日期后会自动生成百日 / 周岁等节点")
            } else {
                ForEach(events) { event in
                    HStack(alignment: .top, spacing: 10) {
                        Text(event.emoji)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title)
                                .font(.subheadline)
                                .foregroundStyle(Theme.textPrimary)
                            Text(event.date)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(Theme.textMuted)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .eoCard()
    }

    private struct TimelineItem: Identifiable {
        let id: String
        let emoji: String
        let title: String
        let date: String
    }

    private var timelineEvents: [TimelineItem] {
        var result: [TimelineItem] = []
        let birth = profile?.birthDate ?? ""
        if !birth.isEmpty {
            let milestones: [(Int, String, String)] = [
                (100, "🌱", "来到地球满 100 天"),
                (365, "🎂", "一周岁生日"),
                (1000, "🚀", "千日之行"),
                (5000, "🏔️", "万水千山"),
                (10000, "🌌", "万日玩家")
            ]
            for item in milestones {
                guard let day = DateUtils.birthPlusDays(birth, days: item.0) else { continue }
                if day <= DateUtils.todayKey() {
                    result.append(TimelineItem(id: "auto-\(item.0)", emoji: item.1, title: item.2, date: day))
                }
            }
            if let adult = DateUtils.birthPlusYears(birth, years: 18), adult <= DateUtils.todayKey() {
                result.append(TimelineItem(id: "auto-adult", emoji: "🎓", title: "成年礼 · 18 周岁", date: adult))
            }
        }
        result.append(contentsOf: session.settings.customTimeline.map {
            TimelineItem(id: $0.id, emoji: $0.emoji, title: $0.title, date: $0.date)
        })
        if let birthDay = DateUtils.birthPlusYears(birth, years: 0), !birth.isEmpty {
            result.append(TimelineItem(id: "auto-birth", emoji: "🌍", title: "登陆地球", date: birthDay))
        }
        return result.sorted { $0.date < $1.date }
    }

    private func addTimelineEvent() {
        session.settings.customTimeline.append(
            TimelineEvent(title: "新的里程碑", date: DateUtils.todayKey())
        )
    }

    // MARK: 历年今日回顾（v1.0.5，触发 egg_throwback）

    private var throwbackItems: [ThrowbackItem] {
        let todaySuffix = DateUtils.monthDay(of: DateUtils.todayKey()) // "MM-dd"
        guard !todaySuffix.isEmpty else { return [] }
        var result: [ThrowbackItem] = []
        for memo in memos where memo.deletedAt == nil {
            let day = DateUtils.dayOfIso(memo.createdAt)
            if DateUtils.monthDay(of: day) == todaySuffix, day != DateUtils.todayKey() {
                result.append(ThrowbackItem(year: String(day.prefix(4)), emoji: "📝", text: memo.text))
            }
        }
        for pin in pins {
            let day = pin.date
            if DateUtils.monthDay(of: day) == todaySuffix, day != DateUtils.todayKey() {
                result.append(ThrowbackItem(year: String(day.prefix(4)), emoji: "🗺️", text: "足迹：\(pin.name)"))
            }
        }
        for task in tasks where task.deletedAt == nil {
            let day = DateUtils.dayOfIso(task.doneAt ?? "")
            if DateUtils.monthDay(of: day) == todaySuffix, day != DateUtils.todayKey() {
                result.append(ThrowbackItem(year: String(day.prefix(4)), emoji: "✅", text: "完成：\(task.title)"))
            }
        }
        return result.sorted { $0.year > $1.year }
    }

    private var throwbackCard: some View {
        let items = throwbackItems
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                showThrowback.toggle()
                if showThrowback && !items.isEmpty {
                    EggCounters.markThrowbackSeen()
                    session.refresh() // 触发成就判定
                }
            } label: {
                HStack(spacing: 6) {
                    Text("🕰️ 历史上的今天")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer(minLength: 4)
                    Image(systemName: showThrowback ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(Theme.textMuted)
                }
            }
            .buttonStyle(.plain)

            if showThrowback {
                if items.isEmpty {
                    Text("往年的今天还没有记录，写下第一条吧")
                        .font(.caption)
                        .foregroundStyle(Theme.textMuted)
                } else {
                    ForEach(Array(items.prefix(6).enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 8) {
                            Text(item.emoji)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.text)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.textPrimary)
                                    .lineLimit(2)
                                Text("\(item.year) 年的今天")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.textMuted)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
        }
        .eoCard()
    }

    private struct ThrowbackItem {
        let year: String
        let emoji: String
        let text: String
    }

    // MARK: 最近动态

    private var recentFeedCard: some View {
        let limit = session.settings.homeFeedLimit
        let list = limit > 0 ? Array(activities.prefix(limit)) : activities
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "最近动态", systemImage: "clock.arrow.circlepath")
            if list.isEmpty {
                EmptyStateView(emoji: "🌤️", title: "还没有动态", subtitle: "完成任务、记录日志都会出现在这里")
            } else {
                ForEach(list, id: \.persistentModelID) { item in
                    HStack(spacing: 10) {
                        Text(ActivityKind(rawValue: item.kind)?.emoji ?? "•")
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.subheadline)
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(2)
                            Text(DateUtils.relative(item.time))
                                .font(.caption2)
                                .foregroundStyle(Theme.textMuted)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .eoCard()
    }

    private var displayName: String {
        let name = profile?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "旅行者" : name
    }

    /// 灵动岛实时活动开关（App 进程推送数据，无需 App Group）
    private func toggleLiveActivity() {
        if liveActivity.isRunning {
            liveActivity.end()
        } else {
            liveActivity.start(stats: session.stats)
        }
    }
}
