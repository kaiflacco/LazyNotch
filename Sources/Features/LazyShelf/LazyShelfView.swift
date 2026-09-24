import AppKit
import QuickLookThumbnailing
import SwiftUI
import UniformTypeIdentifiers

private enum ShelfVisuals {
    static let cyan = Color(red: 0.00, green: 0.88, blue: 0.96)
    static let blue = Color(red: 0.10, green: 0.52, blue: 1.00)
    static let purple = Color(red: 0.62, green: 0.26, blue: 0.98)
    static let pink = Color(red: 1.00, green: 0.18, blue: 0.68)

    static var glow: LinearGradient {
        LinearGradient(colors: [cyan, blue, purple, pink], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

private enum ShelfDrag {
    static let type = UTType(exportedAs: "com.lazynotch.shelf-items")

    static func provider(for item: LazyShelfItem) -> NSItemProvider {
        let provider = NSItemProvider(contentsOf: item.url) ?? NSItemProvider(object: item.url as NSURL)
        let itemID = item.id.uuidString
        provider.registerDataRepresentation(
            forTypeIdentifier: type.identifier,
            visibility: .ownProcess
        ) { completion in
            completion(Data(itemID.utf8), nil)
            return nil
        }
        return provider
    }
}

/// Stages files for temporary holding, Quick Look inspection, reordering, and AirDrop.
public struct LazyShelfView: View {
    @ObservedObject var store = LazyShelfStore.shared
    @State private var isShelfTargeted = false
    @State private var keyMonitor: Any?

    /// Process-wide guard: only one NSOpenPanel may be shown at a time.
    private static var isPanelActive = false

    public init() {}

    public var body: some View {
        Group {
            if store.items.isEmpty {
                emptyDropTarget
            } else {
                stagedContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onAppear(perform: installKeyboardMonitor)
        .onDisappear(perform: removeKeyboardMonitor)
        .onDrop(
            of: [UTType.fileURL.identifier, UTType.item.identifier],
            isTargeted: $isShelfTargeted,
            perform: stageDroppedFiles
        )
    }

    private var emptyDropTarget: some View {
        ZStack {
            if isShelfTargeted {
                NotchShape(topCornerRadius: 0, bottomCornerRadius: 42)
                    .fill(ShelfVisuals.glow.opacity(0.18))
                    .blur(radius: 10)
            }

            NotchShape(topCornerRadius: 0, bottomCornerRadius: 42)
                .fill(Color.white.opacity(isShelfTargeted ? 0.06 : 0.02))
                .overlay {
                    NotchShape(topCornerRadius: 0, bottomCornerRadius: 42)
                        .stroke(
                            isShelfTargeted ? AnyShapeStyle(ShelfVisuals.glow) : AnyShapeStyle(Color.white.opacity(0.12)),
                            style: StrokeStyle(lineWidth: 1, dash: [6, 7], dashPhase: 1)
                        )
                }

            HStack(spacing: 9) {
                Image(systemName: isShelfTargeted ? "arrow.down.circle.fill" : "tray.and.arrow.down")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isShelfTargeted ? AnyShapeStyle(ShelfVisuals.glow) : AnyShapeStyle(Color.white.opacity(0.45)))

                VStack(alignment: .leading, spacing: 1) {
                    Text(isShelfTargeted ? "Release to add" : "Add to Lazy Shelf")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(isShelfTargeted ? 1 : 0.68))
                    Text("Drop files or click to browse")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.white.opacity(0.34))
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            addFilesViaPanel()
        }
        .animation(LazyNotchMotion.interactiveSpring, value: isShelfTargeted)
        .help("Click to browse for files, or drop them here")
    }

    private var stagedContent: some View {
        VStack(spacing: 8) {
            HStack(spacing: 5) {
                Text("\(store.items.count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                Text(store.items.count == 1 ? "item staged" : "items staged")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.38))

                Spacer()

                Button("Clear All") {
                    withAnimation(LazyNotchMotion.interactiveSpring) {
                        store.clearAll()
                    }
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.42))
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                AirDropDock(store: store)
                    .padding(.leading, 8)

                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(store.items) { item in
                                StagedItemCard(item: item, store: store)
                                .id(item.id)
                                .onDrop(
                                    of: [ShelfDrag.type.identifier],
                                    delegate: ShelfReorderDropDelegate(targetID: item.id, store: store)
                                )
                            }

                            miniAddSlot
                                .onDrop(
                                    of: [ShelfDrag.type.identifier],
                                    delegate: ShelfReorderDropDelegate(targetID: nil, store: store)
                                )
                        }
                        .padding(.vertical, 2)
                        .padding(.horizontal, 1)
                        .animation(LazyNotchMotion.interactiveSpring, value: store.items.map(\.id))
                    }
                    .onChange(of: store.focusedItemID) { _, focusedID in
                        guard let focusedID else { return }
                        withAnimation(LazyNotchMotion.interactiveSpring) {
                            proxy.scrollTo(focusedID, anchor: .center)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .background {
                NotchShape(topCornerRadius: 0, bottomCornerRadius: 42)
                    .fill(Color.black.opacity(0.25))
                    .overlay {
                        NotchShape(topCornerRadius: 0, bottomCornerRadius: 42)
                            .stroke(
                                Color.white.opacity(0.12),
                                style: StrokeStyle(lineWidth: 1, dash: [6, 7], dashPhase: 1)
                            )
                    }
            }
        }
    }

    private var miniAddSlot: some View {
        Button {
            addFilesViaPanel()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.38))
                .frame(width: 78, height: 74)
        }
        .buttonStyle(.plain)
        .help("Add files from disk")
    }

    private func addFilesViaPanel() {
        guard !LazyShelfView.isPanelActive else { return }
        LazyShelfView.isPanelActive = true

        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(
            name: NSNotification.Name("LazyNotchHoldOpenTrayRequest"),
            object: nil,
            userInfo: ["seconds": 300.0]
        )
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        panel.message = "Choose files or folders to stage in Lazy Shelf"
        panel.begin { response in
            defer { LazyShelfView.isPanelActive = false }
            if response == .OK, !panel.urls.isEmpty {
                withAnimation(LazyNotchMotion.interactiveSpring) {
                    store.add(urls: panel.urls)
                }
            }
            NotificationCenter.default.post(
                name: NSNotification.Name("LazyNotchHoldOpenTrayRequest"),
                object: nil,
                userInfo: ["seconds": 6.0]
            )
        }
    }

    private func stageDroppedFiles(_ providers: [NSItemProvider]) -> Bool {
        if providers.contains(where: { $0.hasItemConformingToTypeIdentifier(ShelfDrag.type.identifier) }) {
            store.endDragging()
            return true
        }
        loadFileURLs(from: providers) { urls in
            guard !urls.isEmpty else { return }
            withAnimation(LazyNotchMotion.interactiveSpring) {
                store.add(urls: urls)
            }
        }
        return true
    }

    private func installKeyboardMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let isShelfEvent = event.window?.contentView is ShellHostingView
            guard isShelfEvent || store.previewItemURL != nil else { return event }

            switch event.keyCode {
            case 49: // Space
                store.toggleQuickLookForFocusedItem()
            case 123: // Left Arrow
                store.moveFocus(by: -1)
            case 124: // Right Arrow
                store.moveFocus(by: 1)
            case 53: // Escape
                store.closeQuickLook()
                store.clearSelection()
            case 0 where event.modifierFlags.contains(.command): // Command-A
                store.selectAll()
            default:
                return event
            }
            return nil
        }
    }

    private func removeKeyboardMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }
}

