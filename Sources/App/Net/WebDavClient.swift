import Foundation

/// 极简 WebDAV 客户端（URLSession 实现，不引第三方库）
/// 能力：PROPFIND 列目录 / GET 下载 / PUT 上传 / MKCOL 建目录，与 Android WebDavService 一一对应。
struct WebDavEntry {
    let href: String
    let isDirectory: Bool
    let size: Int64
}

// 端点配置复用 Settings 里的 WebDavConfig（单一定义，避免两处漂移）

struct WebDavError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

final class WebDavClient {
    private let config: WebDavConfig
    private let session: URLSession

    init(_ endpoint: WebDavConfig) {
        self.config = endpoint
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 30
        sessionConfig.waitsForConnectivity = false
        self.session = URLSession(configuration: sessionConfig)
    }

    // MARK: - 操作

    /// 连接测试：对远端目录发 PROPFIND，成功即认为可用
    func connect() async throws {
        let url = try directoryURL()
        var request = URLRequest(url: url)
        request.httpMethod = "PROPFIND"
        request.setValue("1", forHTTPHeaderField: "Depth")
        request.setValue("text/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.propfindBody.data(using: .utf8)
        applyAuth(&request)
        let (_, response) = try await session.data(for: request)
        let code = Self.statusCode(response)
        if code == 404 {
            // 目录不存在时尝试自动创建
            try await makeCollection()
            return
        }
        try validate(code, operation: "连接测试")
    }

    func list() async throws -> [WebDavEntry] {
        let url = try directoryURL()
        var request = URLRequest(url: url)
        request.httpMethod = "PROPFIND"
        request.setValue("1", forHTTPHeaderField: "Depth")
        request.httpBody = Self.propfindBody.data(using: .utf8)
        applyAuth(&request)
        let (data, response) = try await session.data(for: request)
        try validate(Self.statusCode(response), operation: "列目录")
        return Self.parse(xml: String(data: data, encoding: .utf8) ?? "")
    }

    func download() async throws -> Data {
        let url = try fileURL()
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyAuth(&request)
        let (data, response) = try await session.data(for: request)
        let code = Self.statusCode(response)
        if code == 404 { throw WebDavError(message: "云端还没有备份文件，先在本机上传一次") }
        try validate(code, operation: "下载")
        return data
    }

    func upload(_ data: Data) async throws {
        let _ = try await makeCollectionToleratingExists()
        let url = try fileURL()
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        applyAuth(&request)
        let (_, response) = try await session.upload(for: request, from: data)
        try validate(Self.statusCode(response), operation: "上传")
    }

    func makeCollection() async throws {
        let url = try directoryURL()
        var request = URLRequest(url: url)
        request.httpMethod = "MKCOL"
        applyAuth(&request)
        let (_, response) = try await session.data(for: request)
        let code = Self.statusCode(response)
        if code == 405 { return }
        try validate(code, operation: "创建目录")
    }

    private func makeCollectionToleratingExists() async throws -> Bool {
        let url = try directoryURL()
        var request = URLRequest(url: url)
        request.httpMethod = "MKCOL"
        applyAuth(&request)
        let (_, response) = try await session.data(for: request)
        let code = Self.statusCode(response)
        if code == 405 { return true }
        if (200..<300).contains(code) { return true }
        throw WebDavError(message: Self.friendly(operation: "创建目录", code: code))
    }

    // MARK: - URL

    private func baseComponents() throws -> URLComponents {
        var raw = config.baseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { throw WebDavError(message: "请先填写 WebDAV 服务器地址") }
        if !raw.hasPrefix("http://") && !raw.hasPrefix("https://") { raw = "https://" + raw }
        guard var components = URLComponents(string: raw) else {
            throw WebDavError(message: "服务器地址格式不正确")
        }
        return components
    }

    private func url(extraSegments: [String], trailingSlash: Bool) throws -> URL {
        var components = try baseComponents()
        let existing = components.percentEncodedPath.components(separatedBy: "/").filter { !$0.isEmpty }
        let raw = [config.remoteDir] + extraSegments
        let segments = raw.flatMap { $0.components(separatedBy: "/") }.filter { !$0.isEmpty }
        let encoded = segments.map { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? $0 }
        let path = "/" + (existing + encoded).joined(separator: "/") + (trailingSlash ? "/" : "")
        components.percentEncodedPath = path
        components.query = nil
        components.fragment = nil
        guard let url = components.url else { throw WebDavError(message: "无法拼接远端地址") }
        return url
    }

    private func directoryURL() throws -> URL { try url(extraSegments: [], trailingSlash: true) }
    private func fileURL() throws -> URL { try url(extraSegments: [config.fileName], trailingSlash: false) }

    // MARK: - 内部

    private func applyAuth(_ request: inout URLRequest) {
        guard !config.user.isEmpty || !config.password.isEmpty else { return }
        let raw = "\(config.user):\(config.password)"
        let token = Data(raw.utf8).base64EncodedString()
        request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
    }

    private func validate(_ code: Int, operation: String) throws {
        if (200..<300).contains(code) { return }
        throw WebDavError(message: Self.friendly(operation: operation, code: code))
    }

    static func statusCode(_ response: URLResponse) -> Int {
        (response as? HTTPURLResponse)?.statusCode ?? -1
    }

    static func friendly(operation: String, code: Int) -> String {
        switch code {
        case 401, 403: return "账号或密码错误（\(code)），请检查 WebDAV 配置"
        case 404: return "路径不存在（404），请检查服务器目录"
        case 405: return "目标已存在或被服务器拒绝（405）"
        case 409: return "上级目录不存在（409），请先在服务器创建对应目录"
        case 423: return "文件被锁定（423），请稍后重试"
        case 200..<300: return "OK"
        case 500...: return "服务器暂时不可用（\(code)），请稍后重试"
        default: return "\(operation)失败（\(code)），请检查网络与服务器配置"
        }
    }

    private static let propfindBody = "<propfind xmlns=\"DAV:\"><prop><resourcetype/><getcontentlength/></prop></propfind>"

    private static func parse(xml: String) -> [WebDavEntry] {
        var output: [WebDavEntry] = []
        let pattern = "<(?:D:)?response>(.*?)</(?:D:)?response>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return output }
        let hrefPattern = "<(?:D:)?href>(.*?)</(?:D:)?href>"
        guard let hrefRegex = try? NSRegularExpression(pattern: hrefPattern, options: []) else { return output }
        let range = NSRange(xml.startIndex..., in: xml)
        for match in regex.matches(in: xml, options: [], range: range) {
            guard let groupRange = Range(match.range(at: 1), in: xml) else { continue }
            let block = String(xml[groupRange])
            let href: String = {
                let r = NSRange(block.startIndex..., in: block)
                guard let m = hrefRegex.firstMatch(in: block, options: [], range: r),
                      let gr = Range(m.range(at: 1), in: block) else { return "" }
                return String(block[gr])
            }()
            if href.isEmpty { continue }
            let isDirectory = block.contains("<D:collection") || block.contains("<collection") || href.hasSuffix("/")
            let sizePattern = "<(?:D:)?getcontentlength>(\\d+)<"
            let size: Int64 = {
                guard let r = try? NSRegularExpression(pattern: sizePattern, options: []),
                      let m = r.firstMatch(in: block, options: [], range: NSRange(block.startIndex..., in: block)),
                      let gr = Range(m.range(at: 1), in: block) else { return 0 }
                return Int64(block[gr]) ?? 0
            }()
            output.append(WebDavEntry(href: href, isDirectory: isDirectory, size: size))
        }
        return output
    }
}
