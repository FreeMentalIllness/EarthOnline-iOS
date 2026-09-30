import SwiftData
import SwiftUI

struct AIView: View {
    @EnvironmentObject private var session: AppSession
    @Query private var tasks: [TaskItem]
    @Query private var memos: [MemoItem]

    @State private var history: [ChatTurn] = []
    @State private var input: String = ""
    @State private var isSending: Bool = false
    @State private var errorMessage: String? = nil

    private let service = AiService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            if history.isEmpty {
                                EmptyStateView(emoji: "🤖", title: "和你的 AI 伙伴聊聊吧",
                                               subtitle: "先在「设置 → AI 助手」配置接口地址、模型与密钥")
                                    .padding(.top, 40)
                            }
                            ForEach(history) { turn in
                                BubbleView(turn: turn)
                                    .id(turn.id)
                            }
                            if let errorMessage {
                                Text(errorMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                                    .eoCard()
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: history.count) { _ in
                        if let last = history.last { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }

                quickPrompts

                HStack(alignment: .bottom, spacing: 8) {
                    TextField("说点什么…", text: $input, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(10)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.border, lineWidth: 1))
                    Button {
                        send()
                    } label: {
                        Image(systemName: isSending ? "hourglass" : "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(isSending ? Theme.textMuted : Theme.accent)
                    }
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }
            .navigationTitle("AI 伙伴")
        }
    }

    private var quickPrompts: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                promptChip("帮我总结今天的待办")
                promptChip("给我一句鼓励")
                promptChip("回顾最近的日志")
                promptChip("推荐一个小目标")
            }
            .padding(.horizontal, 16)
        }
    }

    private func promptChip(_ text: String) -> some View {
        Button {
            input = text
            send()
        } label: {
            ChipView(text: text)
        }
        .buttonStyle(.plain)
    }

    private func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        input = ""
        errorMessage = nil
        history.append(ChatTurn(role: "user", content: text))
        isSending = true
        let pending = history
        let config = session.settings.ai
        Task {
            defer { isSending = false }
            do {
                let reply = try await service.send(history: pending, config: config)
                await MainActor.run { history.append(ChatTurn(role: "assistant", content: reply)) }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }
}

private struct BubbleView: View {
    let turn: ChatTurn

    var body: some View {
        HStack {
            if turn.role == "user" { Spacer(minLength: 40) }
            Text(turn.content)
                .font(.subheadline)
                .foregroundStyle(turn.role == "user" ? .white : Theme.textPrimary)
                .padding(12)
                .background(turn.role == "user" ? Theme.accent : Theme.surface,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(turn.role == "user" ? Color.clear : Theme.border, lineWidth: 1))
            if turn.role == "assistant" { Spacer(minLength: 40) }
        }
    }
}
