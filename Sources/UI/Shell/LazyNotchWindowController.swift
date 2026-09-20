import AppKit
import Combine
import SwiftUI

enum GlobalDragZone: Equatable {
    case tray
    case airdrop
    case none
}

/// Observable shell state shared between the AppKit controller and SwiftUI content.
@MainActor
final class ShellViewModel: ObservableObject {
    @Published var isExpanded: Bool = false
    @Published var isHovered: Bool = false
    @Published var hasActiveLiveActivity: Bool = false
    @Published var activeTab: ShellContentView.ShellTab = .home
    @Published var compactSize: CGSize = CGSize(width: 186, height: 32)
    @Published var globalDragZone: GlobalDragZone = .none
}

/// Owns the borderless NSPanel hosting the LazyNotch shell.
/// The panel maintains a stable top-anchored canvas so that 100% of the
/// notch expansion, spring physics, and shape morphing are executed natively
/// on the GPU via SwiftUI and Metal at up to 120Hz ProMotion without WindowServer IPC jitter.
@MainActor
final class LazyNotchWindowController {
    /// Fallback compact size matching physical notch if unknown.
    static let fallbackClosedSize = CGSize(width: 176, height: 34)

    /// Compact media pill hanging below the physical notch (NotchNook-style).
    static let pillWidth: CGFloat = 300
    static let pillHeight: CGFloat = 36
    /// How far the pill hangs below the visible notch surface.
    static let pillVisibleHeight: CGFloat = 30

    // MARK: - Open geometry (sleek compact notch island)

    static let openWidth: CGFloat = 598
    static let openHeight: CGFloat = 164

    // MARK: - Shadow canvas padding (prevents unclipped SwiftUI drop shadows)

    static let shadowPaddingX: CGFloat = 75
    static let shadowPaddingBottom: CGFloat = 180

    // MARK: - Hover hysteresis (cursor polling)

    static let hoverEnterGrace: TimeInterval = 0.12 // Deliberate, smooth opening response without accidental hair-trigger
    static let hoverLeaveGrace: TimeInterval = 0.22 // Comfortable departure grace
    static let cursorPollInterval: TimeInterval = 0.016 // 60Hz high-frequency cursor tracking

    private let displayCoordinator: DisplayCoordinator
    private let viewModel = ShellViewModel()
    private var panel: NSPanel!
    private var displayObserver: NSObjectProtocol?
    private var spaceObserver: NSObjectProtocol?

    private var hoverTimer: Timer?
    private var enterArmedAt: Date?
    private var leaveArmedAt: Date?
    /// While set, the island stays expanded on the Tray regardless of cursor position
    /// (used while the file picker is open / right after staging files).
    private var holdOpenUntil: Date?
    private var lastDragChangeCount: Int = NSPasteboard(name: .drag).changeCount
    private var isGlobalDragActive: Bool = false

    private var cancellables = Set<AnyCancellable>()

