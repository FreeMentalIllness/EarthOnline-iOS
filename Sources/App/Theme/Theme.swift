import SwiftUI
import UIKit

// MARK: - 视觉基线（与 Web / Android / Windows 三端一致）

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}

extension Color {
    init(hex: UInt32) { self.init(UIColor(hex: hex)) }

    /// 跟随系统深浅模式取色
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { trait in
            UIColor(hex: trait.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

enum Theme {
    static let background = Color.dynamic(light: 0xf8f6f2, dark: 0x16130f)
    static let surface = Color.dynamic(light: 0xffffff, dark: 0x1e1a16)
    static let surfaceSoft = Color.dynamic(light: 0xfdfbf7, dark: 0x241f1a)
    static let border = Color.dynamic(light: 0xe8e2da, dark: 0x2e2823)
    static let textPrimary = Color.dynamic(light: 0x1e1a16, dark: 0xece7e0)
    static let textSecondary = Color.dynamic(light: 0x7a7268, dark: 0xa9a094)
    static let textMuted = Color.dynamic(light: 0xb0a89c, dark: 0x6f675d)
    static let accent = Color(hex: 0xd4a373)
    static let accentSoft = Color.dynamic(light: 0xf3e7da, dark: 0x3a2e22)

    static let radius: CGFloat = 16
    static let spacing: CGFloat = 14
}

// MARK: - 通用卡片样式

struct CardModifier: ViewModifier {
    var padded: Bool = true

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
        return content
            .padding(padded ? Theme.spacing : 0)
            .background(Theme.surface, in: shape)
            .overlay(shape.stroke(Theme.border, lineWidth: 1))
    }
}

extension View {
    func eoCard(padded: Bool = true) -> some View { modifier(CardModifier(padded: padded)) }
}

struct SectionHeader: View {
    let title: String
    let systemImage: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.accent)
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 4)
            if let actionTitle, let action {
                Button(actionTitle) { action() }
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}

/// 全 0 数据的空状态（三端口径：图表无数据必须给空状态，不能画空轴）
struct EmptyStateView: View {
    let emoji: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 8) {
            Text(emoji).font(.system(size: 34))
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Theme.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.textMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

struct ChipView: View {
    let text: String
    var selected: Bool = false

    var body: some View {
        Text(text)
            .font(.footnote)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(selected ? Theme.accent : Theme.surfaceSoft, in: Capsule())
            .foregroundStyle(selected ? Color.white : Theme.textSecondary)
            .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
    }
}

// MARK: - 头像

struct AvatarView: View {
    var avatarKey: String
    var image: UIImage?
    var size: CGFloat = 56

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Theme.accentSoft
                    Text(avatarEmoji(avatarKey))
                        .font(.system(size: size * 0.45))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Theme.border, lineWidth: 1))
    }

    private func avatarEmoji(_ key: String) -> String {
        switch key {
        case "earth": return "🌍"
        case "rocket": return "🚀"
        case "game": return "🎮"
        case "cat": return "🐱"
        case "leaf": return "🍃"
        case "music": return "🎵"
        case "star": return "⭐️"
        default: return "🧑‍🚀"
        }
    }
}
