/// App-scoped composition and lifecycle boundary for LazyNotch.
@MainActor
final class LazyNotchRuntime {
    let displayCoordinator: DisplayCoordinator
    let windowController: LazyNotchWindowController

    init(displayCoordinator: DisplayCoordinator = DisplayCoordinator()) {
        self.displayCoordinator = displayCoordinator
        self.windowController = LazyNotchWindowController(displayCoordinator: displayCoordinator)
    }

    func start() {
        windowController.show()
    }

    func stop() {
        windowController.stop()
        MediaService.shared.stopMonitoring()
        CodexUsageService.shared.stop()
    }
}
