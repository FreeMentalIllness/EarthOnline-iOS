import SwiftData
import SwiftUI

/// 首次引导：写入最小可用资料 + 置位 onboarding_done（与 Android/Web 的首次分流同语义）
struct OnboardingView: View {
    @EnvironmentObject private var session: AppSession

    var onFinish: () -> Void

    @State private var name: String = ""
    @State private var gender: String = ""
    @State private var avatarKey: String = "default"
    @State private var birthDate: Date = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    @State private var hasBirthDate: Bool = true
    @State private var step: Int = 0

    private let presets: [(String, String, String)] = [
        ("default", "🧑‍🚀", "旅行者"),
        ("earth", "🌏", "地球主义者"),
        ("rocket", "🚀", "冒险家"),
        ("game", "🎮", "玩家"),
        ("cat", "🐱", "猫系玩家"),
        ("leaf", "🍃", "慢生活家"),
        ("music", "🎵", "吟游诗人"),
        ("star", "⭐️", "追星人")
    ]

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("🌏").font(.system(size: 64))
                Text("欢迎来到地球Online")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("第 \(step + 1) / 3 步 · 随时可以在设置里修改")
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
            }

            VStack(spacing: 14) {
                switch step {
                case 0:
                    TextField("给自己起个名字", text: $name)
                        .textFieldStyle(.roundedBorder)
                    Picker("性别", selection: $gender) {
                        Text("不填").tag("")
                        Text("男").tag("male")
                        Text("女").tag("female")
                        Text("沃尔玛购物袋").tag("walmart")
                    }
                case 1:
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 10)], spacing: 10) {
                        ForEach(presets, id: \.0) { key, emoji, label in
                            Button {
                                avatarKey = key
                            } label: {
                                VStack(spacing: 4) {
                                    Text(emoji).font(.largeTitle)
                                    Text(label).font(.caption2).foregroundStyle(Theme.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(10)
                                .background(avatarKey == key ? Theme.accentSoft : Theme.surface,
                                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(avatarKey == key ? Theme.accent : Theme.border, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                default:
                    Toggle("设置出生日期（用于计算等级 / 时间轴）", isOn: $hasBirthDate)
                    if hasBirthDate {
                        DatePicker("出生日期", selection: $birthDate, in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .labelsHidden()
                    }
                }
            }
            .frame(minHeight: 240)

            HStack(spacing: 12) {
                if step > 0 {
                    Button("上一步") { step -= 1 }
                        .buttonStyle(.bordered)
                }
                Spacer()
                Button(step < 2 ? "下一步" : "开始冒险") {
                    if step < 2 { step += 1 } else { finish() }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
    }

    private func finish() {
        let profile = session.repo.profile()
        profile.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.gender = gender
        profile.avatarKey = avatarKey
        profile.birthDate = hasBirthDate ? DateUtils.dayKeyFormatter.string(from: birthDate) : ""
        session.repo.save()
        onFinish()
    }
}
