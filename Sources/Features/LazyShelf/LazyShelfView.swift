import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The LazyShelf tray view inside LazyNotch.
/// Stages files for temporary holding, QuickLook inspection, and drag-and-drop into target apps.
public struct LazyShelfView: View {
    @ObservedObject var store = LazyShelfStore.shared
    @State private var isTargeted: Bool = false

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
        panel.message = "Choose files or folders to stage in the Tray"
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

    // MARK: - Empty Drop Target

    // MARK: - Empty Drop Target

    private var emptyDropTarget: some View {
        ZStack {
            // Ambient glow when targeted
            if isTargeted {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(SiriColors.horizontalGradient)
                    .blur(radius: 12)
                    .opacity(0.25)
            }

            // Card background
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    isTargeted
                        ? Color.black.opacity(0.82)
                        : Color.white.opacity(0.035)
                )

            // Dashed border
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    isTargeted
                        ? AnyShapeStyle(SiriColors.horizontalGradient)
                        : AnyShapeStyle(Color.white.opacity(0.12)),
                    style: StrokeStyle(
                        lineWidth: isTargeted ? 1.6 : 1.0,
                        dash: [6, 4]
                    )
                )
                .animation(LazyNotchMotion.interactiveSpring, value: isTargeted)

            VStack(spacing: 8) {
                // Icon with halo
                ZStack {
                    Circle()
                        .fill(
                            isTargeted
                                ? AnyShapeStyle(SiriColors.fullGradient.opacity(0.24))
                                : AnyShapeStyle(Color.white.opacity(0.06))
                        )
                        .frame(width: 42, height: 42)
                        .scaleEffect(isTargeted ? 1.08 : 1.0)

                    Image(systemName: isTargeted ? "arrow.down.circle.fill" : "tray.and.arrow.down.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(
                            isTargeted
                                ? AnyShapeStyle(SiriColors.horizontalGradient)
                                : AnyShapeStyle(Color.white.opacity(0.55))
                        )
                        .scaleEffect(isTargeted ? 1.10 : 1.0)
                }
                .animation(LazyNotchMotion.interactiveSpring, value: isTargeted)

                VStack(spacing: 2) {
                    Text(isTargeted ? "Release to Stage Files" : "Drop files or click to browse")
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            isTargeted ? Color.white : Color.white.opacity(0.60)
                        )

                    if !isTargeted {
                        Text("Instant staging • QuickLook • Drag anywhere")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.32))
                    }
                }
                .animation(LazyNotchMotion.interactiveSpring, value: isTargeted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            addFilesViaPanel()
        }
        .padding(.bottom, 6)
        .help("Click to browse for files, or drop them here")
    }

    // MARK: - Staged Content List

    private var stagedContent: some View {
        VStack(spacing: 4) {
            // Header bar with count and Clear All
            HStack {
                HStack(spacing: 5) {
                    Text("\(store.items.count)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(minWidth: 16, minHeight: 16)
                        .padding(.horizontal, 5)
                        .background(
                            Capsule().fill(SiriColors.horizontalGradient)
                        )

                    Text(store.items.count == 1 ? "item staged" : "items staged")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.45))
                }

                Spacer()

                Button("Clear All") {
                    withAnimation(LazyNotchMotion.interactiveSpring) {
                        store.clearAll()
                    }
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.40))
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 2)

            // Scrollable row of staged items
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.items) { item in
                        StagedItemCard(item: item)
                    }

                    // Mini drop addition slot
                    miniDropSlot
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var miniDropSlot: some View {
        Button {
            addFilesViaPanel()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(isTargeted ? 0.10 : 0.04))
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isTargeted
                            ? AnyShapeStyle(SiriColors.horizontalGradient)
                            : AnyShapeStyle(Color.white.opacity(0.12)),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                    )
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isTargeted ? AnyShapeStyle(SiriColors.horizontalGradient) : AnyShapeStyle(Color.white.opacity(0.4)))
            }
            .frame(width: 60, height: 72)
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
                        }
                    }
                    group.leave()
                }
            } else {
                // Fallback for providers that expose a URL object (e.g. link drags).
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url {
                        DispatchQueue.main.async {
                            foundURLs.append(url)
                        }
                    }
                    group.leave()
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

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 4) {
                Image(nsImage: item.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 34, height: 34)

                Text(item.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(width: 68)

                Text(item.sizeString)
                    .font(.system(size: 9.5))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            .frame(width: 78, height: 74)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(isHovered ? 0.14 : 0.07))
                    .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(isHovered ? 0.22 : 0.08), lineWidth: 0.8)
                    )
            )
            .scaleEffect(isHovered ? 1.03 : 1.0)
            .animation(LazyNotchMotion.interactiveSpring, value: isHovered)
            // Drag-out support: drag this card straight out into Finder or any application!
            .onDrag {
                if let provider = NSItemProvider(contentsOf: item.url) {
                    return provider
                }
                return NSItemProvider(object: item.url as NSURL)
            }
            // Single click (or double click) opens the QuickLook preview
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
                Button("Remove from Tray", role: .destructive) {
                    withAnimation(LazyNotchMotion.interactiveSpring) {
                        store.remove(item: item)
                    }
                }
            }

            // Quick hover actions: Preview (eye) and Remove (x)
            if isHovered {
                HStack(spacing: 3) {
                    Button {
                        store.showQuickLook(for: item)
                    } label: {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 8.5))
                            .foregroundStyle(.white)
                            .frame(width: 16, height: 16)
                            .background(Circle().fill(Color.black.opacity(0.75)))
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        NSSharingService(named: .sendViaAirDrop)?.perform(withItems: [item.url])
                    } label: {
                        Image(systemName: "airdrop")
                            .font(.system(size: 8.5))
                            .foregroundStyle(.white)
                            .frame(width: 16, height: 16)
                            .background(Circle().fill(Color.black.opacity(0.75)))
                    }
                    .buttonStyle(.plain)

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
                }
                .padding(4)
                .transition(.opacity)
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