private struct AirDropDock: View {
    @ObservedObject var store: LazyShelfStore
    @State private var isTargeted = false

    var body: some View {
        Button {
            store.sendAllViaAirDrop()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.black)
                    .overlay {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
                    }

                icon
            }
            .frame(width: 62, height: 62)
            .scaleEffect(isTargeted ? 1.025 : 1)
        }
        .buttonStyle(.plain)
        .onDrop(
            of: [ShelfDrag.type.identifier, UTType.fileURL.identifier, UTType.item.identifier],
            isTargeted: $isTargeted
        ) { providers in
            if providers.contains(where: { $0.hasItemConformingToTypeIdentifier(ShelfDrag.type.identifier) }) {
                let handled = store.sendDraggedItemsViaAirDrop()
                store.endDragging()
                return handled
            }

            loadFileURLs(from: providers) { urls in
                store.sendViaAirDrop(urls)
            }
            return true
        }
        .animation(LazyNotchMotion.interactiveSpring, value: isTargeted)
        .accessibilityLabel("AirDrop")
        .accessibilityValue(subtitle)
        .help("Send all staged files with AirDrop, or drop files here")
    }

    @ViewBuilder
    private var icon: some View {
        ZStack {
            switch store.airDropState {
            case .idle:
                AirDropIcon(color: .white)
            case .progress:
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
            case .success:
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            case .failure:
                Image(systemName: "exclamationmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .contentTransition(.symbolEffect(.replace))
    }

    private var subtitle: String {
        if isTargeted { return "Release to send" }
        switch store.airDropState {
        case .progress: return "Opening…"
        case .success: return "Ready"
        case .failure: return "Unavailable"
        case .idle:
            let count = store.selectedItemIDs.count
            return count > 0 ? "\(count) selected" : "Send all"
        }
    }
}

private struct AirDropIcon: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let scale = (min(size.width, size.height) - 4) / 28

            for radius in [6.5, 10.0, 13.5] {
                var arc = Path()
                arc.addArc(
                    center: center,
                    radius: radius * scale,
                    startAngle: .degrees(135),
                    endAngle: .degrees(405),
                    clockwise: false
                )
                context.stroke(
                    arc,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: 2.6 * scale, lineCap: .round)
                )
            }

            let dotRadius = 2.4 * scale
            context.fill(
                Path(ellipseIn: CGRect(
                    x: center.x - dotRadius,
                    y: center.y - dotRadius,
                    width: dotRadius * 2,
                    height: dotRadius * 2
                )),
                with: .color(color)
            )
        }
        .frame(width: 32, height: 32)
    }
}

