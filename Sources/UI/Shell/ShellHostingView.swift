import AppKit
import SwiftUI

/// Hosts the SwiftUI shell. Hover is polled directly by the window controller.
/// Clicks outside the active notch boundary pass through cleanly to underlying windows.
final class ShellHostingView: NSHostingView<ShellContentView> {
    weak var viewModel: ShellViewModel?
    private weak var forwardedDragDestination: NSView?

    static func shouldDeferDropToSwiftUI(isExpanded: Bool) -> Bool {
        isExpanded
    }

    static func isInternalShelfDrag(
        _ types: [NSPasteboard.PasteboardType]?,
        sourceIsInsideShell: Bool = false,
        hasActiveShelfDrag: Bool = false
    ) -> Bool {
        hasActiveShelfDrag
            || sourceIsInsideShell
            || types?.contains(NSPasteboard.PasteboardType(LazyShelfDrag.type.identifier)) == true
    }

    static func isExternalFileDrag(
        _ types: [NSPasteboard.PasteboardType]?,
        sourceIsInsideShell: Bool = false,
        hasActiveShelfDrag: Bool = false
    ) -> Bool {
        guard !isInternalShelfDrag(
            types,
            sourceIsInsideShell: sourceIsInsideShell,
            hasActiveShelfDrag: hasActiveShelfDrag
        ) else { return false }
        return types?.contains(.fileURL) == true
    }

    required init(rootView: ShellContentView) {
        super.init(rootView: rootView)
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        registerForDraggedTypes([
            .fileURL,
            NSPasteboard.PasteboardType(LazyShelfDrag.type.identifier)
        ])
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        if Self.shouldDeferDropToSwiftUI(isExpanded: viewModel?.isExpanded == true) {
            viewModel?.isShelfDropTargeted = false
            return forwardDraggingEntered(sender)
        }
        if isInternalShelfDrag(sender) {
            viewModel?.isShelfDropTargeted = false
            return super.draggingEntered(sender)
        }
        return prepareForExternalShelfDrop(sender)
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        if Self.shouldDeferDropToSwiftUI(isExpanded: viewModel?.isExpanded == true) {
            viewModel?.isShelfDropTargeted = false
            return forwardDraggingUpdated(sender)
        }
        if isInternalShelfDrag(sender) {
            viewModel?.isShelfDropTargeted = false
            return super.draggingUpdated(sender)
        }
        return prepareForExternalShelfDrop(sender)
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        viewModel?.isShelfDropTargeted = false
        forwardedDragDestination?.draggingExited(sender)
        forwardedDragDestination = nil
        super.draggingExited(sender)
    }

    override func draggingEnded(_ sender: any NSDraggingInfo) {
        LazyShelfStore.shared.endDragging()
        viewModel?.isShelfDropTargeted = false
        forwardedDragDestination?.draggingEnded(sender)
        forwardedDragDestination = nil
        super.draggingEnded(sender)
    }

    private func canAcceptShelfDrop(_ sender: any NSDraggingInfo) -> Bool {
        guard let viewModel,
              viewModel.isExpanded,
              viewModel.activeTab == .shelf,
              Self.isExternalFileDrag(
                  sender.draggingPasteboard.types,
                  sourceIsInsideShell: isDraggingSourceInsideShell(sender),
                  hasActiveShelfDrag: hasActiveShelfDrag
              ) else { return false }
        let point = convert(sender.draggingLocation, from: nil)
        let shelfRect = NSRect(
            x: (bounds.width - LazyNotchWindowController.openWidth) / 2,
            y: isFlipped ? 0 : (bounds.height - LazyNotchWindowController.openHeight),
            width: LazyNotchWindowController.openWidth,
            height: LazyNotchWindowController.openHeight
        )
        return shelfRect.contains(point)
    }

