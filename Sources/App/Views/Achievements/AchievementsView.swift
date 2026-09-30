import SwiftData
import SwiftUI

struct AchievementsView: View {
    @EnvironmentObject private var session: AppSession
    @Query private var rows: [AchievementItem]

    @State private var showAddManual: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    summaryCard
                    ForEach(AchCategories.all) { category in
                        categorySection(category)
                    }
                    Spacer(minLength: 20)
                }
                .padding(16)
            }
            .navigationTitle("成就")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showAddManual = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAddManual) {
                ManualAchievementView { title, desc, category in
                    session.repo.addManualAchievement(title: title, desc: desc, category: category)
                    session.didMutateData()
                }
            }
            .onAppear { session.refresh() }
        }
    }

    private var summaryCard: some View {
        let unlockedCount = rows.filter { $0.unlocked }.count
        let total = max(rows.count, AutoRules.all.count)
        return HStack(spacing: 14) {
            Text("🏅").font(.largeTitle)
            VStack(alignment: .leading, spacing: 6) {
                Text("已解锁 \(unlockedCount) / \(max(total, 1))")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                LineProgressView(progress: total == 0 ? 0 : Double(unlockedCount) / Double(total))
            }
            Spacer(minLength: 0)
        }
        .eoCard()
    }

    private func categorySection(_ category: AchCategory) -> some View {
        let items = displayRows.filter { $0.category == category.id }
        return Group {
            if !items.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "\(category.emoji) \(category.label)", systemImage: "seal")
                    ForEach(items) { row in
                        AchievementRowView(row: row)
                    }
                }
            }
        }
    }

    // MARK: 数据整合

    private var displayRows: [AchRow] {
        var result: [AchRow] = []
        // 1. 自动成就：规则为准，未建行时按 progress 展示
        let stats = session.engine.achievementStats()
        for rule in AutoRules.all {
            let existing = rows.first { $0.autoKey == rule.key }
            result.append(AchRow(
                id: rule.key,
                title: rule.title,
                desc: rule.desc,
                category: rule.category,
                unlocked: existing?.unlocked ?? false,
                progress: rule.progress(of: stats),
                goal: rule.goalValue(),
                unlockedAt: existing?.unlockedAt,
                isManual: false
            ))
        }
        // 2. 手动成就
        for row in rows where row.type != "auto" {
            result.append(AchRow(id: row.recordId, title: row.title, desc: row.achDesc,
                                 category: row.category ?? AchCategories.customId, unlocked: row.unlocked,
                                 progress: row.unlocked ? 1 : 0, goal: 1, unlockedAt: row.unlockedAt, isManual: true))
        }
        return result
    }
}

struct AchRow: Identifiable {
    let id: String
    let title: String
    let desc: String
    let category: String
    let unlocked: Bool
    let progress: Int
    let goal: Int
    let unlockedAt: String?
    let isManual: Bool
}

struct AchievementRowView: View {
    @EnvironmentObject private var session: AppSession
    let row: AchRow

    var body: some View {
        let masked = row.category == AchCategories.eggId && !row.unlocked
        return HStack(alignment: .top, spacing: 12) {
            Text(row.unlocked ? "🏅" : (masked ? "🥚" : "🔒"))
                .font(.title3)
                .opacity(row.unlocked ? 1 : 0.45)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(masked ? AchCategories.eggMask : row.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(row.unlocked ? Theme.textPrimary : Theme.textSecondary)
                    Spacer(minLength: 0)
                    if row.isManual {
                        Button {
                            manualToggle()
                        } label: {
                            Image(systemName: row.unlocked ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(row.unlocked ? Theme.accent : Theme.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text(masked ? AchCategories.eggMaskDesc : row.desc)
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
                if !row.unlocked && !masked {
                    LineProgressView(progress: Double(row.progress) / Double(max(1, row.goal)))
                    Text("\(row.progress) / \(row.goal)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Theme.textMuted)
                } else if let at = row.unlockedAt, row.unlocked {
                    Text("解锁于 \(DateUtils.dayOfIso(at))")
                        .font(.caption2)
                        .foregroundStyle(Theme.textMuted)
                }
            }
        }
        .eoCard()
    }

    private func manualToggle() {
        guard let item = session.repo.all(AchievementItem.self).first(where: { $0.recordId == row.id }) else { return }
        if item.unlocked {
            item.unlocked = false
            item.unlockedAt = nil
        } else {
            item.unlocked = true
            item.unlockedAt = DateUtils.isoNow()
        }
        session.repo.save()
        session.didMutateData()
    }
}

struct ManualAchievementView: View {
    @Environment(\.dismiss) private var dismiss
    var onCreate: (String, String, String) -> Void

    @State private var title: String = ""
    @State private var desc: String = ""
    @State private var category: String = AchCategories.customId

    var body: some View {
        NavigationStack {
            Form {
                Section("自定义成就") {
                    TextField("名称", text: $title)
                    TextField("描述", text: $desc, axis: .vertical)
                    Picker("分类", selection: $category) {
                        ForEach(AchCategories.all) { item in
                            Text("\(item.emoji) \(item.label)").tag(item.id)
                        }
                    }
                }
            }
            .navigationTitle("新建成就")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onCreate(trimmed, desc.trimmingCharacters(in: .whitespacesAndNewlines), category)
                        dismiss()
                    }
                }
            }
        }
    }
}
