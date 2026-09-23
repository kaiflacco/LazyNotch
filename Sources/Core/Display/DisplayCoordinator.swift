import AppKit

/// Enumerates screens, computes notch/safe-area geometry, and reports
/// the anchor point where the LazyNotch shell should live.
@MainActor
final class DisplayCoordinator {
    struct DisplayInfo {
        let screen: NSScreen
        let hasNotch: Bool
        /// Safe area insets (top) for the screen.
        let notchHeight: CGFloat
        /// Exact hardware notch width, derived from the auxiliary menu-bar areas.
        let notchWidth: CGFloat
    }

    var displays: [DisplayInfo] {
        NSScreen.screens.map(makeDisplayInfo)
    }

    /// The display the shell currently anchors to (built-in notch display preferred).
    var primaryDisplay: DisplayInfo? {
        let all = displays
        return all.first { $0.hasNotch } ?? all.first
    }

    private func makeDisplayInfo(_ screen: NSScreen) -> DisplayInfo {
        let frame = screen.frame
        let safeArea = screen.safeAreaInsets
        let hasNotch = safeArea.top > 0

        // Derive the exact notch width from the auxiliary menu-bar areas
        // (public API). The notch is the gap between them at the top.
        var notchWidth: CGFloat = 200
        if let topLeft = screen.auxiliaryTopLeftArea, let topRight = screen.auxiliaryTopRightArea {
            notchWidth = frame.width - topLeft.width - topRight.width
        }

        return DisplayInfo(
            screen: screen,
            hasNotch: hasNotch,
            notchHeight: safeArea.top,
            notchWidth: max(notchWidth, 0)
        )
    }

    /// React to display changes (connect/disconnect, resolution, sleep/wake).
    ///
    /// NOTE: `NSApplication.didChangeScreenParametersNotification` is posted to the
    /// app's DEFAULT notification center — not `NSWorkspace.shared.notificationCenter`.
    /// Observing it on the workspace center silently never fires, which previously
    /// left the shell stuck at stale geometry after display changes.
    func observeChanges(_ handler: @escaping @Sendable () -> Void) -> NSObjectProtocol {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { _ in handler() }
    }
}
