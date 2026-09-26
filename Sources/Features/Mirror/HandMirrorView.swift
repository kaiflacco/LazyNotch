import AVFoundation
import AppKit
import SwiftUI

/// Teardrop/beak pointer shape pointing upwards to the physical Mac notch.
public struct HandMirrorPointerShape: Shape {
    public var cornerRadius: CGFloat = 30
    public var pointerWidth: CGFloat = 24
    public var pointerHeight: CGFloat = 12

    public init(cornerRadius: CGFloat = 30, pointerWidth: CGFloat = 24, pointerHeight: CGFloat = 12) {
        self.cornerRadius = cornerRadius
        self.pointerWidth = pointerWidth
        self.pointerHeight = pointerHeight
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let top = rect.minY + pointerHeight
        let bottom = rect.maxY
        let left = rect.minX
        let right = rect.maxX
        let midX = rect.midX

        // Start below top-left corner
        path.move(to: CGPoint(x: left, y: top + cornerRadius))

        // Top-left corner arc
        path.addArc(
            center: CGPoint(x: left + cornerRadius, y: top + cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )

        // Line to pointer left base
        path.addLine(to: CGPoint(x: midX - pointerWidth / 2, y: top))

        // Pointer tip pointing directly up to the physical notch camera
        path.addLine(to: CGPoint(x: midX, y: rect.minY))
        path.addLine(to: CGPoint(x: midX + pointerWidth / 2, y: top))

        // Line to top-right corner
        path.addLine(to: CGPoint(x: right - cornerRadius, y: top))

        // Top-right corner arc
        path.addArc(
            center: CGPoint(x: right - cornerRadius, y: top + cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(270),
            endAngle: .degrees(0),
            clockwise: false
        )

        // Bottom-right corner arc
        path.addArc(
            center: CGPoint(x: right - cornerRadius, y: bottom - cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )

        // Bottom-left corner arc
        path.addArc(
            center: CGPoint(x: left + cornerRadius, y: bottom - cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )

        path.closeSubpath()
        return path
    }
}

public struct HandMirrorView: View {
    @ObservedObject var camera = CameraManager.shared
    @Binding var isPresented: Bool
    @AppStorage("camera_is_mirrored") private var isMirrored: Bool = true
    @State private var isFlipHovered = false
    @State private var isFilterHovered = false

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    private func iconFor(effect: MirrorEffect) -> String {
        switch effect {
        case .normal: return "camera.filters"
        case .lovestruck: return "heart.fill"
        case .dizzy: return "sparkles"
        case .money: return "banknote.fill"
        }
    }

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            // Background fill and camera feed
            ZStack {
                Color.black

                cameraContent
            }
            .clipShape(HandMirrorPointerShape())

            // Top-right action buttons (Flip / Mirror Toggle & Close)
            HStack(spacing: 8) {
                Menu {
                    Section("LazyNotch Filters") {
                        Picker(selection: $camera.currentEffect, label: EmptyView()) {
                            ForEach(MirrorEffect.allCases) { effect in
                                Label(effect.rawValue, systemImage: iconFor(effect: effect))
                                    .tag(effect)
                            }
                        }
                        .pickerStyle(.inline)
                    }
                } label: {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(isFilterHovered ? 1.0 : 0.8))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.black.opacity(isFilterHovered ? 0.75 : 0.55)))
                        .scaleEffect(isFilterHovered ? 1.06 : 1.0)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 26, height: 26)
                .help("Select photo booth filters")
                .onHover { hovering in
                    withAnimation(LazyNotchMotion.interactiveSpring) {
                        isFilterHovered = hovering
                    }
                }
                
                Button {
                    withAnimation(LazyNotchMotion.interactiveSpring) {
                        isMirrored.toggle()
                    }
                } label: {
                    Image(systemName: isMirrored ? "arrow.left.and.right.righttriangle.left.righttriangle.right.fill" : "arrow.left.and.right.righttriangle.left.righttriangle.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(isFlipHovered ? 1.0 : 0.8))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.black.opacity(isFlipHovered ? 0.75 : 0.55)))
                        .scaleEffect(isFlipHovered ? 1.06 : 1.0)
                }
                .buttonStyle(.plain)
                .help(isMirrored ? "Switch to natural (unmirrored) camera view" : "Switch to mirror reflection")
                .onHover { hovering in
                    withAnimation(LazyNotchMotion.interactiveSpring) {
                        isFlipHovered = hovering
                    }
                }
            }
            .padding(.trailing, 16)
            .padding(.top, 22)
        }
        .frame(width: Self.mirrorWidth, height: Self.mirrorHeight)
        // No SwiftUI .shadow: it is a layer filter inside the window and gets clipped
        // at the layer bounds (and misbehaves over the embedded AVCapture layer).
        // MirrorWindowController enables the native WindowServer shadow instead — it is
        // drawn OUTSIDE the window frame, follows the teardrop's alpha shape, and can
        // never crop. Padding here only keeps the window frame from sitting under the
        // notch so the shape has breathing room and stays fully on screen.
        .padding(.top, Self.shadowPadding)
        .padding(.horizontal, Self.shadowPadding)
        .padding(.bottom, Self.shadowPadding)
        .frame(width: Self.mirrorWindowWidth, height: Self.mirrorWindowHeight)
        .onAppear {
            camera.start()
        }
        .onDisappear {
            camera.stop()
        }
    }

    @ViewBuilder
    private var cameraContent: some View {
        switch camera.availability {
        case .ready where camera.isRunning && camera.currentFrame != nil:
            VideoPreviewLayerRepresentable(currentFrame: camera.currentFrame, isMirrored: isMirrored)
        case .ready:
            statusContent(
                icon: "video.fill",
                title: "Starting Hand Mirror",
                message: "Waiting for the first camera frame…"
            )
        case .starting:
            statusContent(
                icon: "video.fill",
                title: "Starting Hand Mirror",
                message: "Preparing your camera preview…"
            )
        case .permissionRequired:
            statusContent(
                icon: "video.slash.fill",
                title: "Camera Access Required",
                message: "Allow camera access to use Hand Mirror.",
                actionTitle: "Request Camera Access",
                action: { camera.requestAccess() }
            )
        case .permissionDenied:
            statusContent(
                icon: "video.slash.fill",
                title: "Camera Access Denied",
                message: "Enable camera access in System Settings > Privacy & Security > Camera.",
                actionTitle: "Open System Settings",
                action: camera.openSettings
            )
        case .unavailable(let message):
            statusContent(
                icon: "exclamationmark.triangle.fill",
                title: "Hand Mirror Unavailable",
                message: message,
                actionTitle: "Retry",
                action: camera.start
            )
        }
    }

    private func statusContent(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(.white.opacity(0.6))

            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(.top, 12)
    }

    /// Small breathing margin between the window frame and the visible shape.
    /// The shadow itself is rendered natively by WindowServer outside the frame.
    public static let shadowPadding: CGFloat = 16
    public static let mirrorWidth: CGFloat = 380
    public static let mirrorHeight: CGFloat = 285
    public static let mirrorWindowWidth: CGFloat = mirrorWidth + shadowPadding * 2
    public static let mirrorWindowHeight: CGFloat = mirrorHeight + shadowPadding * 2
}
