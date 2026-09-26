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

enum LazyShelfDrag {
    static let type = UTType(exportedAs: "com.lazynotch.shelf-items", conformingTo: .data)

    static func acceptsExternalDrop(types: [UTType], hasActiveShelfDrag: Bool) -> Bool {
        guard !hasActiveShelfDrag,
              !types.contains(type) else { return false }
        return types.contains { $0 == UTType.fileURL || $0 == UTType.item }
    }

    static func pasteboardItem(for url: URL, itemIDs: [UUID]) -> NSPasteboardItem {
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(url.absoluteString, forType: .fileURL)
        pasteboardItem.setString(url.path, forType: .string)
        let itemIDString = itemIDs.map(\.uuidString).joined(separator: "\n")
        pasteboardItem.setString(
            itemIDString,
            forType: NSPasteboard.PasteboardType(type.identifier)
        )
        return pasteboardItem
    }

    static func provider(for item: LazyShelfItem, itemIDs: [UUID]) -> NSItemProvider {
        let provider = NSItemProvider(contentsOf: item.url) ?? NSItemProvider(object: item.url as NSURL)
        provider.registerDataRepresentation(
            forTypeIdentifier: type.identifier,
            visibility: .ownProcess
        ) { completion in
            let payload = Data(itemIDs.map(\.uuidString).joined(separator: "\n").utf8)
            completion(payload, nil)
            return nil
        }
        return provider
    }
}

/// Stages file references for persistent holding, Quick Look inspection, reordering, and AirDrop.
public struct LazyShelfView: View {
    @ObservedObject var store = LazyShelfStore.shared
    @EnvironmentObject private var shellViewModel: ShellViewModel
    @State private var isShelfTargeted = false
    @State private var keyMonitor: Any?

    /// Process-wide guard: only one NSOpenPanel may be shown at a time.
    private static var isPanelActive = false

    public init() {}

