import Foundation

/// 一条弹幕。
struct DanmakuItem: Identifiable, Hashable, Sendable {
    enum Mode: Int, Sendable {
        case scrolling = 1
        case bottom = 4
        case top = 5
        /// 逆向、高级、代码、BAS 弹幕在 Group 1 中不渲染。
        case unsupported = 0
    }

    let id: Int64
    /// 出现时间，单位秒。
    let time: Double
    let mode: Mode
    /// 字号的百分比（B 站标准为 18 / 25 / 36）。
    let fontScale: Int
    let color: UInt32
    let content: String
    let weight: Int

    var isRenderable: Bool {
        mode == .scrolling || mode == .bottom || mode == .top
    }
}

/// 最小化的 protobuf 读取器，只覆盖弹幕分段响应（`DmSegMobileReply`）所需能力。
struct ProtobufReader {
    enum WireType: UInt64 {
        case varint = 0
        case fixed64 = 1
        case lengthDelimited = 2
        case startGroup = 3
        case endGroup = 4
        case fixed32 = 5
    }

    private let bytes: [UInt8]
    private var index: Int

    init(_ data: Data) {
        bytes = Array(data)
        index = 0
    }

    var isAtEnd: Bool { index >= bytes.count }

    mutating func readTag() throws -> (field: Int, wire: WireType)? {
        guard !isAtEnd else { return nil }
        let raw = try readVarint()
        let field = Int(raw >> 3)
        guard let wire = WireType(rawValue: raw & 0x7) else {
            throw DanmakuDecodeError.invalidWireType(raw & 0x7)
        }
        guard field > 0 else { throw DanmakuDecodeError.invalidField }
        return (field, wire)
    }

    mutating func readVarint() throws -> UInt64 {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while index < bytes.count {
            let byte = bytes[index]
            index += 1
            result |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 {
                return result
            }
            shift += 7
            if shift >= 64 { throw DanmakuDecodeError.malformedVarint }
        }
        throw DanmakuDecodeError.unexpectedEnd
    }

    mutating func readBytes() throws -> [UInt8] {
        let length = Int(try readVarint())
        guard length >= 0, index + length <= bytes.count else {
            throw DanmakuDecodeError.unexpectedEnd
        }
        let slice = bytes[index ..< index + length]
        index += length
        return Array(slice)
    }

    mutating func skip(_ wire: WireType) throws {
        switch wire {
        case .varint:
            _ = try readVarint()
        case .fixed64:
            guard index + 8 <= bytes.count else { throw DanmakuDecodeError.unexpectedEnd }
            index += 8
        case .lengthDelimited:
            _ = try readBytes()
        case .fixed32:
            guard index + 4 <= bytes.count else { throw DanmakuDecodeError.unexpectedEnd }
            index += 4
        case .startGroup, .endGroup:
            throw DanmakuDecodeError.unsupportedGroup
        }
    }
}

enum DanmakuDecodeError: Error, Equatable {
    case unexpectedEnd
    case malformedVarint
    case invalidField
    case invalidWireType(UInt64)
    case unsupportedGroup
}

/// 解析 `DmSegMobileReply`：
/// ```proto
/// message DmSegMobileReply { repeated DanmakuElem elems = 1; }
/// message DanmakuElem {
///   int64 id = 1; int32 progress = 2; int32 mode = 3; int32 fontsize = 4;
///   uint32 color = 5; string midHash = 6; string content = 7; int64 ctime = 8;
///   int32 weight = 9; int32 pool = 12; string idStr = 13; int32 attr = 14;
/// }
/// ```
enum DanmakuDecoder {
    static func items(from data: Data) -> [DanmakuItem] {
        var reader = ProtobufReader(data)
        var items: [DanmakuItem] = []
        do {
            while let tag = try reader.readTag() {
                if tag.field == 1, tag.wire == .lengthDelimited {
                    let message = try reader.readBytes()
                    if let item = parseElement(message) {
                        items.append(item)
                    }
                } else {
                    try reader.skip(tag.wire)
                }
            }
        } catch {
            // 单条数据损坏时保留已解析出的内容，避免整段弹幕丢失。
        }
        return items.sorted { $0.time < $1.time }
    }

    private static func parseElement(_ bytes: [UInt8]) -> DanmakuItem? {
        var reader = ProtobufReader(Data(bytes))
        var identifier: Int64 = 0
        var progressMS: UInt64 = 0
        var modeRaw: UInt64 = 1
        var fontSize: UInt64 = 25
        var color: UInt64 = 0xFFFFFF
        var content = ""
        var weight: UInt64 = 5

        do {
            while let tag = try reader.readTag() {
                switch (tag.field, tag.wire) {
                case (1, .varint):
                    identifier = Int64(bitPattern: try reader.readVarint())
                case (2, .varint):
                    progressMS = try reader.readVarint()
                case (3, .varint):
                    modeRaw = try reader.readVarint()
                case (4, .varint):
                    fontSize = try reader.readVarint()
                case (5, .varint):
                    color = try reader.readVarint()
                case (7, .lengthDelimited):
                    content = String(decoding: try reader.readBytes(), as: UTF8.self)
                case (9, .varint):
                    weight = try reader.readVarint()
                default:
                    try reader.skip(tag.wire)
                }
            }
        } catch {
            return nil
        }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        return DanmakuItem(
            id: identifier,
            time: Double(progressMS) / 1000,
            mode: DanmakuItem.Mode(rawValue: Int(modeRaw)) ?? .unsupported,
            fontScale: Int(fontSize),
            color: UInt32(truncatingIfNeeded: color),
            content: trimmed,
            weight: Int(weight)
        )
    }
}
