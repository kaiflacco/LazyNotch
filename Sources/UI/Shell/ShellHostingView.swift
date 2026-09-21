import AppKit
import SwiftUI

/// Hosts the SwiftUI shell. Hover is polled directly by the window controller.
/// Clicks outside the active notch boundary pass through cleanly to underlying windows.
final class ShellHostingView: NSHostingView<ShellContentView> {
    weak var viewModel: ShellViewModel?
    var shadowPaddingX: CGFloat = 75
    var shadowPaddingBottom: CGFloat = 100

    required init(rootView: ShellContentView) {
        super.init(rootView: rootView)
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        registerForDraggedTypes([.fileURL])
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard let viewModel else { return [] }
        if !viewModel.isExpanded {
            withAnimation(LazyNotchMotion.shellSpring(isExpanded: true)) {
                viewModel.isExpanded = true
            }
        }
        updateDragZone(for: sender)
        return .copy
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard let viewModel else { return .copy }
        if !viewModel.isExpanded {
            withAnimation(LazyNotchMotion.shellSpring(isExpanded: true)) {
                viewModel.isExpanded = true
            }
        }
        updateDragZone(for: sender)
        
        let point = convert(sender.draggingLocation, from: nil)
        let hudWidth = LazyNotchWindowController.dropHUDWidth
        let hudHeight = LazyNotchWindowController.dropHUDHeight
        let islandY = isFlipped ? 0 : (bounds.height - hudHeight)
        let islandRect = NSRect(
            x: (bounds.width - hudWidth) / 2,
            y: islandY,
            width: hudWidth,
            height: hudHeight
        )
        let hitRect = islandRect.insetBy(dx: -25, dy: -25)
        return hitRect.contains(point) ? .copy : []
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        guard let viewModel else { return }
        withAnimation(LazyNotchMotion.interactiveSpring) {
            viewModel.globalDragZone = .none
        }
    }

    private func updateDragZone(for sender: any NSDraggingInfo) {
        guard let viewModel else { return }
        let point = convert(sender.draggingLocation, from: nil)
        
        let hudWidth = LazyNotchWindowController.dropHUDWidth
        let hudHeight = LazyNotchWindowController.dropHUDHeight
        let islandY = isFlipped ? 0 : (bounds.height - hudHeight)
        let islandRect = NSRect(
            x: (bounds.width - hudWidth) / 2,
            y: islandY,
            width: hudWidth,
            height: hudHeight
        )
        
        let hitRect = islandRect.insetBy(dx: -25, dy: -25)
        if hitRect.contains(point) {
            let targetZone: GlobalDragZone = point.x < islandRect.midX ? .tray : .airdrop
            if viewModel.globalDragZone != targetZone {
                withAnimation(LazyNotchMotion.interactiveSpring) {
                    viewModel.globalDragZone = targetZone
                }
            }
        }
    }

    private func extractURLs(from pasteboard: NSPasteboard) -> [URL] {
        var urls: [URL] = []
        if let direct = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !direct.isEmpty {
            urls.append(contentsOf: direct)
        }
        if urls.isEmpty, let files = pasteboard.propertyList(forType: .init("NSFilenamesPboardType")) as? [String] {
            urls.append(contentsOf: files.map { URL(fileURLWithPath: $0) })
        }
        if urls.isEmpty, let items = pasteboard.pasteboardItems {
            for item in items {
                if let string = item.string(forType: .fileURL), let url = URL(string: string) {
                    urls.append(url)
                } else if let string = item.string(forType: .init("public.file-url")), let url = URL(string: string) {
                    urls.append(url)
                }
            }
        }
        var seen = Set<String>()
        return urls.filter { seen.insert($0.standardizedFileURL.path).inserted }
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        guard let viewModel = viewModel else { return false }
        let urls = extractURLs(from: sender.draggingPasteboard)
        guard !urls.isEmpty else { return false }
        
        let point = convert(sender.draggingLocation, from: nil)
        let hudWidth = LazyNotchWindowController.dropHUDWidth
        let hudHeight = LazyNotchWindowController.dropHUDHeight
        let islandY = isFlipped ? 0 : (bounds.height - hudHeight)
        let islandRect = NSRect(
            x: (bounds.width - hudWidth) / 2,
            y: islandY,
            width: hudWidth,
            height: hudHeight
        )
        let hitRect = islandRect.insetBy(dx: -30, dy: -30)
        guard hitRect.contains(point) else { return false }
        
        let dropZone: GlobalDragZone = point.x < islandRect.midX ? .tray : .airdrop
        
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        
        if dropZone == .airdrop {
            withAnimation(LazyNotchMotion.interactiveSpring) {
                viewModel.globalDragZone = .none
                viewModel.isExpanded = false
            }
            DispatchQueue.main.async {
                NSSharingService(named: .sendViaAirDrop)?.perform(withItems: urls)
            }
        } else {
            LazyShelfStore.shared.add(urls: urls)
            withAnimation(LazyNotchMotion.interactiveSpring) {
                viewModel.globalDragZone = .none
                viewModel.activeTab = .shelf
            }
            NotificationCenter.default.post(
                name: NSNotification.Name("LazyNotchHoldOpenTrayRequest"),
                object: nil,
                userInfo: ["seconds": 5.0]
            )
        }
        return true
    }

    @MainActor required dynamic init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let viewModel else { return nil }

        let localPoint = convert(point, from: superview)

        if viewModel.globalDragZone != .none {
            let activeWidth = LazyNotchWindowController.dropHUDWidth
            let activeHeight = LazyNotchWindowController.dropHUDHeight
            let notchBounds = NSRect(
                x: (bounds.width - activeWidth) / 2,
                y: 0,
                width: activeWidth,
                height: activeHeight
            )
            guard notchBounds.contains(localPoint) else { return nil }
            return super.hitTest(point) ?? self
        } else if viewModel.isExpanded {
            let activeWidth = LazyNotchWindowController.openWidth
            let activeHeight = LazyNotchWindowController.openHeight
            let notchBounds = NSRect(
                x: (bounds.width - activeWidth) / 2,
                y: 0,
                width: activeWidth,
                height: activeHeight
            )
            guard notchBounds.contains(localPoint) else {
                return nil
            }
            return super.hitTest(point) ?? self
        } else {
            // When notch is collapsed: allow clicking the notch or live activity in navbar to open the Nook.
            let activeWidth = viewModel.hasActiveLiveActivity ? (viewModel.compactSize.width + 76) : viewModel.compactSize.width
            let activeHeight = viewModel.compactSize.height
            let notchBounds = NSRect(
                x: (bounds.width - activeWidth) / 2,
                y: 0,
                width: activeWidth,
                height: activeHeight
            )
            guard notchBounds.contains(localPoint) else {
                return nil
            }
            return super.hitTest(point) ?? self
        }
    }
}