    private var isDropTargeted: Bool {
        isShelfTargeted || shellViewModel.isShelfDropTargeted
    }

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
    }

    private var emptyDropTarget: some View {
        VStack(spacing: 8) {
            HStack(spacing: 5) {
                Text("Lazy Shelf")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.58))

                Spacer()

                ShelfVolumeControl()
            }
            .frame(height: 28)

            ZStack {
                if isDropTargeted {
                    NotchShape(topCornerRadius: 0, bottomCornerRadius: 42)
                        .fill(ShelfVisuals.glow.opacity(0.18))
                        .blur(radius: 10)
                }

                NotchShape(topCornerRadius: 0, bottomCornerRadius: 42)
                    .fill(Color.white.opacity(isDropTargeted ? 0.06 : 0.02))
                    .overlay {
                        NotchShape(topCornerRadius: 0, bottomCornerRadius: 42)
                            .stroke(
                                isDropTargeted ? AnyShapeStyle(ShelfVisuals.glow) : AnyShapeStyle(Color.white.opacity(0.12)),
                                style: StrokeStyle(lineWidth: 1, dash: [6, 7], dashPhase: 1)
                            )
                    }

                HStack(spacing: 9) {
                    Image(systemName: isDropTargeted ? "arrow.down.circle.fill" : "tray.and.arrow.down")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isDropTargeted ? AnyShapeStyle(ShelfVisuals.glow) : AnyShapeStyle(Color.white.opacity(0.45)))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(isDropTargeted ? "Release to add" : "Add to Lazy Shelf")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(isDropTargeted ? 1 : 0.68))
                        Text("Drop files or click to browse")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(.white.opacity(0.34))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                addFilesViaPanel()
            }
            .onDrop(
                of: [UTType.fileURL, UTType.item],
                delegate: ShelfExternalDropDelegate(
                    store: store,
                    isTargeted: $isShelfTargeted
                )
            )
        }
        .animation(LazyNotchMotion.interactiveSpring, value: isDropTargeted)
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

                ShelfVolumeControl()

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
                                }

                                miniAddSlot
                                    .onDrop(
                                        of: [LazyShelfDrag.type],
                                        delegate: ShelfReorderDropDelegate(
                                            targetID: nil,
                                            store: store
                                        )
                                    )
                            }
                            .padding(.vertical, 2)
                            .padding(.horizontal, 1)
                            .animation(LazyNotchMotion.interactiveSpring, value: store.items.map(\.id))
                        }
                        .scrollClipDisabled()
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
                    .fill(Color.black.opacity(isDropTargeted ? 0.10 : 0.25))
                    .overlay {
                        NotchShape(topCornerRadius: 0, bottomCornerRadius: 42)
                            .stroke(
                                isDropTargeted
                                    ? AnyShapeStyle(ShelfVisuals.glow)
                                    : AnyShapeStyle(Color.white.opacity(0.12)),
                                style: StrokeStyle(lineWidth: 1, dash: [6, 7], dashPhase: 1)
                                )
                    }
                    .onDrop(
                        of: [UTType.fileURL, UTType.item],
                        delegate: ShelfExternalDropDelegate(
                            store: store,
                            isTargeted: $isShelfTargeted
                        )
                    )
            }
        }
        .overlay(alignment: .top) {
            if shellViewModel.isShelfDropTargeted {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                    Text("Release to add files")
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.black.opacity(0.82)))
                .overlay(Capsule().stroke(ShelfVisuals.cyan.opacity(0.75), lineWidth: 0.75))
                .transition(.opacity)
            }
        }
        .animation(LazyNotchMotion.interactiveSpring, value: shellViewModel.isShelfDropTargeted)
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

    private var isGlowing: Bool {
        isTargeted || store.airDropState != .idle
    }

    var body: some View {
        Button {
            if store.selectedItemIDs.isEmpty {
                store.sendAllViaAirDrop()
            } else {
                store.sendSelectedItemsViaAirDrop()
            }
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    if isGlowing {
                        Circle()
                            .fill(ShelfVisuals.glow.opacity(isTargeted ? 0.34 : 0.20))
                            .blur(radius: isTargeted ? 12 : 8)
                            .scaleEffect(isTargeted ? 1.18 : 1.08)
                    }

                    Circle()
                        .fill(Color.black)
                        .overlay {
                            Circle()
                                .strokeBorder(
                                    isGlowing ? AnyShapeStyle(ShelfVisuals.glow) : AnyShapeStyle(Color.white.opacity(0.28)),
                                    lineWidth: isGlowing ? 1.4 : 1
                                )
                        }
                        .shadow(
                            color: isGlowing ? ShelfVisuals.blue.opacity(isTargeted ? 0.7 : 0.4) : .clear,
                            radius: isTargeted ? 15 : 9
                        )

                    icon
                }
                .frame(width: 52, height: 52)

                Text(isTargeted ? "Drop to send" : "AirDrop")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(isTargeted ? 0.9 : 0.44))
                    .lineLimit(1)
            }
            .frame(width: 76, height: 74)
            .scaleEffect(isTargeted ? 1.025 : 1)
        }
        .buttonStyle(.plain)
        .onDrop(
            of: [LazyShelfDrag.type, UTType.fileURL, UTType.item],
            isTargeted: $isTargeted
        ) { providers in
            if providers.contains(where: { $0.hasItemConformingToTypeIdentifier(LazyShelfDrag.type.identifier) }) {
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
        .animation(LazyNotchMotion.interactiveSpring, value: store.airDropState)
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
            case .opening:
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
            case .opened:
                Image(systemName: "square.and.arrow.up")
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
        case .opening: return "Opening…"
        case .opened: return "Share sheet opened"
        case .failure: return "Unavailable"
        case .idle:
            let count = store.selectedItemIDs.count
            return count > 0 ? "\(count) selected" : "Send all"
        }
    }
}

private struct ShelfMediaDock: View {
    @ObservedObject private var mediaService = MediaService.shared

    private var track: MediaTrack? { mediaService.currentTrack }
    private var isPlaying: Bool { track?.isPlaying == true }