    private func prepareForExternalShelfDrop(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard Self.isExternalFileDrag(
            sender.draggingPasteboard.types,
            sourceIsInsideShell: isDraggingSourceInsideShell(sender),
            hasActiveShelfDrag: hasActiveShelfDrag
        ), let viewModel else {
            viewModel?.isShelfDropTargeted = false
            return []
        }

        // A file dragged onto the physical notch opens directly into the Shelf. The
        // expanded drop target then takes over without requiring a second gesture.
        if !viewModel.isExpanded {
            withAnimation(LazyNotchMotion.shellSpring(isExpanded: true)) {
                viewModel.openShelf()
            }
        }

        let acceptsDrop = canAcceptShelfDrop(sender)
        viewModel.isShelfDropTargeted = acceptsDrop
        return acceptsDrop ? .copy : []
    }

    private func isInternalShelfDrag(_ sender: any NSDraggingInfo) -> Bool {
        Self.isInternalShelfDrag(
            sender.draggingPasteboard.types,
            sourceIsInsideShell: isDraggingSourceInsideShell(sender),
            hasActiveShelfDrag: hasActiveShelfDrag
        )
    }

    private var hasActiveShelfDrag: Bool {
        !LazyShelfStore.shared.draggedItemIDs.isEmpty
    }

    private func isDraggingSourceInsideShell(_ sender: any NSDraggingInfo) -> Bool {
        guard let sourceView = sender.draggingSource as? NSView else { return false }
        return sourceView === self || sourceView.isDescendant(of: self)
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
        defer { viewModel?.isShelfDropTargeted = false }
        if Self.shouldDeferDropToSwiftUI(isExpanded: viewModel?.isExpanded == true) {
            let handled = forwardedDragDestination?.performDragOperation(sender) ?? false
            forwardedDragDestination = nil
            return handled
        }
        if isInternalShelfDrag(sender) {
            return super.performDragOperation(sender)
        }
        guard let viewModel, canAcceptShelfDrop(sender) else { return false }
        let urls = extractURLs(from: sender.draggingPasteboard)
        guard !urls.isEmpty else { return false }

        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)

        withAnimation(LazyNotchMotion.interactiveSpring) {
            LazyShelfStore.shared.add(urls: urls)
        }
        viewModel.openShelf()
        NotificationCenter.default.post(
            name: NSNotification.Name("LazyNotchHoldOpenTrayRequest"),
            object: nil,
            userInfo: ["seconds": 5.0]
        )
        return true
    }

    private func dragDestination(at draggingLocation: NSPoint) -> NSView? {
        let point = convert(draggingLocation, from: nil)
        guard let destination = super.hitTest(point), destination !== self else { return nil }
        return destination
    }

    private func forwardDraggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        forwardedDragDestination = dragDestination(at: sender.draggingLocation)
        return forwardedDragDestination?.draggingEntered(sender) ?? []
    }

    private func forwardDraggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        let destination = dragDestination(at: sender.draggingLocation) ?? forwardedDragDestination
        if destination !== forwardedDragDestination {
            forwardedDragDestination?.draggingExited(sender)
            forwardedDragDestination = destination
            destination?.draggingEntered(sender)
        }
        return destination?.draggingUpdated(sender) ?? []
    }

    @MainActor required dynamic init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let viewModel else { return nil }

        // AppKit provides this hit-test point in the panel's bottom-origin space,
        // while SwiftUI lays out the shell from the top. Normalize once at this
        // boundary so the visual shell and the event region use the same origin.
        let localPoint = NSPoint(
            x: point.x,
            y: bounds.minY + bounds.maxY - point.y
        )

        if viewModel.isExpanded {
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
            let hit = super.hitTest(point)
            return hit ?? self
        } else {
            // When notch is collapsed: allow clicking the notch or live activity in navbar to open the Nook.
            let activeWidth = viewModel.isActivityContentVisible ? (viewModel.compactSize.width + 104) : (viewModel.compactSize.width + 24)
            let activeHeight = viewModel.isActivityContentVisible ? (viewModel.compactSize.height + 16) : (viewModel.compactSize.height + 8)
            let notchBounds = NSRect(
                x: (bounds.width - activeWidth) / 2,
                y: 0,
                width: activeWidth,
                height: activeHeight
            )
            guard notchBounds.contains(localPoint) else {
                return nil
            }
            let hit = super.hitTest(point)
            return hit ?? self
        }
    }
}
