import AppKit
import Combine
import SwiftUI

private final class LazyNotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Observable shell state shared between the AppKit controller and SwiftUI content.
@MainActor
final class ShellViewModel: ObservableObject {
    @Published var isExpanded: Bool = false
    @Published var isHovered: Bool = false
    @Published var hasActiveLiveActivity: Bool = false
    @Published var codexUsage: CodexUsage?
    @Published var codexIcon: NSImage?
    @Published var codexAccentColor: NSColor = .systemBlue
    @Published var codexHostName: String?
    @Published var showsCodexLiveActivity = false
    @Published var showsCodexDetails = false
    @Published var isMediaCoverHovered = false
    @Published var activeTab: ShellContentView.ShellTab = .home
    @Published var compactSize: CGSize = CGSize(width: 186, height: 32)

    func openHome() {
        isMediaCoverHovered = false
        activeTab = .home
        showsCodexDetails = false
        isExpanded = true
    }

    func openShelf() {
        isMediaCoverHovered = false
        activeTab = .shelf
        showsCodexDetails = false
        isExpanded = true
    }

    func close() {
        isMediaCoverHovered = false
        showsCodexDetails = false
        isExpanded = false
    }

    func toggleCodexDetails() {
        activeTab = .home
        showsCodexDetails.toggle()
    }

    var isActivityContentVisible: Bool {
        hasActiveLiveActivity
    }
}

/// Owns the borderless NSPanel hosting the LazyNotch shell.
/// The panel maintains a stable top-anchored canvas so that 100% of the
/// notch expansion, spring physics, and shape morphing are executed natively
/// on the GPU via SwiftUI and Metal at up to 120Hz ProMotion without WindowServer IPC jitter.
@MainActor
final class LazyNotchWindowController {
    // MARK: - Open geometry (sleek compact notch island)

    static let openWidth: CGFloat = 620
    static let openHeight: CGFloat = 180

    // MARK: - Shadow canvas padding (prevents unclipped SwiftUI drop shadows)

    static let shadowPaddingX: CGFloat = 75
    static let shadowPaddingBottom: CGFloat = 180

    // MARK: - Hover hysteresis (cursor polling)

    static let hoverEnterGrace: TimeInterval = 0.08 // Snappy, deliberate response without accidental hair-trigger
    static let hoverLeaveGrace: TimeInterval = 0.15 // Matches the Settings default
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
    private var isSystemDragInProgress: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private var notificationObservers: [NSObjectProtocol] = []

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
        let updateLiveActivity = { [weak self] in
            let showLiveMedia = UserDefaults.standard.object(forKey: "showLiveMediaActivity") as? Bool ?? true
            let showCodexUsage = UserDefaults.standard.object(forKey: "showCodexUsage") as? Bool ?? true
            let isPlaying = MediaService.shared.currentTrack?.isPlaying == true
            let codexUsage = CodexUsageService.shared.usage
            let codingAppIsActive = CodexUsageService.shared.hostIsActive
            let showCodexLiveActivity = showCodexUsage && codexUsage != nil && codingAppIsActive
            self?.viewModel.codexUsage = showCodexUsage ? codexUsage : nil
            self?.viewModel.showsCodexLiveActivity = showCodexLiveActivity
            if showCodexLiveActivity || !isPlaying {
                self?.viewModel.isMediaCoverHovered = false
            }
            if !showCodexUsage {
                self?.viewModel.showsCodexDetails = false
            }
            self?.viewModel.codexIcon = CodexUsageService.shared.codexIcon
            self?.viewModel.codexAccentColor = CodexUsageService.shared.codexAccentColor
            if let activeHostName = CodexUsageService.shared.activeHostName {
                self?.viewModel.codexHostName = activeHostName
            } else if self?.viewModel.codexHostName == nil {
                self?.viewModel.codexHostName = "Codex"
            }
            self?.viewModel.hasActiveLiveActivity = showCodexLiveActivity || (showLiveMedia && isPlaying && !codingAppIsActive)
        }

