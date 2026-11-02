import Foundation

/// 本地弹幕屏蔽：按关键词过滤（大小写不敏感）。
enum DanmakuFilter {
    static func apply(
        _ items: [DanmakuItem],
        blockedKeywords: [String]
    ) -> [DanmakuItem] {
        let keywords = blockedKeywords
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }

        guard !keywords.isEmpty else { return items }

        return items.filter { item in
            let text = item.content.lowercased()
            return !keywords.contains { text.contains($0) }
        }
    }
}
