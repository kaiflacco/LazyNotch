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
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(ShelfVisuals.glow.opacity(0.18))
                    .blur(radius: 10)
            }

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(isShelfTargeted ? 0.07 : 0.025))
                .overlay {
                    if isShelfTargeted {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(
                                ShelfVisuals.glow,
                                style: StrokeStyle(lineWidth: 1.3, dash: [5, 4])
                            )
                    }
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
        VStack(spacing: 4) {
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
            .padding(.horizontal, 2)

            HStack(spacing: 8) {
                AirDropDock(store: store)

                Divider()
                    .overlay(Color.white.opacity(0.08))
                    .frame(height: 56)

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
        }
    }

    private var miniAddSlot: some View {
        Button {
            addFilesViaPanel()
        } label: {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.035))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.38))
                }
                .frame(width: 56, height: 74)
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
    @State private var isHovered = false

    var body: some View {
        Button {
            store.sendAllViaAirDrop()
        } label: {
            HStack(spacing: 8) {
                icon

                VStack(alignment: .leading, spacing: 1) {
                    Text("AirDrop")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.48))
                        .lineLimit(1)
                }
            }
            .frame(width: 104, height: 74)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(isHovered ? 0.11 : 0.07))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                isTargeted ? AnyShapeStyle(ShelfVisuals.glow) : AnyShapeStyle(Color.white.opacity(0.1)),
                                lineWidth: isTargeted ? 1.5 : 0.8
                            )
                    }
                    .shadow(color: isTargeted ? ShelfVisuals.blue.opacity(0.45) : .clear, radius: 10)
            }
            .scaleEffect(isTargeted ? 1.025 : 1)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
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
        .animation(LazyNotchMotion.interactiveSpring, value: isHovered)
        .help("Send all staged files with AirDrop, or drop files here")
    }

    @ViewBuilder
    private var icon: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 34, height: 34)

            switch store.airDropState {
            case .idle:
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(nsColor: .systemBlue))
            case .progress:
                ProgressView()
                    .controlSize(.small)
                    .tint(Color(nsColor: .systemBlue))
            case .success:
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(nsColor: .systemBlue))
            case .failure:
                Image(systemName: "exclamationmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(nsColor: .systemOrange))
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

private struct StagedItemCard: View {
    let item: LazyShelfItem
    @ObservedObject var store: LazyShelfStore
    @State private var isHovered = false

    private var isSelected: Bool { store.selectedItemIDs.contains(item.id) }
    private var isFocused: Bool { store.focusedItemID == item.id }

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
                .fill(Color.white.opacity(isHovered ? 0.12 : 0.065))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isSelected ? Color(nsColor: .systemBlue).opacity(0.85) : Color.white.opacity(isHovered ? 0.18 : 0.08),
                    lineWidth: isSelected ? 1.5 : 0.8
                )
        }
        .overlay {
            if isFocused && !isSelected {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.42), lineWidth: 1)
                    .padding(-2)
            }
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