        MediaService.shared.$currentTrack
            .receive(on: DispatchQueue.main)
            .sink { _ in
                updateLiveActivity()
            }
            .store(in: &cancellables)

        CodexUsageService.shared.$usage
            .receive(on: DispatchQueue.main)
            .sink { _ in
                updateLiveActivity()
            }
            .store(in: &cancellables)

        CodexUsageService.shared.$hostIsActive
            .receive(on: DispatchQueue.main)
            .sink { _ in
                updateLiveActivity()
            }
            .store(in: &cancellables)

        CodexUsageService.shared.$activeHostBundleIdentifier
            .receive(on: DispatchQueue.main)
            .sink { _ in
                updateLiveActivity()
            }
            .store(in: &cancellables)

        CodexUsageService.shared.start()

        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                updateLiveActivity()
            }
            .store(in: &cancellables)

        let collapseObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("LazyNotchCollapseRequest"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                withAnimation(LazyNotchMotion.shellSpring(isExpanded: false)) {
                    self?.viewModel.close()
                }
            }
        }
        notificationObservers.append(collapseObserver)

        let holdOpenObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("LazyNotchHoldOpenTrayRequest"),
            object: nil,
            queue: .main
        ) { [weak self] note in
            let seconds = (note.userInfo?["seconds"] as? Double) ?? 6
            MainActor.assumeIsolated {
                self?.holdOpenTray(seconds: seconds)
            }
        }
        notificationObservers.append(holdOpenObserver)
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

    func stop() {
        hoverTimer?.invalidate()
        hoverTimer = nil
        if let displayObserver {
            NotificationCenter.default.removeObserver(displayObserver)
            self.displayObserver = nil
        }
        if let spaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(spaceObserver)
            self.spaceObserver = nil
        }
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
        notificationObservers.removeAll()
        cancellables.removeAll()
        panel.orderOut(nil)
    }

    // MARK: - Panel setup

    private func makePanel() {
        let panel = LazyNotchPanel(
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
        if viewModel.isMediaCoverHovered {
            let width: CGFloat = anchor.width + 104
            let height: CGFloat = anchor.height + 40
            return CGRect(
                x: frame.midX - width / 2,
                y: frame.maxY - height,
                width: width,
                height: height + 10
            )
        }
        if viewModel.isActivityContentVisible {
            // Live activity is positioned in the top navbar flanking the notch:
            // 42pt wings on each side + 10pt droop + comfortable padding for fast cursor sweeps
            let width: CGFloat = anchor.width + 104
            let height: CGFloat = anchor.height + 16
            return CGRect(
                x: frame.midX - width / 2,
                y: frame.maxY - height,
                width: width,
                height: height + 10
            )
        } else {
            // Idle notch: physical notch cutout with generous horizontal buffer and ceiling buffer
            let width: CGFloat = anchor.width + 24
            let height: CGFloat = anchor.height + 8
            return CGRect(
                x: frame.midX - width / 2,
                y: frame.maxY - height,
                width: width,
                height: height + 10
            )
        }
    }

    private func compactMediaCoverRect() -> CGRect {
        guard let display = displayCoordinator.primaryDisplay else { return .null }
        let anchor = closedSize(for: display)
        let frame = display.screen.frame
        let compactWidth = anchor.width + MorphingNotchIsland.liveActivityWingExtension * 2
        let leftEdge = frame.midX - compactWidth / 2
        let coverCenterX = leftEdge
            + MorphingNotchIsland.liveActivityTopRadius
            + MorphingNotchIsland.liveActivityBorderMargin
            + MorphingNotchIsland.liveActivityVisibleWingWidth / 2
        return CGRect(
            x: coverCenterX - 15,
            y: frame.maxY - anchor.height,
            width: 30,
            height: anchor.height
        )
    }

    private func updateMediaCoverHover(at mouse: CGPoint) {
        let canPeek = viewModel.isActivityContentVisible
            && !viewModel.showsCodexLiveActivity
            && !viewModel.isExpanded

        if !canPeek {
            viewModel.isMediaCoverHovered = false
        } else if viewModel.isMediaCoverHovered {
            if !hotZoneRect().contains(mouse) {
                withAnimation(LazyNotchMotion.pillMorphSpring) {
                    viewModel.isMediaCoverHovered = false
                }
            }
        } else if compactMediaCoverRect().contains(mouse) {
            withAnimation(LazyNotchMotion.pillMorphSpring) {
                viewModel.isMediaCoverHovered = true
            }
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
            height: Self.openHeight + 10
        )
        return contentRect.insetBy(dx: -8, dy: -4).contains(mouse)
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
            height: Self.openHeight + 10
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
        if isSystemDragInProgress {
            // A drag only interacts with an already-open Shelf. Files near the
            // collapsed notch pass through without opening a drop surface.
            interactive = viewModel.isExpanded && (expandedInteractiveRect()?.contains(mouse) ?? false)
        } else if viewModel.isExpanded {
            interactive = expandedInteractiveRect()?.contains(mouse) ?? false
        } else {
            interactive = hotZoneRect().contains(mouse)
        }

        panel.ignoresMouseEvents = !interactive
    }

    private func pollCursor() {
        let mouse = NSEvent.mouseLocation
        let currentDragCount = NSPasteboard(name: .drag).changeCount

        if currentDragCount != lastDragChangeCount {
            lastDragChangeCount = currentDragCount
            if NSEvent.pressedMouseButtons != 0 {
                isSystemDragInProgress = true
            }
        }

        if isSystemDragInProgress && NSEvent.pressedMouseButtons == 0 {
            isSystemDragInProgress = false
        }

        updateMediaCoverHover(at: mouse)

        let engaged = isSystemDragInProgress
            ? viewModel.isExpanded && (expandedInteractiveRect()?.contains(mouse) ?? false)
            : cursorIsEngaged()
        updateMousePassThrough()

        if viewModel.isHovered != engaged {
            withAnimation(LazyNotchMotion.interactiveSpring) {
                viewModel.isHovered = engaged
            }
        }

        if engaged {
            leaveArmedAt = nil
            if !viewModel.isExpanded {
                let openOnHover = UserDefaults.standard.object(forKey: "openOnHover") as? Bool ?? true
                let canAutoExpand = openOnHover && !viewModel.isActivityContentVisible
                if canAutoExpand {
                    let isAtCeiling: Bool
                    if let display = displayCoordinator.primaryDisplay {
                        isAtCeiling = mouse.y >= (display.screen.frame.maxY - 3)
                    } else {
                        isAtCeiling = false
                    }
                    let effectiveGrace: TimeInterval = isAtCeiling ? 0.04 : Self.hoverEnterGrace
                    if let armed = enterArmedAt, Date().timeIntervalSince(armed) >= effectiveGrace {
                        expand()
                    } else if enterArmedAt == nil {
                        enterArmedAt = Date()
                    }
                } else {
                    enterArmedAt = nil
                }
            }
        } else {
            if isSystemDragInProgress {
                leaveArmedAt = nil
                enterArmedAt = nil
                return
            }

            enterArmedAt = nil
            // Hold the island open while a hold-open request is active (file picker / post-staging feedback).
            let isHeldOpen = Date() < (holdOpenUntil ?? .distantPast)
            if viewModel.isExpanded, !isHeldOpen {
                let leaveGrace = UserDefaults.standard.object(forKey: "hoverGraceDuration") as? Double ?? Self.hoverLeaveGrace
                if let armed = leaveArmedAt, Date().timeIntervalSince(armed) >= leaveGrace {
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
        enterArmedAt = nil
        updateMousePassThrough()
        panel.orderFrontRegardless()
        withAnimation(LazyNotchMotion.shellSpring(isExpanded: true)) {
            viewModel.openHome()
        }
        MirrorWindowController.shared.closeMirror()
    }

    func collapse() {
        guard viewModel.isExpanded else { return }
        // Update before the animated flag change so the cursor's current location is
        // evaluated against the outgoing (expanded) geometry.
        updateMousePassThrough()
        withAnimation(LazyNotchMotion.shellSpring(isExpanded: false)) {
            viewModel.close()
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
            viewModel.openShelf()
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
