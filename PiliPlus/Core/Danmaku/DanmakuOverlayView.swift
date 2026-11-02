import QuartzCore
import SwiftUI
import UIKit

/// CoreAnimation 弹幕层。
///
/// 每条弹幕是一个 `CATextLayer` + 一条线性位移动画：渲染由 CoreAnimation 在
/// 渲染服务器上完成，SwiftUI 每次状态刷新（约 5Hz）只负责「投放」新弹幕，
/// 因此滚动平滑度与刷新率解耦，120Hz 设备上也不会掉帧。
struct DanmakuOverlayView: UIViewRepresentable {
    let items: [DanmakuItem]
    let currentTime: Double
    let isPlaying: Bool
    let isEnabled: Bool
    let fontScale: Double
    let opacity: Double
    let speed: Double
    let area: Double

    func makeUIView(context: Context) -> DanmakuCanvasView {
        DanmakuCanvasView()
    }

    func updateUIView(_ view: DanmakuCanvasView, context: Context) {
        view.apply(
            items: items,
            time: currentTime,
            isPlaying: isPlaying,
            isEnabled: isEnabled,
            fontScale: fontScale,
            opacity: opacity,
            speed: speed,
            area: area
        )
    }
}

final class DanmakuCanvasView: UIView {
    private struct Lane {
        var availableAt: Double = 0
    }

    private var items: [DanmakuItem] = []
    private var itemSignature: String = ""
    private var nextIndex = 0
    private var lastTime: Double = 0
    private var scrollLanes: [Lane] = []
    private var topLanes: [Double] = []
    private var bottomLanes: [Double] = []
    private var isPausedState = false
    private var pausedTime: CFTimeInterval = 0
    private var activeLayerCount = 0
    private let maximumActiveLayers = 220

