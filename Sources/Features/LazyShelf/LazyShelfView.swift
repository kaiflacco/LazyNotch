import AppKit
import QuickLookThumbnailing
import SwiftUI
import UniformTypeIdentifiers

private enum ShelfTileMetrics {
    static let size: CGFloat = 80
    static let spacing: CGFloat = 8
    static let rowHeight: CGFloat = 96
    static let previewWidth: CGFloat = 68
    static let previewHeight: CGFloat = 38
}

/// The LazyShelf view inside LazyNotch.
/// Stages files for temporary holding, QuickLook inspection, and drag-and-drop into target apps.
public struct LazyShelfView: View {
    @ObservedObject var store = LazyShelfStore.shared
    @State private var isTargeted: Bool = false
    @State private var isAirDropHovered: Bool = false

    /// Process-wide guard: only one NSOpenPanel may be shown at a time.
    /// Static because @State copies wouldn't be visible inside the panel's completion closure.
    private static var isPanelActive = false

    public init() {}

    public var body: some View {
        VStack(spacing: 6) {
            if store.items.isEmpty {
                emptyDropTarget
            } else {
                stagedContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [UTType.fileURL.identifier, UTType.item.identifier], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    // MARK: - Add via File Picker

    /// Lets users stage files without dragging (the tray must be clickable, not drop-only).
    /// The notch is held open on the Tray for the whole picker session and briefly after,
    /// so it never hides while (or right after) the user is adding files.
    private func addFilesViaPanel() {
        // Only one picker at a time; ignore rapid double-clicks / misclicks.
        guard !LazyShelfView.isPanelActive else { return }
        LazyShelfView.isPanelActive = true

        NSApp.activate(ignoringOtherApps: true)
        // Keep the notch expanded while browsing the picker.
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
        panel.message = "Choose files or folders to stage in the Shelf"
        panel.begin { response in
            defer { LazyShelfView.isPanelActive = false }
            let urls = panel.urls
            if response == .OK, !urls.isEmpty {
                withAnimation(LazyNotchMotion.interactiveSpring) {
                    store.add(urls: urls)
                }
            }
            // Re-show the tray with the freshly staged items, then resume normal
            // hover behavior a few seconds later.
            NotificationCenter.default.post(
                name: NSNotification.Name("LazyNotchHoldOpenTrayRequest"),
                object: nil,
                userInfo: ["seconds": 6.0]
            )
        }
    }

    private func airDropStagedFiles() {
        let urls = store.items.map(\.url)
        guard !urls.isEmpty else { return }

        NSApp.activate(ignoringOtherApps: true)
        NSSharingService(named: .sendViaAirDrop)?.perform(withItems: urls)
    }

    // MARK: - Empty Drop Target

    private var emptyDropTarget: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isTargeted ? AnyShapeStyle(Color.lnAccentBlue.opacity(0.18)) : AnyShapeStyle(Color.white.opacity(0.07)))
                    .frame(width: 36, height: 36)

                Image(systemName: isTargeted ? "arrow.down.circle.fill" : "tray.and.arrow.down.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isTargeted ? AnyShapeStyle(Color.lnAccentBlue) : AnyShapeStyle(Color.white.opacity(0.62)))
                    .scaleEffect(isTargeted ? 1.08 : 1.0)
            }
            .animation(LazyNotchMotion.interactiveSpring, value: isTargeted)

            VStack(spacing: 2) {
                Text(isTargeted ? "Release to stage files" : "Drop files here")
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.86))

                Text("Files stay ready to preview, drag, or open")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.38))
            }

            Button {
                addFilesViaPanel()
            } label: {
                Label("Add Files", systemImage: "plus")
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(isTargeted ? Color.white.opacity(0.18) : Color.white.opacity(0.10)))
                    .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.7))
            }
            .buttonStyle(.plain)
            .help("Choose files or folders to stage")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isTargeted ? Color.black.opacity(0.80) : Color.white.opacity(0.035))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            AnyShapeStyle(isTargeted ? Color.lnAccentBlue.opacity(0.85) : Color.white.opacity(0.13)),
                            style: StrokeStyle(lineWidth: isTargeted ? 1.5 : 1, dash: [6, 4])
                        )
                }
        }
        .animation(LazyNotchMotion.interactiveSpring, value: isTargeted)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .help("Click to browse for files, or drop them here")
    }

    // MARK: - Staged Content List

    private var stagedContent: some View {
        GeometryReader { proxy in
            let tileCount = store.items.count + 2 // AirDrop + staged files + Add
            let rowWidth = CGFloat(tileCount) * ShelfTileMetrics.size
                + CGFloat(tileCount - 1) * ShelfTileMetrics.spacing
            let contentWidth = min(rowWidth, proxy.size.width)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    Text("Staged files")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.86))
                    Text(store.items.count == 1 ? "1 item ready" : "\(store.items.count) items ready")
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.40))

                    Spacer(minLength: 0)

                    Button {
                        withAnimation(LazyNotchMotion.interactiveSpring) {
                            store.clearAll()
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.48))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.white.opacity(0.055)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear all files")
                    .help("Clear all files")
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: ShelfTileMetrics.spacing) {
                        airDropTile

                        ForEach(store.items) { item in
                            StagedItemCard(item: item)
                        }

                        miniDropSlot
                    }
                    .frame(height: ShelfTileMetrics.rowHeight, alignment: .topLeading)
                }
                .frame(width: contentWidth, height: ShelfTileMetrics.rowHeight, alignment: .topLeading)
            }
            .frame(width: contentWidth, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var airDropTile: some View {
        Button {
            airDropStagedFiles()
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    // A restrained blue halo gives AirDrop the same lifted feel as a cover.
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color.lnAccentBlue.opacity(isAirDropHovered ? 0.28 : 0.16))
                        .blur(radius: isAirDropHovered ? 10 : 7)
                        .padding(4)

                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color.lnAccentBlue.opacity(isAirDropHovered ? 0.15 : 0.10))
                        .overlay {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(Color.lnAccentBlue.opacity(isAirDropHovered ? 0.40 : 0.24), lineWidth: 0.8)
                        }

                    AirDropGlyph(color: Color.lnAccentBlue)
                        .frame(width: 24, height: 24)
                }
                .frame(width: ShelfTileMetrics.size, height: ShelfTileMetrics.size)
                .shadow(
                    color: Color.lnAccentBlue.opacity(isAirDropHovered ? 0.28 : 0.14),
                    radius: isAirDropHovered ? 9 : 5
                )

                Text("AirDrop")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.62))
            }
            .frame(width: ShelfTileMetrics.size, alignment: .top)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(LazyNotchMotion.interactiveSpring) {
                isAirDropHovered = hovering
            }
        }
        .help("Send all staged files with AirDrop")
        .accessibilityLabel("AirDrop staged files")
    }

    private var miniDropSlot: some View {
        Button {
            addFilesViaPanel()
        } label: {
            VStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.white.opacity(isTargeted ? 0.08 : 0.03))
                    .overlay {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(
                                AnyShapeStyle(isTargeted ? Color.lnAccentBlue.opacity(0.72) : Color.white.opacity(0.10)),
                                style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                            )
                    }
                    .overlay {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isTargeted ? AnyShapeStyle(Color.lnAccentBlue) : AnyShapeStyle(Color.white.opacity(0.32)))
                    }
                    .frame(width: ShelfTileMetrics.size, height: ShelfTileMetrics.size)

                Text("Add")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.48))
            }
            .frame(width: ShelfTileMetrics.size, alignment: .top)
        }
        .buttonStyle(.plain)
        .help("Add files from disk")
    }

    // MARK: - Drop Handling

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var foundURLs: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                // Finder drags reliably expose public.file-url as raw data;
                // loadObject(ofClass: URL.self) is flaky with them.
                _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                    if let data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        DispatchQueue.main.async {
                            foundURLs.append(url)
                            group.leave()
                        }
                    } else {
                        group.leave()
                    }
                }
            } else {
                // Fallback for providers that expose a URL object (e.g. link drags).
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url {
                        DispatchQueue.main.async {
                            foundURLs.append(url)
                            group.leave()
                        }
                    } else {
                        group.leave()
                    }
                }
            }
        }

        group.notify(queue: .main) {
            if !foundURLs.isEmpty {
                withAnimation(LazyNotchMotion.interactiveSpring) {
                    store.add(urls: foundURLs)
                }
            }
        }
        return true
    }
}