    init(displayCoordinator: DisplayCoordinator) {
        self.displayCoordinator = displayCoordinator
        makePanel()
        updateCompactSize()
        displayObserver = displayCoordinator.observeChanges { [weak self] in
            MainActor.assumeIsolated {
                self?.handleDisplayChange()
            }
        }
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.handleSpaceChange()
            }
        }
        MediaService.shared.$currentTrack
            .receive(on: DispatchQueue.main)
            .sink { [weak self] track in
                self?.viewModel.hasActiveLiveActivity = (track?.isPlaying == true)
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("LazyNotchCollapseRequest"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                withAnimation(LazyNotchMotion.shellSpring(isExpanded: false)) {
                    self?.viewModel.isExpanded = false
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("LazyNotchHoldOpenTrayRequest"),
            object: nil,
            queue: .main
        ) { [weak self] note in
            let seconds = (note.userInfo?["seconds"] as? Double) ?? 6
            MainActor.assumeIsolated {
                self?.holdOpenTray(seconds: seconds)
            }
        }
    }

    private func closedSize(for display: DisplayCoordinator.DisplayInfo?) -> CGSize {
        guard let display, display.hasNotch else { return CGSize(width: 200, height: 0) }
        // The hardware notch cutout width and height derived from NSScreen
        let physicalWidth = display.notchWidth
        let physicalHeight = display.notchHeight
        return CGSize(width: physicalWidth, height: physicalHeight)
    }

    private func updateCompactSize() {
        let size = closedSize(for: displayCoordinator.primaryDisplay)
        viewModel.compactSize = size
    }

    func show() {
        positionPanel()
        panel.orderFrontRegardless()
        startCursorWatcher()
    }

    // MARK: - Panel setup

    private func makePanel() {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        // screenSaver level (1000) keeps the notch above all desktop spaces, full-screen apps, and windows at all times.
        panel.level = .screenSaver
        panel.isMovable = false
        panel.ignoresMouseEvents = false
        panel.hidesOnDeactivate = false
        panel.canHide = false
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle,
        ]

        let host = ShellHostingView(rootView: ShellContentView(viewModel: viewModel))
        host.viewModel = viewModel
        host.shadowPaddingX = Self.shadowPaddingX
        host.shadowPaddingBottom = Self.shadowPaddingBottom
        host.layerContentsRedrawPolicy = .onSetNeedsDisplay
        panel.contentView = host
        panel.registerForDraggedTypes([.fileURL])
        self.panel = panel
    }

    private func positionPanel() {
        guard let display = displayCoordinator.primaryDisplay else { return }
        let frame = display.screen.frame
        let windowWidth = Self.openWidth + Self.shadowPaddingX * 2
        let windowHeight = Self.openHeight + Self.shadowPaddingBottom
        let rect = CGRect(
            x: frame.midX - windowWidth / 2,
            y: frame.maxY - windowHeight,
            width: windowWidth,
            height: windowHeight
        )
        panel.setFrame(rect, display: true)
    }

    // MARK: - Hover state machine (fully interruptible cursor tracking)

    /// The cursor zone that activates or hovers the notch. Anchored strictly to the physical notch and navbar wings.
    private func hotZoneRect() -> CGRect {
        guard let display = displayCoordinator.primaryDisplay else { return .null }
        let anchor = closedSize(for: display)
        let frame = display.screen.frame
        if viewModel.hasActiveLiveActivity {
            // Live activity is positioned in the top navbar flanking the notch
            let width: CGFloat = anchor.width + 76
            let height = anchor.height
            return CGRect(
                x: frame.midX - width / 2,
                y: frame.maxY - height,
                width: width,
                height: height
            )
        } else {
            // Idle notch: strictly within the physical notch cutout
            let width = anchor.width
            let height = anchor.height
            return CGRect(
                x: frame.midX - width / 2,
                y: frame.maxY - height,
                width: width,
                height: height
            )
        }
    }

    /// Whether the cursor is inside the region that holds the shell open.
    private func cursorIsEngaged() -> Bool {
        let mouse = NSEvent.mouseLocation
        if hotZoneRect().contains(mouse) { return true }
        guard viewModel.isExpanded, let display = displayCoordinator.primaryDisplay else { return false }
        let frame = display.screen.frame
        let contentRect = CGRect(
            x: frame.midX - Self.openWidth / 2,
            y: frame.maxY - Self.openHeight,
            width: Self.openWidth,
            height: Self.openHeight
        )
        return contentRect.insetBy(dx: -8, dy: -4).contains(mouse)
    }

    /// The exact visible screen bounds of the notch right now.
    private func activeNotchScreenRect() -> CGRect {
        guard let display = displayCoordinator.primaryDisplay else { return .null }
        let frame = display.screen.frame
        if viewModel.isExpanded {
            let width = Self.openWidth
            let height = Self.openHeight
            return CGRect(
                x: frame.midX - width / 2,
                y: frame.maxY - height,
                width: width,
                height: height
            )
        } else if viewModel.hasActiveLiveActivity {
            let width: CGFloat = viewModel.compactSize.width + 76
            let height = viewModel.compactSize.height
            return CGRect(
                x: frame.midX - width / 2,
                y: frame.maxY - height,
                width: width,
                height: height
            )
        } else {
            let width = viewModel.compactSize.width
            let height = viewModel.compactSize.height
            return CGRect(
                x: frame.midX - width / 2,
                y: frame.maxY - height,
                width: width,
                height: height
            )
        }
    }

    private func startCursorWatcher() {
        guard hoverTimer == nil else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: Self.cursorPollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.pollCursor() }
        }
        hoverTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func expandedInteractiveRect() -> CGRect? {
        guard let display = displayCoordinator.primaryDisplay else { return nil }
        let frame = display.screen.frame
        return CGRect(
            x: frame.midX - Self.openWidth / 2,
            y: frame.maxY - Self.openHeight,
            width: Self.openWidth,
            height: Self.openHeight
        )
    }

    /// Window Server–level click-through. Returning `nil` from ShellHostingView.hitTest
    /// does NOT forward clicks to windows beneath other apps — WindowServer delivers the
    /// event to the topmost window (this panel) and AppKit swallows it. The only reliable
    /// pass-through mechanism is `ignoresMouseEvents`, so we drive it from the cursor poll:
    /// accept events only over the actually-interactive notch region, pass through everywhere
    /// else (menu bar items, pixels below the notch, etc.).
    private func updateMousePassThrough() {
        let mouse = NSEvent.mouseLocation

        let interactive: Bool
        if isGlobalDragActive {
            interactive = true
        } else if viewModel.isExpanded {
            interactive = expandedInteractiveRect()?.contains(mouse) ?? false
        } else {
            interactive = hotZoneRect().contains(mouse)
        }

        panel.ignoresMouseEvents = !interactive
    }

    private func pollCursor() {
        let currentDragCount = NSPasteboard(name: .drag).changeCount
        if currentDragCount != lastDragChangeCount {
            lastDragChangeCount = currentDragCount
            if NSEvent.pressedMouseButtons != 0 {
                isGlobalDragActive = true
                if viewModel.globalDragZone == .none {
                    withAnimation(LazyNotchMotion.interactiveSpring) { viewModel.globalDragZone = .tray }
                }
            }
        }
        
        if isGlobalDragActive && NSEvent.pressedMouseButtons == 0 {
            isGlobalDragActive = false
            withAnimation(LazyNotchMotion.interactiveSpring) { viewModel.globalDragZone = .none }
        }

        let engaged = cursorIsEngaged() || isGlobalDragActive
        updateMousePassThrough()
        if viewModel.isHovered != engaged {
            withAnimation(LazyNotchMotion.hoverSpring) {
                viewModel.isHovered = engaged
            }
        }

        if engaged {
            leaveArmedAt = nil
            if !viewModel.isExpanded {
                if let armed = enterArmedAt, Date().timeIntervalSince(armed) >= Self.hoverEnterGrace {
                    expand()
                } else if enterArmedAt == nil {
                    enterArmedAt = Date()
                }
            }
        } else {
            enterArmedAt = nil
            // Hold the island open while a hold-open request is active (file picker / post-staging feedback).
            let isHeldOpen = Date() < (holdOpenUntil ?? .distantPast)
            if viewModel.isExpanded, !isHeldOpen {
                if let armed = leaveArmedAt, Date().timeIntervalSince(armed) >= Self.hoverLeaveGrace {
                    collapse()
                } else if leaveArmedAt == nil {
                    leaveArmedAt = Date()
                }
            }
        }
    }

    // MARK: - State transitions (fully interruptible, zero blocking locks)

    func expand() {
        guard !viewModel.isExpanded else { return }
        updateMousePassThrough()
        panel.orderFrontRegardless()
        withAnimation(LazyNotchMotion.shellSpring(isExpanded: true)) {
            viewModel.isExpanded = true
        }
        MirrorWindowController.shared.closeMirror()
    }

    func collapse() {
        guard viewModel.isExpanded else { return }
        // Update before the animated flag change so the cursor's current location is
        // evaluated against the outgoing (expanded) geometry.
        updateMousePassThrough()
        withAnimation(LazyNotchMotion.shellSpring(isExpanded: false)) {
            viewModel.isExpanded = false
        }
    }

    func toggle() {
        viewModel.isExpanded ? collapse() : expand()
    }

    /// Keeps the island expanded on the Tray regardless of cursor position — used while
    /// the file picker dialog is open and right after staging, so the notch is never
    /// hidden when the user needs to see (or continue adding to) the tray.
    func holdOpenTray(seconds: TimeInterval) {
        holdOpenUntil = Date().addingTimeInterval(seconds)
        enterArmedAt = nil
        leaveArmedAt = nil
        panel.orderFrontRegardless()
        withAnimation(LazyNotchMotion.shellSpring(isExpanded: true)) {
            viewModel.activeTab = .shelf
            viewModel.isExpanded = true
        }
    }

    private func handleSpaceChange() {
        positionPanel()
        panel.orderFrontRegardless()
    }

    private func handleDisplayChange() {
        updateCompactSize()
        positionPanel()
        panel.orderFrontRegardless()
    }
}