    var body: some View {
        Group {
            if let track {
                HStack(spacing: 6) {
                    Button {
                        mediaService.activateApp()
                    } label: {
                        artwork
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help("Open \(track.appName)")

                    VStack(alignment: .leading, spacing: 1) {
                        Text(track.displayTitle)
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(1)
                        Text(track.displayArtist)
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.42))
                            .lineLimit(1)
                    }
                    .frame(width: 92, alignment: .leading)

                    HStack(spacing: 1) {
                        shelfMediaButton(
                            systemName: "backward.end.fill",
                            label: "Previous track",
                            action: mediaService.previousTrack
                        )
                        shelfMediaButton(
                            systemName: isPlaying ? "pause.fill" : "play.fill",
                            label: isPlaying ? "Pause" : "Play",
                            action: mediaService.togglePlayPause,
                            isProminent: true
                        )
                        shelfMediaButton(
                            systemName: "forward.end.fill",
                            label: "Next track",
                            action: mediaService.nextTrack
                        )
                    }
                }
                .padding(.horizontal, 6)
                .frame(height: 28)
                .background {
                    Capsule()
                        .fill(Color.white.opacity(0.045))
                        .overlay {
                            Capsule()
                                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                        }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Now playing \(track.displayTitle) by \(track.displayArtist)")
            }
        }
    }

    @ViewBuilder
    private var artwork: some View {
        if let image = mediaService.cachedArtwork {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.10))
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.58))
                }
        }
    }

    private func shelfMediaButton(
        systemName: String,
        label: String,
        action: @escaping () -> Void,
        isProminent: Bool = false
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: isProminent ? 9 : 7.5, weight: .bold))
                .foregroundStyle(.white.opacity(isProminent ? 0.90 : 0.62))
                .frame(width: isProminent ? 22 : 18, height: 22)
                .background {
                    if isProminent {
                        Circle().fill(Color.white.opacity(0.10))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
    }
}

private struct ShelfVolumeControl: View {
    @ObservedObject private var audioService = SystemAudioService.shared

    private var percentage: Int {
        Int((audioService.volume * 100).rounded())
    }

    var body: some View {
        HStack(spacing: 5) {
            Button {
                audioService.toggleMute()
            } label: {
                Image(systemName: audioService.isMuted ? "speaker.slash.fill" : volumeIcon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(audioService.isAvailable ? 0.72 : 0.28))
                    .frame(width: 16, height: 20)
            }
            .buttonStyle(.plain)
            .disabled(!audioService.isAvailable)
            .accessibilityLabel(audioService.isMuted ? "Unmute" : "Mute")
            .help(audioService.isMuted ? "Unmute" : "Mute")

            Slider(
                value: Binding(
                    get: { audioService.volume },
                    set: { audioService.setVolume($0) }
                ),
                in: 0...1
            )
            .tint(ShelfVisuals.cyan)
            .frame(width: 66)
            .controlSize(.mini)
            .disabled(!audioService.isAvailable)
            .accessibilityLabel("System volume")
            .accessibilityValue(audioService.isAvailable ? "\(percentage) percent" : "Unavailable")

            Text(audioService.isAvailable ? "\(percentage)%" : "—")
                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(audioService.isAvailable ? 0.42 : 0.25))
                .frame(width: 24, alignment: .trailing)
        }
        .padding(.horizontal, 6)
        .frame(height: 28)
        .background {
            Capsule()
                .fill(Color.white.opacity(0.045))
                .overlay {
                    Capsule()
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                }
        }
        .help(audioService.isAvailable ? "System volume: \(percentage)%" : "System volume unavailable")
    }

    private var volumeIcon: String {
        switch audioService.volume {
        case 0: return "speaker.slash"
        case ..<0.34: return "speaker.wave.1.fill"
        case ..<0.67: return "speaker.wave.2.fill"
        default: return "speaker.wave.3.fill"
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
    @State private var isDropTargeted = false

    private var isSelected: Bool { store.selectedItemIDs.contains(item.id) }
    @State private var isDragging = false
    @State private var isDragActive = false

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
                .fill(
                    Color.white.opacity(
                        isSelected ? 0.12 : (isHovered || isDropTargeted ? 0.08 : 0.035)
                    )
                )
        }
        .scaleEffect(isHovered ? 1.015 : 1)
        .opacity(isDragging ? 0.15 : (isDragActive ? 0.52 : 1))
        .zIndex(isDragging ? 10 : 0)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onDrop(
            of: [LazyShelfDrag.type],
            delegate: ShelfReorderDropDelegate(
                targetID: item.id,
                store: store,
                isTargeted: $isDropTargeted
            )
        )
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
            return LazyShelfDrag.provider(for: item, itemIDs: store.draggedItemIDs)
        } preview: {
            ShelfDragPreview(item: item)
        }
        .onHover { isHovered = $0 }
        .onChange(of: store.draggedItemIDs) { _, draggedItemIDs in
            if draggedItemIDs.isEmpty {
                isDropTargeted = false
            }
            let dragging = draggedItemIDs.contains(item.id)
            let active = !draggedItemIDs.isEmpty

            if (dragging && !isDragging) || (active && !isDragActive) {
                DispatchQueue.main.async {
                    isDragging = dragging
                    isDragActive = active
                }
            } else {
                isDragging = dragging
                isDragActive = active
            }
        }
        .onAppear {
            isDragging = store.draggedItemIDs.contains(item.id)
            isDragActive = !store.draggedItemIDs.isEmpty
        }
        .animation(LazyNotchMotion.interactiveSpring, value: isHovered)
        .animation(LazyNotchMotion.interactiveSpring, value: isDragging)
        .animation(LazyNotchMotion.interactiveSpring, value: isDropTargeted)
        .animation(LazyNotchMotion.interactiveSpring, value: isDragActive)
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
        .accessibilityHint("Drag to reorder in Lazy Shelf or move the file to another app")
    }
}

