import AppKit
import SwiftUI

/// Hosts the SwiftUI shell. Hover is polled directly by the window controller.
/// Clicks outside the active notch boundary pass through cleanly to underlying windows.
final class ShellHostingView: NSHostingView<ShellContentView> {
    weak var viewModel: ShellViewModel?

    required init(rootView: ShellContentView) {
        super.init(rootView: rootView)
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        registerForDraggedTypes([.fileURL])
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        canAcceptShelfDrop(sender) ? .copy : []
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        canAcceptShelfDrop(sender) ? .copy : []
    }

    private func canAcceptShelfDrop(_ sender: any NSDraggingInfo) -> Bool {
        guard let viewModel, viewModel.isExpanded, viewModel.activeTab == .shelf else { return false }
        let point = convert(sender.draggingLocation, from: nil)
        let shelfRect = NSRect(
            x: (bounds.width - LazyNotchWindowController.openWidth) / 2,
            y: isFlipped ? 0 : (bounds.height - LazyNotchWindowController.openHeight),
            width: LazyNotchWindowController.openWidth,
            height: LazyNotchWindowController.openHeight
        )
        return shelfRect.contains(point)
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

    @MainActor required dynamic init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let viewModel else { return nil }

        // AppKit supplies `point` in this view's local coordinate space. Converting it
        // from the superview shifts the hit region and makes the shell feel misaligned.
        let localPoint = point

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
            return super.hitTest(point) ?? self
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
            return super.hitTest(point) ?? self
        }
    }
}
