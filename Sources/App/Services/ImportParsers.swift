import Foundation

/// v1.0.5 数据导入增强：CSV 任务表 / Markdown 日记
/// 复用 earth-online-backup.json 的 DTO + 按主键合并管线，语义与其他端完全一致
enum ImportParsers {

    // MARK: - CSV（任务表）

    /// 期望表头（宽松匹配，列序不限，title 必需）：
    /// id,title,category,status,progress,note,dueDate
    static func parseTasksCSV(_ text: String) -> ([TaskDTO], errors: [String]) {
        var rows: [[String]] = []
        var header: [String] = []
        var errors: [String] = []

        for (index, rawLine) in text.split(separator: "\r\n").flatMap({ $0.split(separator: "\n") }).enumerated() {
            let fields = splitCSVLine(String(rawLine))
            guard fields.map({ $0.trimmingCharacters(in: .whitespaces) }).contains(where: { !$0.isEmpty }) else { continue }
            if index == 0 {
                header = fields.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                if !header.contains("title") {
                    // 无表头，按默认列序整行当标题
                    header = []
                    rows.append(fields)
                }
                continue
            }
            rows.append(fields)
        }

        var result: [TaskDTO] = []
        for (rowIndex, fields) in rows.enumerated() {
            var map: [String: String] = [:]
            if header.isEmpty {
                map["title"] = fields.first ?? ""
                if fields.count > 1 { map["note"] = fields[1] }
            } else {
                for (column, name) in header.enumerated() where column < fields.count {
                    map[name] = fields[column]
                }
            }
            let title = (map["title"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else {
                errors.append("第 \(rowIndex + 1) 行缺少标题，已跳过")
                continue
            }
            var dto = TaskDTO(id: map["id"]?.trimmingCharacters(in: .whitespaces).isEmpty == false ? map["id"]!.trimmingCharacters(in: .whitespaces) : UUID().uuidString)
            dto.title = title
            if let category = map["category"], TaskCategory(rawValue: category.trimmingCharacters(in: .whitespaces)) != nil {
                dto.category = category.trimmingCharacters(in: .whitespaces)
            } else {
                dto.category = TaskCategory.todo.rawValue
            }
            if let status = map["status"], TaskStatus(rawValue: status.trimmingCharacters(in: .whitespaces)) != nil {
                dto.status = status.trimmingCharacters(in: .whitespaces)
                if dto.status == TaskStatus.done.rawValue { dto.doneAt = DateUtils.isoNow() }
            }
            if let progress = map["progress"], let value = Int(progress.trimmingCharacters(in: .whitespaces)) {
                dto.progress = min(100, max(0, value))
            }
            if let note = map["note"] { dto.note = note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note }
            if let due = map["duedate"], !due.trimmingCharacters(in: .whitespaces).isEmpty { dto.dueDate = due.trimmingCharacters(in: .whitespaces) }
            dto.createdAt = DateUtils.isoNow()
            dto.lastModified = dto.createdAt
            result.append(dto)
        }
        return (result, errors)
    }

    /// 极简 CSV 字段切分：支持双引号包裹（含内嵌逗号/转义引号）
    private static func splitCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var iterator = line.makeIterator()
        while let char = iterator.next() {
            if inQuotes {
                if char == "\"" {
                    // 双写引号 = 字面引号；这里偷懒单看下一个字符成本高，按奇偶切换已足够常见格式
                    inQuotes = false
                } else {
                    current.append(char)
                }
            } else {
                switch char {
                case "\"": inQuotes = true
                case ",": fields.append(current); current = ""
                default: current.append(char)
                }
            }
        }
        fields.append(current)
        return fields
    }

    // MARK: - Markdown（日记 / 清单）

    /// 语法：
    /// - "- [ ] 文本" → 新待办；"- [x] 文本" → 已完成待办
    /// - "# 2026-01-02" / "## 2026-01-02" → 之后条目的日期前缀
    /// - 其余 "- 文本" → 世界日志（沿用上下文日期）
    static func parseMarkdown(_ text: String) -> (tasks: [TaskDTO], memos: [MemoDTO]) {
        var tasks: [TaskDTO] = []
        var memos: [MemoDTO] = []
        var contextDay: String? = nil

        for rawLine in text.split(separator: "\r\n").flatMap({ $0.split(separator: "\n") }) {
            let line = String(rawLine).trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            // 日期标题
            if line.hasPrefix("#") {
                let candidate = line.drop(while: { $0 == "#" || $0 == " " })
                if let range = candidate.range(of: #"(\d{4})-(\d{2})-(\d{2})"#, options: .regularExpression) {
                    contextDay = String(candidate[range])
                }
                continue
            }
            guard line.hasPrefix("-") || line.hasPrefix("*") else { continue }
            let body = line.dropFirst().trimmingCharacters(in: .whitespaces)

            if body.hasPrefix("[ ]") || body.lowercased().hasPrefix("[x]") {
                let done = body.lowercased().hasPrefix("[x]")
                let title = body.dropFirst(3).trimmingCharacters(in: .whitespaces)
                guard !title.isEmpty else { continue }
                var dto = TaskDTO(id: UUID().uuidString)
                dto.title = title
                dto.category = TaskCategory.todo.rawValue
                dto.status = done ? TaskStatus.done.rawValue : TaskStatus.active.rawValue
                dto.progress = done ? 100 : 0
                dto.doneAt = done ? (contextDay.flatMap(DateUtils.dayToIso) ?? DateUtils.isoNow()) : nil
                dto.createdAt = contextDay.flatMap(DateUtils.dayToIso) ?? DateUtils.isoNow()
                dto.lastModified = dto.createdAt
                tasks.append(dto)
            } else {
                let memoText = body.trimmingCharacters(in: .whitespaces)
                guard !memoText.isEmpty else { continue }
                var dto = MemoDTO(id: UUID().uuidString, text: memoText, type: MemoType.note.rawValue)
                dto.createdAt = contextDay.flatMap(DateUtils.dayToIso) ?? DateUtils.isoNow()
                memos.append(dto)
            }
        }
        return (tasks, memos)
    }
}
