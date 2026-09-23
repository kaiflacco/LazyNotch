import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var displayCoordinator: DisplayCoordinator!
    private var windowController: LazyNotchWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Pre-warm calendar and media services at startup so first-click/hover doesn't hitch
        _ = CalendarService.shared
        _ = MediaService.shared

        displayCoordinator = DisplayCoordinator()
        windowController = LazyNotchWindowController(displayCoordinator: displayCoordinator)
        windowController.show()

        NSApp.activate(ignoringOtherApps: false)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
