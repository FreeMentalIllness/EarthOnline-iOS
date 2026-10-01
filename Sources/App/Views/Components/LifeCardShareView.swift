import SwiftUI

/// v1.0.5 分享人生卡片长图：等级 / 连续记录 / 本月关键词 / 签名
struct LifeCardShareView: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss

    @State private var rendered: UIImage? = nil
    @State private var showShare: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            LifeCard(stats: session.stats,
                     name: displayName,
                     signature: session.repo.profile().signature,
                     keywords: monthKeywords)
                .frame(width: 340, height: 480)
                .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)

            Button {
                renderAndShare()
            } label: {
                Label("生成并分享", systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Theme.accent, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("人生卡片")
        .sheet(isPresented: $showShare) {
            if let rendered { ShareSheet(items: [rendered]) }
        }
    }

    private var displayName: String {
        let name = session.repo.profile().name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "旅行者" : name
    }

    /// 本月关键词：取本月日志的 2 字以上词频 Top3（极简中文口径）
    private var monthKeywords: [String] {
        let prefix = String(DateUtils.todayKey().prefix(7))
        let texts = session.repo.active(MemoItem.self)
            .filter { DateUtils.dayOfIso($0.createdAt).hasPrefix(prefix) }
            .map { $0.text }
        var freq: [String: Int] = [:]
        for text in texts {
            let words = text.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            for word in words where word.count >= 2 && word.count <= 6 {
                freq[String(word), default: 0] += 1
            }
        }
        return freq.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
    }

    private func renderAndShare() {
        let view = LifeCard(stats: session.stats,
                            name: displayName,
                            signature: session.repo.profile().signature,
                            keywords: monthKeywords)
            .frame(width: 340, height: 480)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        if let image = renderer.uiImage {
            rendered = image
            showShare = true
        }
    }
}

/// 卡片本体（固定浅色版式，长图导出不随深色模式漂移）
private struct LifeCard: View {
    let stats: LifeStats
    let name: String
    let signature: String
    let keywords: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Text("🌏").font(.system(size: 34))
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Self.ink)
                    Text("地球Online · 在地球第 \(stats.daysLived) 天")
                        .font(.caption)
                        .foregroundStyle(Self.sub)
                }
                Spacer(minLength: 0)
            }

            HStack(alignment: .bottom, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lv.\(stats.level)")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(Self.accent)
                    Text(stats.title)
                        .font(.footnote)
                        .foregroundStyle(Self.ink)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(stats.currentStreak) 天")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Self.accent)
                    Text("连续记录")
                        .font(.caption)
                        .foregroundStyle(Self.sub)
                }
            }

            Divider().overlay(Self.border)

            VStack(alignment: .leading, spacing: 8) {
                Text("本月关键词")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Self.sub)
                if keywords.isEmpty {
                    Text("记录几条日志，长出你的关键词")
                        .font(.footnote)
                        .foregroundStyle(Self.sub)
                } else {
                    HStack(spacing: 8) {
                        ForEach(keywords, id: \.self) { word in
                            Text(word)
                                .font(.footnote.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Self.accentSoft, in: Capsule())
                                .foregroundStyle(Self.accentDeep)
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            Text(signature.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                 ? "「记录本身就是意义。」"
                 : "「\(signature)」")
                .font(.footnote.italic())
                .foregroundStyle(Self.sub)
                .lineLimit(2)
        }
        .padding(22)
        .background(Self.paper)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Self.border, lineWidth: 1))
    }

    private static let paper = Color(red: 0.973, green: 0.965, blue: 0.949)
    private static let ink = Color(red: 0.118, green: 0.102, blue: 0.086)
    private static let sub = Color(red: 0.478, green: 0.447, blue: 0.408)
    private static let accent = Color(red: 0.831, green: 0.639, blue: 0.451)
    private static let accentSoft = Color(red: 0.953, green: 0.906, blue: 0.855)
    private static let accentDeep = Color(red: 0.62, green: 0.44, blue: 0.27)
    private static let border = Color(red: 0.91, green: 0.886, blue: 0.855)
}
