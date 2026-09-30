import Foundation

struct ChatTurn: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var role: String          // system / user / assistant
    var content: String
}

enum AiError: LocalizedError {
    case notConfigured
    case badResponse(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "AI 尚未配置，请到「设置 → AI 助手」填写接口地址、模型与密钥"
        case .badResponse(let text): return text
        }
    }
}

/// OpenAI 兼容接口（/chat/completions），不绑定任何厂商
final class AiService {
    private struct Message: Codable {
        let role: String
        let content: String
    }

    private struct RequestBody: Codable {
        let model: String
        let messages: [Message]
        let temperature: Double
    }

    private struct Choice: Codable {
        let message: Message
    }

    private struct ResponseBody: Codable {
        let choices: [Choice]
    }

    private struct ErrorBody: Codable {
        let error: ErrorDetail?
    }

    private struct ErrorDetail: Codable {
        let message: String?
    }

    static let systemPrompt = """
    你是「地球Online」里陪玩家冒险的伙伴。回答用中文，简短、有温度，一句多余的客套都不要。
    玩家可以让你总结任务、鼓励自己、整理日志，也可以纯聊天。
    """

    func send(history: [ChatTurn], config: AiConfig) async throws -> String {
        guard !config.baseUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !config.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AiError.notConfigured
        }

        let base = config.baseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let root = base.hasSuffix("/") ? String(base.dropLast()) : base
        let endpoint: URL?
        if root.hasSuffix("/chat/completions") {
            endpoint = URL(string: root)
        } else {
            endpoint = URL(string: root + "/v1/chat/completions") ?? URL(string: root + "/chat/completions")
        }
        guard let url = endpoint else { throw AiError.badResponse("接口地址无法解析") }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines))",
                         forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60

        let messages = [Message(role: "system", content: Self.systemPrompt)] + history.map {
            Message(role: $0.role, content: $0.content)
        }
        let body = RequestBody(model: config.model, messages: messages, temperature: 0.7)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1

        if let wrapper = try? JSONDecoder().decode(ResponseBody.self, from: data),
           let text = wrapper.choices.first?.message.content, !text.isEmpty {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let detail = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error?.message
        let raw = String(data: data, encoding: .utf8) ?? ""
        throw AiError.badResponse(detail ?? "请求失败（\(code)）：\(String(raw.prefix(160)))")
    }
}
