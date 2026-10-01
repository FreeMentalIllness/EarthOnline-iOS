import Foundation

/// 更新提示（SideStore 约束下只能提示引导，无法应用内静默更新）
struct UpdateAlert: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    /// 非空时弹窗提供「前往下载」按钮
    let url: URL?
}

/// GitHub Releases 版本检查（零依赖 URLSession）
/// 整类 MainActor：要读写 AppSession 的 @Published 状态，UI 调用点都在主线程
@MainActor
final class VersionCheckService {
    /// 仓库 Releases 页面（浏览器打开用）
    static let releasesPage = URL(string: "https://github.com/FreeMentalIllness/EarthOnline-iOS/releases")!
    private static let apiURL = URL(string: "https://api.github.com/repos/FreeMentalIllness/EarthOnline-iOS/releases/latest")!
    private static let lastAutoCheckKey = "last_update_check_at"
    private static let autoCheckMinInterval: TimeInterval = 24 * 3600

    struct RemoteRelease {
        let tag: String
        let pageURL: URL
    }

    // MARK: - 对外动作

    /// 启动时的自动检查（静默失败，24 小时至多一次）
    static func autoCheckIfNeeded(session: AppSession) {
        let store = UserDefaults.standard
        let now = Date().timeIntervalSince1970
        guard now - store.double(forKey: lastAutoCheckKey) >= autoCheckMinInterval else { return }
        store.set(now, forKey: lastAutoCheckKey)
        runCheck(session: session, manual: false)
    }

    /// 手动「检查更新」（任何失败都给出中文反馈）
    static func manualCheck(session: AppSession) {
        runCheck(session: session, manual: true)
    }

    // MARK: - 内部

    private static func runCheck(session: AppSession, manual: Bool) {
        guard !session.isCheckingUpdate else { return }
        session.isCheckingUpdate = true
        Task {
            defer { session.isCheckingUpdate = false }
            do {
                let release = try await fetchLatest()
                let local = localVersion()
                guard isNewer(release.tag, than: local) else {
                    if manual {
                        session.updateAlert = UpdateAlert(
                            title: "检查更新",
                            message: "已是最新版本（v\(local)）。",
                            url: nil
                        )
                    }
                    return
                }
                session.updateAlert = UpdateAlert(
                    title: "发现新版本 \(release.tag)",
                    message: "检测到新版本 \(release.tag)，请前往 GitHub Actions 或 SideStore 下载最新 .ipa 进行覆盖安装。由于 SideStore 7 天签名机制，应用内无法直接自动更新，需要手动操作。",
                    url: release.pageURL
                )
            } catch {
                guard manual else { return }
                session.updateAlert = UpdateAlert(
                    title: "检查更新",
                    message: "检查更新失败：" + SyncManager.friendlyError(error),
                    url: nil
                )
            }
        }
    }

    /// 请求 GitHub Releases API 取最新版本
    static func fetchLatest() async throws -> RemoteRelease {
        var request = URLRequest(url: apiURL)
        request.httpMethod = "GET"
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        if code == 404 {
            throw WebDavError(message: "仓库还没有发布过任何 Release，敬请期待")
        }
        guard (200..<300).contains(code) else {
            throw WebDavError(message: "获取版本信息失败（\(code)），请稍后重试")
        }
        struct Payload: Decodable {
            let tagName: String?
            let htmlURL: String?
            enum CodingKeys: String, CodingKey {
                case tagName = "tag_name"
                case htmlURL = "html_url"
            }
        }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data),
              let tag = payload.tagName, !tag.isEmpty else {
            throw WebDavError(message: "版本信息格式异常，请稍后重试")
        }
        let page = payload.htmlURL.flatMap(URL.init(string:)) ?? releasesPage
        return RemoteRelease(tag: normalize(tag), pageURL: page)
    }

    /// 本地版本号（Info.plist CFBundleShortVersionString）
    static func localVersion() -> String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    /// 语义化比较：v1.0.5 > v1.0.4；段数不足按 0 补齐；非数字段忽略
    static func isNewer(_ remote: String, than local: String) -> Bool {
        lexicographicGreater(remote, local)
    }

    private static func normalize(_ tag: String) -> String {
        tag.hasPrefix("v") || tag.hasPrefix("V") ? "v" + String(tag.dropFirst()) : (tag.first?.isNumber == true ? "v" + tag : tag)
    }

    private static func numericComponents(_ version: String) -> [Int] {
        version.trimmingCharacters(in: .whitespaces)
            .drop { !$0.isNumber }
            .split(whereSeparator: { $0 == "." || $0 == "-" })
            .compactMap { Int($0) }
    }

    private static func lexicographicGreater(_ a: String, _ b: String) -> Bool {
        let la = numericComponents(a), lb = numericComponents(b)
        let count = max(la.count, lb.count)
        for i in 0..<count {
            let x = i < la.count ? la[i] : 0
            let y = i < lb.count ? lb[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