// MARK: - Staged Item Card with Drag-Out & QuickLook

struct StagedItemCard: View {
    let item: LazyShelfItem
    @ObservedObject var store = LazyShelfStore.shared
    @State private var isHovered = false
    @State private var thumbnail: NSImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.white.opacity(0.04))

                    if let thumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: ShelfTileMetrics.previewWidth, height: ShelfTileMetrics.previewHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else {
                        Image(nsImage: item.icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 30, height: 30)
                    }
                }
                .frame(width: ShelfTileMetrics.previewWidth, height: ShelfTileMetrics.previewHeight)

                Text(item.name)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(width: 70)

                Text(item.sizeString)
                    .font(.system(size: 9))
                    .foregroundStyle(Color.white.opacity(0.42))
            }
            .frame(width: ShelfTileMetrics.size, height: ShelfTileMetrics.size)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.white.opacity(isHovered ? 0.10 : 0.055))
                    .overlay {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(Color.white.opacity(isHovered ? 0.18 : 0.07), lineWidth: 0.8)
                    }
            )
            .animation(LazyNotchMotion.interactiveSpring, value: isHovered)
            // Drag-out support: drag this card straight out into Finder or any application!
            .onDrag {
                if let provider = NSItemProvider(contentsOf: item.url) {
                    return provider
                }
                return NSItemProvider(object: item.url as NSURL)
            }
            // Single click opens the QuickLook preview.
            .onTapGesture {
                store.showQuickLook(for: item)
            }
            .contextMenu {
                Button("Open") {
                    NSWorkspace.shared.open(item.url)
                }
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([item.url])
                }
                Button("AirDrop") {
                    NSSharingService(named: .sendViaAirDrop)?.perform(withItems: [item.url])
                }
                Divider()
                Button("Remove from Shelf", role: .destructive) {
                    withAnimation(LazyNotchMotion.interactiveSpring) {
                        store.remove(item: item)
                    }
                }
            }

            if isHovered {
                Button {
                    withAnimation(LazyNotchMotion.interactiveSpring) {
                        store.remove(item: item)
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(Color.black.opacity(0.75)))
                }
                .buttonStyle(.plain)
                .padding(4)
                .transition(.opacity)
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear(perform: loadThumbnail)
    }

    private func loadThumbnail() {
        let request = QLThumbnailGenerator.Request(
            fileAt: item.url,
            size: CGSize(width: 136, height: 76),
            scale: 2,
            representationTypes: .thumbnail
        )

        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
            guard let image = representation?.nsImage else { return }
            DispatchQueue.main.async {
                thumbnail = image
            }
        }
    }
}

private struct AirDropGlyph: View {
    let color: Color

    var body: some View {
        ZStack {
            ForEach([12.0, 18.0, 24.0], id: \.self) { diameter in
                Circle()
                    .trim(from: 0.13, to: 0.87)
                    .stroke(color, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    .frame(width: diameter, height: diameter)
                    .rotationEffect(.degrees(90))
            }

            Circle()
                .fill(color)
                .frame(width: 4.5, height: 4.5)
        }
    }
}
