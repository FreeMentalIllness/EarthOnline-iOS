import Foundation

/// 沙盒文件存储：头像 / 壁纸 / 记忆相册 / 收藏附件
/// 与 Android ImageStore、Windows 自定义数据目录同语义：二进制只放沙盒，JSON 备份里只记相对路径。
enum LocalFileStore {
    static func baseURL() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("EarthOnline", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 对外共享目录（Info.plist 里 UIFileSharingEnabled = YES），Windows 上可直接拷出备份 JSON
    static func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    static func save(_ data: Data, into folder: String, filename: String) -> String? {
        let dir = baseURL().appendingPathComponent(folder, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent(filename)
        do {
            try data.write(to: file, options: .atomic)
            return "\(folder)/\(filename)"
        } catch {
            return nil
        }
    }

    static func fileURL(_ relativePath: String) -> URL {
        baseURL().appendingPathComponent(relativePath)
    }

    static func load(_ relativePath: String) -> Data? {
        try? Data(contentsOf: fileURL(relativePath))
    }

    static func delete(_ relativePath: String) {
        try? FileManager.default.removeItem(at: fileURL(relativePath))
    }

    static func deleteAllContent() {
        try? FileManager.default.removeItem(at: baseURL())
    }

    /// 把备份 JSON 写到共享目录，方便 iTunes / 文件 App 直接取出
    @discardableResult
    static func exportToDocuments(_ data: Data, filename: String = "earth-online-backup.json") -> URL? {
        let url = documentsDirectory().appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
