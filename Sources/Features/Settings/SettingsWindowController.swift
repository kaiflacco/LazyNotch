import AppKit
import SwiftUI

final class SettingsPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
public final class SettingsWindowController: NSObject, NSWindowDelegate {
    public static let shared = SettingsWindowController()
    private var window: SettingsPanel?
    private var escEventMonitor: Any?

    public func showSettings() {
        if let window = window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let isPresentedBinding = Binding<Bool>(
            get: { [weak self] in self?.window?.isVisible ?? false },
            set: { [weak self] newValue in
                if !newValue {
                    self?.closeSettings()
                }
            }
        )

        let settingsView = SettingsSheet(isPresented: isPresentedBinding)
        let hostingView = NSHostingView(rootView: settingsView)

        let win = SettingsPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 420),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        win.isMovableByWindowBackground = true
        win.backgroundColor = .clear
        win.isOpaque = false
        win.hasShadow = false // Shadow is rendered inside SwiftUI SettingsSheet
        win.level = NSWindow.Level(Int(CGWindowLevelForKey(.screenSaverWindow)) + 1)
        win.center()
        win.contentView = hostingView
        win.isReleasedWhenClosed = false
        win.delegate = self

        // Explicitly hide any OS traffic light buttons if instantiated by AppKit
        win.standardWindowButton(.closeButton)?.isHidden = true
        win.standardWindowButton(.miniaturizeButton)?.isHidden = true
        win.standardWindowButton(.zoomButton)?.isHidden = true

        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        startEscMonitor()
    }

    public func closeSettings() {
        stopEscMonitor()
        window?.close()
        window = nil
    }

    public func windowWillClose(_ notification: Notification) {
        stopEscMonitor()
        window = nil
    }

    private func startEscMonitor() {
        stopEscMonitor()
        escEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // ESC key
                self?.closeSettings()
                return nil
            }
            return event
        }
    }

    private func stopEscMonitor() {
        if let monitor = escEventMonitor {
            NSEvent.removeMonitor(monitor)
            escEventMonitor = nil
        }
    }
}

