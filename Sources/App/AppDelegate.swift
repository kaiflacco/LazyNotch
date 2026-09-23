import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var runtime: LazyNotchRuntime!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Pre-warm calendar and media services at startup so first-click/hover doesn't hitch
        _ = CalendarService.shared
        _ = MediaService.shared

        runtime = LazyNotchRuntime()
        runtime.start()

        NSApp.activate(ignoringOtherApps: false)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        runtime.stop()
    }
}
