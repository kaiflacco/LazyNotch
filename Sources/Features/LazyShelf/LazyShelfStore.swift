import AppKit
import Foundation
import QuickLookUI

/// Shared store managing files staged in LazyShelf.
@MainActor
public final class LazyShelfStore: NSObject, ObservableObject {
    public static let shared = LazyShelfStore()

    private let persistenceKey = "LazyShelfStagedPaths"

    @Published public var items: [LazyShelfItem] = []
    @Published public var previewItemURL: URL?

    public override init() {
        super.init()
        loadPersistedItems()
    }

    public func add(urls: [URL]) {
        var updated = items
        for url in urls {
            // Avoid immediate duplicate additions
            if !updated.contains(where: { $0.url.path == url.path }) {
                updated.insert(LazyShelfItem(url: url), at: 0)
            }
        }
        items = updated
        persistItems()
    }

    public func remove(item: LazyShelfItem) {
        items.removeAll { $0.id == item.id }
        persistItems()
        if previewItemURL == item.url {
            closeQuickLook()
        }
    }

    public func clearAll() {
        items.removeAll()
        persistItems()
        closeQuickLook()
    }

    private func persistItems() {
        let paths = items.map { $0.url.path }
        UserDefaults.standard.set(paths, forKey: persistenceKey)
    }

    private func loadPersistedItems() {
        guard let paths = UserDefaults.standard.stringArray(forKey: persistenceKey) else { return }
        var loaded: [LazyShelfItem] = []
        for path in paths {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: path) {
                loaded.append(LazyShelfItem(url: url))
            }
        }
        self.items = loaded
    }

    // MARK: - QuickLook Preview Integration

    public func showQuickLook(for item: LazyShelfItem) {
        previewItemURL = item.url
        NSApp.activate(ignoringOtherApps: true)
        guard let panel = QLPreviewPanel.shared() else { return }
        panel.dataSource = self
        panel.delegate = self
        panel.makeKeyAndOrderFront(nil)
    }

    public func closeQuickLook() {
        previewItemURL = nil
        if let panel = QLPreviewPanel.shared(), panel.isVisible {
            panel.orderOut(nil)
        }
    }
}

// MARK: - QLPreviewPanel DataSource & Delegate

extension LazyShelfStore: @preconcurrency QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    @MainActor
    public func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        previewItemURL != nil ? 1 : 0
    }

    @MainActor
    public func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        previewItemURL as (any QLPreviewItem)?
    }
}