private struct StagedItemCard: View {
    let item: LazyShelfItem
    @ObservedObject var store: LazyShelfStore
    @State private var isHovered = false

    private var isSelected: Bool { store.selectedItemIDs.contains(item.id) }

    var body: some View {
        VStack(spacing: 4) {
            ShelfThumbnail(item: item)

            Text(item.name)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 66)

            Text(item.sizeString)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.46))
        }
        .frame(width: 78, height: 74)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(isSelected ? 0.12 : (isHovered ? 0.08 : 0.035)))
        }
        .scaleEffect(isHovered ? 1.015 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture {
            let modifiers = NSApp.currentEvent?.modifierFlags.intersection(.deviceIndependentFlagsMask) ?? []
            if modifiers.contains(.command) {
                store.toggleSelection(of: item, extendingRange: modifiers.contains(.shift))
            } else {
                store.focus(item)
                store.showQuickLook(for: item)
            }
        }
        .onDrag {
            store.beginDragging(item)
            return ShelfDrag.provider(for: item)
        }
        .onHover { isHovered = $0 }
        .animation(LazyNotchMotion.interactiveSpring, value: isHovered)
        .animation(LazyNotchMotion.interactiveSpring, value: isSelected)
        .contextMenu {
            Button("Quick Look") {
                store.focus(item)
                store.showQuickLook(for: item)
            }
            Button("Open") { NSWorkspace.shared.open(item.url) }
            Button("Reveal in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
            Divider()
            Button("Remove from Lazy Shelf", role: .destructive) {
                withAnimation(LazyNotchMotion.interactiveSpring) {
                    store.remove(item: item)
                }
            }
        }
        .help(item.name)
    }
}

private struct ShelfThumbnail: View {
    let item: LazyShelfItem
    @State private var thumbnail: NSImage?

    var body: some View {
        Image(nsImage: thumbnail ?? item.icon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 38, height: 34)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .task(id: item.url) {
                let request = QLThumbnailGenerator.Request(
                    fileAt: item.url,
                    size: CGSize(width: 76, height: 68),
                    scale: NSScreen.main?.backingScaleFactor ?? 2,
                    representationTypes: .all
                )
                thumbnail = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).nsImage
            }
    }
}

private struct ShelfReorderDropDelegate: DropDelegate {
    let targetID: UUID?
    let store: LazyShelfStore

    func dropEntered(info: DropInfo) {
        guard info.hasItemsConforming(to: [ShelfDrag.type]) else { return }
        withAnimation(LazyNotchMotion.interactiveSpring) {
            store.moveDraggedItems(before: targetID)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        store.endDragging()
        return true
    }
}

private func loadFileURLs(from providers: [NSItemProvider], completion: @escaping ([URL]) -> Void) {
    let group = DispatchGroup()
    var urls: [URL] = []

    for provider in providers {
        group.enter()
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                DispatchQueue.main.async {
                    if let data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        urls.append(url)
                    }
                    group.leave()
                }
            }
        } else {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                DispatchQueue.main.async {
                    if let url { urls.append(url) }
                    group.leave()
                }
            }
        }
    }

    group.notify(queue: .main) {
        completion(urls)
    }
}
