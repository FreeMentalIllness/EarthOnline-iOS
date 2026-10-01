import PhotosUI
import SwiftUI

/// 相册选择器（头像 / 壁纸 / 收藏附件共用）
struct PhotoPickerView: View {
    var title: String = "从相册选择"
    var onPick: (Data) -> Void

    @State private var selection: PhotosPickerItem? = nil

    var body: some View {
        PhotosPicker(selection: $selection, matching: .images, photoLibrary: .shared()) {
            Label(title, systemImage: "photo")
        }
        .onChange(of: selection) { _, newValue in
            guard let newValue else { return }
            Task {
                if let data = try? await newValue.loadTransferable(type: Data.self) {
                    await MainActor.run { onPick(data) }
                }
                // 消费后清空，保证同一张照片再次选择仍能触发回调
                await MainActor.run { selection = nil }
            }
        }
    }
}

/// 数值条（数据看板 / 主页概览共用）
struct StatPillView: View {
    let emoji: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(emoji).font(.system(size: 18))
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.surfaceSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.border, lineWidth: 1))
    }
}

/// 进度条（等级 / 任务进度共用）
struct LineProgressView: View {
    var progress: Double
    var tint: Color = Theme.accent

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.border.opacity(0.6))
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, min(1, progress)) * proxy.size.width)
            }
        }
        .frame(height: 6)
    }
}

/// 数据全 0 时不画图的兜底（三端口径）
struct EmptyChartHint: View {
    let text: String

    var body: some View {
        EmptyStateView(emoji: "📊", title: text, subtitle: "记录几条数据之后，这里会长出图表")
    }
}