    private var fontScale: Double = 1
    private var speed: Double = 1
    private var area: Double = 0.5

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        layer.masksToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        rebuildLanesIfNeeded()
    }

    func apply(
        items: [DanmakuItem],
        time: Double,
        isPlaying: Bool,
        isEnabled: Bool,
        fontScale: Double,
        opacity: Double,
        speed: Double,
        area: Double
    ) {
        self.fontScale = fontScale
        self.speed = max(speed, 0.25)
        self.area = min(max(area, 0.2), 1)
        layer.opacity = Float(min(max(opacity, 0.1), 1))

        guard isEnabled else {
            if !items.isEmpty || itemSignature.isEmpty {
                clearAll()
            }
            self.items = items
            itemSignature = Self.signature(items)
            return
        }

        let signature = Self.signature(items)
        if signature != itemSignature {
            itemSignature = signature
            self.items = items
            resetCursor(for: time)
        } else {
            self.items = items
        }

        rebuildLanesIfNeeded()
        setPaused(!isPlaying)

        if abs(time - lastTime) > 1.5 || time < lastTime - 0.5 {
            // 发生 seek：清理旧弹幕并从新位置重新投放。
            clearAllLayers()
            resetCursor(for: time)
        }
        lastTime = time

        dispatchUpcoming(at: time)
        pruneLayersIfNeeded()
    }

    // MARK: - 投放

    private func dispatchUpcoming(at time: Double) {
        guard !items.isEmpty else { return }
        let window = time + 0.2
        var spawned = 0

        while nextIndex < items.count, items[nextIndex].time <= window {
            let item = items[nextIndex]
            nextIndex += 1
            guard item.isRenderable, item.time >= time - 2.5 else { continue }
            guard activeLayerCount < maximumActiveLayers else { continue }
            spawn(item)
            spawned += 1
            if spawned > 80 { break }
        }
    }

    private func spawn(_ item: DanmakuItem) {
        let fontSize = max(11, 17 * fontScale)
        let lineHeight = fontSize * 1.35
        let textWidth = measure(item.content, fontSize: fontSize) + 6
        guard textWidth > 0, bounds.height > lineHeight else { return }

        let textLayer = CATextLayer()
        textLayer.contentsScale = UIScreen.main.scale
        textLayer.string = item.content
        textLayer.font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        textLayer.fontSize = fontSize
        textLayer.foregroundColor = Self.color(for: item.color).cgColor
        textLayer.alignmentMode = .left
        textLayer.isWrapped = false
        textLayer.truncationMode = .none
        textLayer.anchorPoint = CGPoint(x: 0, y: 0)
        textLayer.bounds = CGRect(x: 0, y: 0, width: textWidth, height: lineHeight)
        textLayer.shadowColor = UIColor.black.cgColor
        textLayer.shadowOpacity = 0.75
        textLayer.shadowRadius = 1.2
        textLayer.shadowOffset = .zero

        switch item.mode {
        case .scrolling:
            guard let y = allocateScrollLane(lineHeight: lineHeight, at: item.time) else { return }
            let startX = bounds.width + textWidth
            let endX = -textWidth
            textLayer.position = CGPoint(x: startX, y: y)
            layer.addSublayer(textLayer)
            let distance = startX - endX
            let duration = max(4.5, distance / (bounds.width / 7.5 * max(speed, 0.25)))
            let animation = CABasicAnimation(keyPath: "position.x")
            animation.fromValue = startX
            animation.toValue = endX
            animation.duration = duration
            animation.timingFunction = CAMediaTimingFunction(name: .linear)
            animation.isRemovedOnCompletion = false
            textLayer.add(animation, forKey: "scroll")
            activeLayerCount += 1
            scheduleRemoval(textLayer, after: duration + 0.2)
        case .top, .bottom:
            guard let y = allocateStaticLane(lineHeight: lineHeight, isTop: item.mode == .top, at: item.time) else {
                return
            }
            textLayer.position = CGPoint(x: bounds.width / 2 - textWidth / 2, y: y)
            layer.addSublayer(textLayer)
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = 1
            animation.toValue = 1
            animation.duration = 4
            animation.isRemovedOnCompletion = false
            textLayer.add(animation, forKey: "static")
            activeLayerCount += 1
            scheduleRemoval(textLayer, after: 4.2)
        case .unsupported:
            return
        }
    }

    // MARK: - 轨道

    private func rebuildLanesIfNeeded() {
        let lineHeight = max(16, 17 * fontScale * 1.35)
        let usableHeight = bounds.height * area
        let laneCount = max(1, min(Int(usableHeight / lineHeight), 24))
        if scrollLanes.count != laneCount {
            scrollLanes = Array(repeating: Lane(), count: laneCount)
            topLanes = Array(repeating: 0, count: max(1, laneCount / 2))
            bottomLanes = Array(repeating: 0, count: max(1, laneCount / 2))
        }
    }

    private func allocateScrollLane(lineHeight: CGFloat, at time: Double) -> CGFloat? {
        guard !scrollLanes.isEmpty else { return nil }
        var bestIndex: Int?
        var bestAvailable = Double.infinity
        for (index, lane) in scrollLanes.enumerated() where lane.availableAt <= time {
            if lane.availableAt < bestAvailable {
                bestAvailable = lane.availableAt
                bestIndex = index
            }
        }
        guard let index = bestIndex else { return nil }
        scrollLanes[index].availableAt = time + 1.2 / max(speed, 0.25)
        return (CGFloat(index) + 0.5) * lineHeight
    }

    private func allocateStaticLane(lineHeight: CGFloat, isTop: Bool, at time: Double) -> CGFloat? {
        var lanes = isTop ? topLanes : bottomLanes
        guard !lanes.isEmpty else { return nil }
        guard let index = lanes.firstIndex(where: { $0 <= time }) ?? lanes.indices.min(by: { lanes[$0] < lanes[$1] }) else {
            return nil
        }
        lanes[index] = time + 4
        if isTop {
            topLanes = lanes
        } else {
            bottomLanes = lanes
        }

        if isTop {
            return (CGFloat(index) + 0.5) * lineHeight + bounds.height * (1 - area) / 2
        }
        return bounds.height - (CGFloat(index) + 0.5) * lineHeight - bounds.height * (1 - area) / 2
    }

    // MARK: - 暂停 / 清理

    private func setPaused(_ paused: Bool) {
        guard paused != isPausedState else { return }
        isPausedState = paused
        if paused {
            pausedTime = layer.convertTime(CACurrentMediaTime(), from: nil)
            layer.speed = 0
            layer.timeOffset = pausedTime
        } else {
            layer.speed = 1
            layer.timeOffset = 0
            layer.beginTime = 0
            let now = layer.convertTime(CACurrentMediaTime(), from: nil)
            layer.beginTime = now - pausedTime
        }
    }

    private func resetCursor(for time: Double) {
        nextIndex = lowerBound(time: time)
        lastTime = time
        rebuildLanesIfNeeded()
        scrollLanes = Array(repeating: Lane(), count: max(scrollLanes.count, 1))
        topLanes = Array(repeating: 0, count: max(topLanes.count, 1))
        bottomLanes = Array(repeating: 0, count: max(bottomLanes.count, 1))
    }

    private func lowerBound(time: Double) -> Int {
        var low = 0
        var high = items.count
        while low < high {
            let mid = (low + high) / 2
            if items[mid].time < time - 0.5 {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low
    }

    private func pruneLayersIfNeeded() {
        guard activeLayerCount > maximumActiveLayers / 2 else { return }
        // 防御性清理：正常路径由 scheduleRemoval 精确回收。
        let excess = activeLayerCount - maximumActiveLayers / 2
        guard excess > 0, let sublayers = layer.sublayers else { return }
        for sublayer in sublayers.prefix(excess) {
            sublayer.removeFromSuperlayer()
            activeLayerCount -= 1
        }
    }

    private func scheduleRemoval(_ textLayer: CATextLayer, after seconds: TimeInterval) {
        Task { @MainActor [weak self, weak textLayer] in
            try? await Task.sleep(for: .seconds(seconds))
            guard let self, let textLayer, textLayer.superlayer === self.layer else { return }
            textLayer.removeFromSuperlayer()
            self.activeLayerCount = max(0, self.activeLayerCount - 1)
        }
    }

    private func clearAllLayers() {
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        activeLayerCount = 0
    }

    private func clearAll() {
        clearAllLayers()
        nextIndex = 0
        scrollLanes = []
    }

    // MARK: - 工具

    private static func signature(_ items: [DanmakuItem]) -> String {
        guard let first = items.first, let last = items.last else { return "empty" }
        return "\(items.count)-\(first.id)-\(last.id)"
    }

    private func measure(_ text: String, fontSize: CGFloat) -> CGFloat {
        let font = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        return (text as NSString).size(withAttributes: [.font: font]).width
    }

    private static func color(for rgb: UInt32) -> UIColor {
        let red = CGFloat((rgb >> 16) & 0xFF) / 255
        let green = CGFloat((rgb >> 8) & 0xFF) / 255
        let blue = CGFloat(rgb & 0xFF) / 255
        // 纯黑弹幕在暗色画面上不可读，统一提亮为白色。
        if red < 0.08, green < 0.08, blue < 0.08 {
            return .white
        }
        return UIColor(red: red, green: green, blue: blue, alpha: 1)
    }
}
