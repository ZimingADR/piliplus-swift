import Testing

@testable import PiliPlus

@Suite("RankFilters")
struct RankFilterTests {
    @Test("榜单分区覆盖全站与常用分区")
    func regions() {
        #expect(RankRegion.all.first?.id == 0)
        #expect(RankRegion.all.contains { $0.id == 1 && $0.title == "动画" })
        #expect(RankRegion.all.count >= 10)
    }

    @Test("榜单周期标题")
    func periods() {
        #expect(RankPeriod.allCases.count == 4)
        #expect(RankPeriod.all.title == "三日榜")
        #expect(RankPeriod.day.rawValue == "day")
        #expect(RankPeriod.month.title == "月榜")
    }
}
