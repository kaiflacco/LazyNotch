import AppKit
import Foundation
import QuickLookUI

/// Shared store managing files staged in LazyShelf.
@MainActor
public final class LazyShelfStore: NSObject, ObservableObject {
    public static let shared = LazyShelfStore()

    public enum AirDropState: Equatable {
        case idle
        case opening
        case opened
        case failure
    }

    private let persistenceKey: String
    private let defaults: UserDefaults
    private let airDropHandler: @MainActor ([URL]) -> Bool
    private var airDropGeneration = UUID()

    @Published public var items: [LazyShelfItem] = []
    @Published public var previewItemURL: URL?
    @Published public private(set) var selectedItemIDs: Set<UUID> = []
    @Published public private(set) var focusedItemID: UUID?
    @Published public private(set) var draggedItemIDs: [UUID] = []
    @Published public private(set) var airDropState: AirDropState = .idle

    private var selectionAnchorID: UUID?

    public override init() {
        self.persistenceKey = "LazyShelfStagedPaths"
        self.defaults = .standard
        self.airDropHandler = Self.performNativeAirDrop
        super.init()
        loadPersistedItems()
    }

    init(
        defaults: UserDefaults,
        persistenceKey: String = "LazyShelfStagedPaths",
        airDropHandler: @escaping @MainActor ([URL]) -> Bool
    ) {
        self.persistenceKey = persistenceKey
        self.defaults = defaults
        self.airDropHandler = airDropHandler
        super.init()
        loadPersistedItems()
    }

    public static func validStoredPaths(_ paths: [String], fileManager: FileManager = .default) -> [String] {
        paths.filter { fileManager.fileExists(atPath: $0) }
    }

