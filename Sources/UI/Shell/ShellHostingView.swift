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
        withAnimation(LazyNotchMotion.shellSpring(isExpanded: true)) {
            viewModel.isExpanded = true
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
        let islandY = isFlipped ? 0 : (bounds.height - LazyNotchWindowController.openHeight)
        let islandRect = NSRect(
            x: (bounds.width - LazyNotchWindowController.openWidth) / 2,
            y: islandY,
            width: LazyNotchWindowController.openWidth,
            height: LazyNotchWindowController.openHeight
        )
        return islandRect.contains(point) ? .copy : []
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
        
        let islandY = isFlipped ? 0 : (bounds.height - LazyNotchWindowController.openHeight)
        let islandRect = NSRect(
            x: (bounds.width - LazyNotchWindowController.openWidth) / 2,
            y: islandY,
            width: LazyNotchWindowController.openWidth,
            height: LazyNotchWindowController.openHeight
        )
        
        if islandRect.contains(point) {
            let targetZone: GlobalDragZone = point.x < islandRect.midX ? .tray : .airdrop
            if viewModel.globalDragZone != targetZone {
                withAnimation(LazyNotchMotion.interactiveSpring) {
                    viewModel.globalDragZone = targetZone
                }
            }
        } else {
            if viewModel.globalDragZone == .none {
                withAnimation(LazyNotchMotion.interactiveSpring) {
                    viewModel.globalDragZone = .tray
                }
            }
        }
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        guard let pasteboard = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], let viewModel = viewModel else {
            return false
        }
        
        let point = convert(sender.draggingLocation, from: nil)
        let islandY = isFlipped ? 0 : (bounds.height - LazyNotchWindowController.openHeight)
        let islandRect = NSRect(
            x: (bounds.width - LazyNotchWindowController.openWidth) / 2,
            y: islandY,
            width: LazyNotchWindowController.openWidth,
            height: LazyNotchWindowController.openHeight
        )
        
        guard islandRect.contains(point) else { return false }
        
        if viewModel.globalDragZone == .airdrop {
            NSSharingService(named: .sendViaAirDrop)?.perform(withItems: pasteboard)
        } else {
            LazyShelfStore.shared.add(urls: pasteboard)
        }
        
        withAnimation(LazyNotchMotion.interactiveSpring) {
            viewModel.globalDragZone = .none
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

        // Convert point from superview (unflipped AppKit window coordinates) to local flipped view coordinates
        let localPoint = convert(point, from: superview)

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
