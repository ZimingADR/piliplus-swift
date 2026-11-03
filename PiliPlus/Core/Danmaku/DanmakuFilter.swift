import Foundation

/// 本地弹幕屏蔽：普通关键词（大小写不敏感）或 `/正则/`。
enum DanmakuFilter {
    static func apply(
        _ items: [DanmakuItem],
        blockedKeywords: [String]
    ) -> [DanmakuItem] {
        let rules = blockedKeywords.compactMap(Rule.init)
        guard !rules.isEmpty else { return items }

        return items.filter { item in
            !rules.contains { $0.matches(item.content) }
        }
    }

    struct Rule {
        let literal: String?
        let regex: NSRegularExpression?

        init?(_ raw: String) {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }

            if trimmed.count > 2, trimmed.hasPrefix("/"), trimmed.hasSuffix("/") {
                let pattern = String(trimmed.dropFirst().dropLast())
                if let regex = try? NSRegularExpression(
                    pattern: pattern,
                    options: [.caseInsensitive]
                ) {
                    self.regex = regex
                    literal = nil
                    return
                }
            }

            literal = trimmed.lowercased()
            regex = nil
        }

        func matches(_ content: String) -> Bool {
            if let regex {
                let range = NSRange(content.startIndex ..< content.endIndex, in: content)
                return regex.firstMatch(in: content, range: range) != nil
            }
            guard let literal else { return false }
            return content.lowercased().contains(literal)
        }
    }
}