    public func add(urls: [URL]) {
        var updated = items
        for url in urls.reversed() {
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
        selectedItemIDs.remove(item.id)
        draggedItemIDs.removeAll { $0 == item.id }
        if focusedItemID == item.id {
            focusedItemID = items.first?.id
        }
        if selectionAnchorID == item.id {
            selectionAnchorID = nil
        }
        persistItems()
        if previewItemURL == item.url {
            closeQuickLook()
        }
    }

    public func clearAll() {
        items.removeAll()
        clearSelection()
        focusedItemID = nil
        draggedItemIDs = []
        persistItems()
        closeQuickLook()
    }

    public func focus(_ item: LazyShelfItem) {
        focusedItemID = item.id
    }

    public func moveFocus(by offset: Int) {
        guard !items.isEmpty else { return }
        let current = focusedItemID.flatMap { id in items.firstIndex { $0.id == id } }
        let index = min(max((current ?? (offset > 0 ? -1 : items.count)) + offset, 0), items.count - 1)
        focusedItemID = items[index].id
    }

    public func toggleSelection(of item: LazyShelfItem, extendingRange: Bool) {
        guard let itemIndex = items.firstIndex(where: { $0.id == item.id }) else { return }

        if extendingRange,
           let anchorID = selectionAnchorID,
           let anchorIndex = items.firstIndex(where: { $0.id == anchorID }) {
            let range = min(anchorIndex, itemIndex)...max(anchorIndex, itemIndex)
            selectedItemIDs.formUnion(range.map { items[$0].id })
        } else {
            if selectedItemIDs.contains(item.id) {
                selectedItemIDs.remove(item.id)
            } else {
                selectedItemIDs.insert(item.id)
            }
            selectionAnchorID = item.id
        }
    }

    public func selectAll() {
        selectedItemIDs = Set(items.map(\.id))
        selectionAnchorID = focusedItemID ?? items.first?.id
    }

    public func clearSelection() {
        selectedItemIDs.removeAll()
        selectionAnchorID = nil
    }

    public func selectOnly(_ item: LazyShelfItem) {
        guard items.contains(where: { $0.id == item.id }) else { return }
        selectedItemIDs = [item.id]
        selectionAnchorID = item.id
        focusedItemID = item.id
    }

    public func beginDragging(_ item: LazyShelfItem) {
        if selectedItemIDs.contains(item.id) {
            draggedItemIDs = items.map(\.id).filter(selectedItemIDs.contains)
        } else {
            selectOnly(item)
            draggedItemIDs = [item.id]
        }
    }

    public func endDragging() {
        draggedItemIDs = []
    }

    public func moveDraggedItems(before targetID: UUID?, afterTarget: Bool = false) {
        moveItems(draggedItemIDs, before: targetID, afterTarget: afterTarget)
    }

    private func moveItems(_ itemIDs: [UUID], before targetID: UUID?, afterTarget: Bool = false) {
        let movingIDs = Set(itemIDs)
        guard !movingIDs.isEmpty else { return }
        if let targetID, movingIDs.contains(targetID) { return }

        let movingItems = items.filter { movingIDs.contains($0.id) }
        var remaining = items.filter { !movingIDs.contains($0.id) }
        let targetIndex: Int
        if let targetID {
            guard let index = remaining.firstIndex(where: { $0.id == targetID }) else { return }
            targetIndex = afterTarget ? index + 1 : index
        } else {
            targetIndex = remaining.endIndex
        }
        remaining.insert(contentsOf: movingItems, at: targetIndex)
        guard remaining != items else { return }
        items = remaining
        persistItems()
    }

    public func moveDraggedItems(after targetID: UUID?) {
        moveDraggedItems(before: targetID, afterTarget: true)
    }

    public func moveDraggedItems(over targetID: UUID?) {
        moveItems(draggedItemIDs, over: targetID)
    }

    public func moveItems(_ itemIDs: [UUID], over targetID: UUID?) {
        guard let targetID else {
            moveItems(itemIDs, before: nil)
            return
        }

        let movingIDs = Set(itemIDs)
        guard !movingIDs.contains(targetID),
              let targetIndex = items.firstIndex(where: { $0.id == targetID }),
              let firstMovingIndex = items.firstIndex(where: { movingIDs.contains($0.id) }),
              let lastMovingIndex = items.lastIndex(where: { movingIDs.contains($0.id) }) else { return }

        if targetIndex < firstMovingIndex {
            moveItems(itemIDs, before: targetID)
        } else if targetIndex > lastMovingIndex {
            moveItems(itemIDs, before: targetID, afterTarget: true)
        }
    }

    @discardableResult
    public func sendAllViaAirDrop() -> Bool {
        sendViaAirDrop(items.map(\.url))
    }

    @discardableResult
    public func sendDraggedItemsViaAirDrop() -> Bool {
        let dragged = draggedItemIDs.isEmpty ? selectedItemIDs : Set(draggedItemIDs)
        return sendViaAirDrop(items.filter { dragged.contains($0.id) }.map(\.url))
    }

    @discardableResult
    public func sendSelectedItemsViaAirDrop() -> Bool {
        sendViaAirDrop(items.filter { selectedItemIDs.contains($0.id) }.map(\.url))
    }

    @discardableResult
    public func sendItemsViaAirDrop(_ itemIDs: [UUID]) -> Bool {
        let itemIDs = Set(itemIDs)
        return sendViaAirDrop(items.filter { itemIDs.contains($0.id) }.map(\.url))
    }

    @discardableResult
    public func sendViaAirDrop(_ urls: [URL]) -> Bool {
        guard !urls.isEmpty else { return false }
        let generation = UUID()
        airDropGeneration = generation
        airDropState = .opening
        let succeeded = airDropHandler(urls)

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard let self, self.airDropGeneration == generation else { return }
            self.airDropState = succeeded ? .opened : .failure
            try? await Task.sleep(for: .seconds(1.2))
            guard self.airDropGeneration == generation else { return }
            self.airDropState = .idle
        }
        return succeeded
    }

    public func toggleQuickLookForFocusedItem() {
        guard let focusedItemID,
              let item = items.first(where: { $0.id == focusedItemID }) else { return }
        if previewItemURL == item.url {
            closeQuickLook()
        } else {
            showQuickLook(for: item)
        }
    }

    private func persistItems() {
        let paths = items.map { $0.url.path }
        defaults.set(paths, forKey: persistenceKey)
    }

    private func loadPersistedItems() {
        guard let paths = defaults.stringArray(forKey: persistenceKey) else { return }
        var loaded: [LazyShelfItem] = []
        for path in Self.validStoredPaths(paths) {
            let url = URL(fileURLWithPath: path)
            loaded.append(LazyShelfItem(url: url))
        }
        self.items = loaded
    }

    private static func performNativeAirDrop(_ urls: [URL]) -> Bool {
        guard let service = NSSharingService(named: .sendViaAirDrop),
              service.canPerform(withItems: urls) else { return false }
        service.perform(withItems: urls)
        return true
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
