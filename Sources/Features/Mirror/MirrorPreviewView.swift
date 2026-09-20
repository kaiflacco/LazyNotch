import AVFoundation
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
        imageLayer.contentsGravity = .resizeAspectFill
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

/// Full Mirror popup overlay view with live camera feed.
public struct MirrorPreviewModal: View {
    @ObservedObject var camera = CameraManager.shared
    @Binding var isPresented: Bool

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            // Camera feed or fallback permission notice
            if camera.hasPermission {
                VideoPreviewLayerRepresentable(currentFrame: camera.currentFrame)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "video.slash.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.white.opacity(0.5))

                    Text("Camera Access Required")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(camera.errorMessage ?? "Enable camera access in System Settings.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            // Close button
            Button {
                withAnimation(LazyNotchMotion.interactiveSpring) {
                    isPresented = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.black.opacity(0.65)))
            }
            .buttonStyle(.plain)
            .padding(10)
        }
        .frame(width: 220, height: 130)
        .shadow(color: .black.opacity(0.5), radius: 16, y: 8)
        .onAppear {
            camera.start()
        }
        .onDisappear {
            camera.stop()
        }
    }
}
