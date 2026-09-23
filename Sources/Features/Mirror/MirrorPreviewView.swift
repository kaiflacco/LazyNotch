import AppKit
import SwiftUI

/// Custom AppKit view hosting AVCaptureVideoPreviewLayer with guaranteed lifecycle & mirroring control.
@MainActor
final class CameraPreviewNSView: NSView {
    let imageLayer = CALayer()
    
    var isMirrored: Bool {
        didSet {
            applyMirroring()
        }
    }
    var currentFrame: CGImage? {
        didSet {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            imageLayer.contents = currentFrame
            CATransaction.commit()
        }
    }
    
    override var isFlipped: Bool { return true }

    init(isMirrored: Bool = true) {
        self.isMirrored = isMirrored
        super.init(frame: .zero)
        wantsLayer = true
        // Keep the complete camera frame visible inside the teardrop. Aspect-fill
        // crops the preview on common 16:9 camera feeds and makes the controls feel
        // detached from the content.
        imageLayer.contentsGravity = .resizeAspect
        layer?.addSublayer(imageLayer)
        applyMirroring()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        imageLayer.frame = bounds
        CATransaction.commit()
    }

    func applyMirroring() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if isMirrored {
            imageLayer.transform = CATransform3DMakeScale(-1, 1, 1)
        } else {
            imageLayer.transform = CATransform3DIdentity
        }
        CATransaction.commit()
    }
}

/// Live mirror video layer rendered via AppKit AVCaptureVideoPreviewLayer.
struct VideoPreviewLayerRepresentable: NSViewRepresentable {
    let currentFrame: CGImage?
    var isMirrored: Bool = true

    func makeNSView(context: Context) -> CameraPreviewNSView {
        CameraPreviewNSView(isMirrored: isMirrored)
    }

    func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {
        nsView.isMirrored = isMirrored
        nsView.currentFrame = currentFrame
    }
}
