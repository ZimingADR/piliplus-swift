import Foundation
import Testing

@testable import PiliPlus

@Suite("DanmakuDecoder")
struct DanmakuDecoderTests {
    @Test("解析 protobuf 弹幕分段：时间、模式、颜色与文本")
    func decodesSegment() throws {
        let payload = Self.segment(
            elements: [
                Self.element(
                    id: 101,
                    progressMS: 5_000,
                    mode: 1,
                    fontSize: 25,
                    color: 0xFF_FF_FF,
                    content: "前方高能"
                ),
                Self.element(
                    id: 102,
                    progressMS: 12_500,
                    mode: 5,
                    fontSize: 18,
                    color: 0xFF_00_00,
                    content: "顶部弹幕"
                ),
            ]
        )

        let items = DanmakuDecoder.items(from: payload)
        #expect(items.count == 2)

        let first = try #require(items.first)
        #expect(first.id == 101)
        #expect(first.time == 5.0)
        #expect(first.mode == .scrolling)
        #expect(first.fontScale == 25)
        #expect(first.color == 0xFF_FF_FF)
        #expect(first.content == "前方高能")

        let second = try #require(items.last)
        #expect(second.time == 12.5)
        #expect(second.mode == .top)
        #expect(second.color == 0xFF_00_00)
    }

    @Test("损坏的分段不会崩溃")
    func toleratesTruncatedData() {
        let truncated = Data([0x0A, 0x20, 0x08, 0x01])
        #expect(DanmakuDecoder.items(from: truncated).isEmpty)
    }

    @Test("未知 mode 归为 unsupported，不参与渲染")
    func marksUnknownModeUnsupported() throws {
        let payload = Self.segment(
            elements: [
                Self.element(
                    id: 1,
                    progressMS: 1_000,
                    mode: 7,
                    fontSize: 25,
                    color: 0,
                    content: "高级弹幕"
                )
            ]
        )
        let item = try #require(DanmakuDecoder.items(from: payload).first)
        #expect(item.mode == .unsupported)
        #expect(item.isRenderable == false)
    }

    // MARK: - Fixtures

    private static func segment(elements: [[UInt8]]) -> Data {
        var body: [UInt8] = []
        for element in elements {
            body.append(0x0A)
            body.append(contentsOf: varint(UInt64(element.count)))
            body.append(contentsOf: element)
        }
        return Data(body)
    }

    private static func element(
        id: Int64,
        progressMS: Int,
        mode: Int,
        fontSize: Int,
        color: UInt32,
        content: String
    ) -> [UInt8] {
        var bytes: [UInt8] = []
        bytes.append(contentsOf: [0x08])
        bytes.append(contentsOf: varint(UInt64(bitPattern: id)))
        bytes.append(contentsOf: [0x10])
        bytes.append(contentsOf: varint(UInt64(progressMS)))
        bytes.append(contentsOf: [0x18])
        bytes.append(contentsOf: varint(UInt64(mode)))
        bytes.append(contentsOf: [0x20])
        bytes.append(contentsOf: varint(UInt64(fontSize)))
        bytes.append(contentsOf: [0x28])
        bytes.append(contentsOf: varint(UInt64(color)))
        let contentBytes = Array(content.utf8)
        bytes.append(contentsOf: [0x3A])
        bytes.append(contentsOf: varint(UInt64(contentBytes.count)))
        bytes.append(contentsOf: contentBytes)
        bytes.append(contentsOf: [0x48])
        bytes.append(contentsOf: varint(5))
        return bytes
    }

    private static func varint(_ value: UInt64) -> [UInt8] {
        var value = value
        var output: [UInt8] = []
        repeat {
            var byte = UInt8(value & 0x7F)
            value >>= 7
            if value != 0 {
                byte |= 0x80
            }
            output.append(byte)
        } while value != 0
        return output
    }
}
