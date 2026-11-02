import QuartzCore
import SwiftUI
import UIKit

/// SwiftUI ↔ CAMetalLayer 的桥接视图。
struct MPVSurfaceView: UIViewRepresentable {
    let onLayerReady: @MainActor (CAMetalLayer) -> Void

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        let layer = view.metalLayer
        Task { @MainActor in
            onLayerReady(layer)
        }
        return view
    }

    func updateUIView(_ uiView: PlayerLayerView, context: Context) {}
}

final class PlayerLayerView: UIView {
    override class var layerClass: AnyClass { CAMetalLayer.self }

    var metalLayer: CAMetalLayer {
        guard let layer = layer as? CAMetalLayer else {
            fatalError("PlayerLayerView 的 backing layer 必须是 CAMetalLayer")
        }
        return layer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
