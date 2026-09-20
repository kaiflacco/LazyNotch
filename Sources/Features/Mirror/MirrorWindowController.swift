import AppKit
import SwiftUI

@MainActor
public final class MirrorWindowController: NSObject, NSWindowDelegate {
    public static let shared = MirrorWindowController()
    private var window: NSPanel?
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?

    public static let mirrorWidth: CGFloat = 380
    public static let mirrorHeight: CGFloat = 285

    public var isVisible: Bool {
        window?.isVisible ?? false
    }

    public func toggleMirror() {
        if isVisible {
            closeMirror()
        } else {
            showMirror()
        }
    }

    public func showMirror() {
        if let window = window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = screen.frame

        // Notch height (typically ~32-34 pt on Apple Silicon, or 25 pt menu bar)
        let notchHeight: CGFloat = screen.safeAreaInsets.top > 0 ? screen.safeAreaInsets.top : 25
        let notchBottomY = screenFrame.maxY - notchHeight

        // Panel is larger than the visible shape (shadow padding) so the drop shadow
        // isn't clipped; offset the frame so the pointer tip still touches the notch.
        let winWidth = HandMirrorView.mirrorWindowWidth
        let winHeight = HandMirrorView.mirrorWindowHeight
        let winX = screenFrame.midX - winWidth / 2
        let winY = notchBottomY - winHeight + HandMirrorView.shadowPadding

        let contentRect = NSRect(x: winX, y: winY, width: winWidth, height: winHeight)

        let isPresentedBinding = Binding<Bool>(
            get: { [weak self] in self?.window?.isVisible ?? false },
            set: { [weak self] newValue in
                if !newValue {
                    self?.closeMirror()
                }
            }
        )

        let mirrorView = HandMirrorView(isPresented: isPresentedBinding)
        let hostingView = NSHostingView(rootView: mirrorView)

        let panel = NSPanel(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        // Native WindowServer shadow: derived from the window's opaque alpha region
        // (the teardrop-clipped camera feed) and drawn OUTSIDE the frame, so it can
        // never be clipped by the window bounds the way a SwiftUI .shadow would.
        panel.hasShadow = true
        panel.level = NSWindow.Level(Int(CGWindowLevelForKey(.screenSaverWindow)) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = hostingView
        panel.isReleasedWhenClosed = false
        panel.delegate = self

        self.window = panel
        panel.orderFrontRegardless()

        // Dismiss on click outside
        startDismissMonitors()
    }

    public func closeMirror() {
        stopDismissMonitors()
        window?.orderOut(nil)
        window = nil
        CameraManager.shared.stop()
        CameraManager.shared.currentEffect = .normal
    }

    private func startDismissMonitors() {
        stopDismissMonitors()

        // Close on ESC
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC
                self?.closeMirror()
                return nil
            }
            return event
        }

        // Close when clicking outside window
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, let window = self.window, window.isVisible else { return }
            let mouseLoc = NSEvent.mouseLocation
            if !window.frame.contains(mouseLoc) {
                self.closeMirror()
            }
        }
    }

    private func stopDismissMonitors() {
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
    }

    public func windowWillClose(_ notification: Notification) {
        closeMirror()
    }
}