private struct ShelfDragPreview: View {
    let item: LazyShelfItem

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
        .padding(6)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.92))
        }
    }
}

private struct ShelfReorderDropDelegate: DropDelegate {
    let targetID: UUID?
    let store: LazyShelfStore
    @Binding var isTargeted: Bool

    init(
        targetID: UUID?,
        store: LazyShelfStore,
        isTargeted: Binding<Bool> = .constant(false)
    ) {
        self.targetID = targetID
        self.store = store
        self._isTargeted = isTargeted
    }

    func dropEntered(info: DropInfo) {
        guard info.hasItemsConforming(to: [LazyShelfDrag.type]) else { return }
        isTargeted = targetID.map { !store.draggedItemIDs.contains($0) } ?? true
        withAnimation(LazyNotchMotion.interactiveSpring) {
            store.moveDraggedItems(over: targetID)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard info.hasItemsConforming(to: [LazyShelfDrag.type]) else { return nil }
        isTargeted = targetID.map { !store.draggedItemIDs.contains($0) } ?? true
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        store.endDragging()
        return true
    }
}

private struct ShelfExternalDropDelegate: DropDelegate {
    let store: LazyShelfStore
    @Binding var isTargeted: Bool

    func dropEntered(info: DropInfo) {
        isTargeted = acceptsExternalDrop(info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard acceptsExternalDrop(info) else {
            isTargeted = false
            return nil
        }
        isTargeted = true
        return DropProposal(operation: .copy)
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func performDrop(info: DropInfo) -> Bool {
        defer { isTargeted = false }
        guard acceptsExternalDrop(info) else { return false }

        let providers = info.itemProviders(for: [UTType.fileURL, UTType.item])
        loadFileURLs(from: providers) { urls in
            guard !urls.isEmpty else { return }
            withAnimation(LazyNotchMotion.interactiveSpring) {
                store.add(urls: urls)
            }
        }
        return true
    }

    private func acceptsExternalDrop(_ info: DropInfo) -> Bool {
        let types = [UTType.fileURL, UTType.item, LazyShelfDrag.type].filter {
            info.hasItemsConforming(to: [$0])
        }
        return LazyShelfDrag.acceptsExternalDrop(
            types: types,
            hasActiveShelfDrag: !store.draggedItemIDs.isEmpty
        )
    }
}

private struct ShelfThumbnail: View {
    let item: LazyShelfItem
    @Environment(\.displayScale) private var displayScale
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
                    scale: displayScale,
                    representationTypes: .all
                )
                thumbnail = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request).nsImage
            }
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
