import AppKit
import UniformTypeIdentifiers
import XCTest
@testable import LazyNotch

@MainActor
final class ShellViewModelTests: XCTestCase {
    func testOpeningShelfSelectsShelfAndExpands() {
        let viewModel = ShellViewModel()
        viewModel.isMediaCoverHovered = true

        viewModel.openShelf()

        XCTAssertTrue(viewModel.isExpanded)
        XCTAssertEqual(viewModel.activeTab, .shelf)
        XCTAssertFalse(viewModel.showsCodexDetails)
        XCTAssertFalse(viewModel.isMediaCoverHovered)
    }

    func testCodexDetailsAlwaysUsesHomeAndToggles() {
        let viewModel = ShellViewModel()
        viewModel.openShelf()

        viewModel.toggleCodexDetails()
        XCTAssertEqual(viewModel.activeTab, .home)
        XCTAssertTrue(viewModel.showsCodexDetails)

        viewModel.toggleCodexDetails()
        XCTAssertFalse(viewModel.showsCodexDetails)
    }

    func testMediaDisplayTextFallsBackWithoutChangingTrackData() {
        let track = MediaTrack(
            title: "  ",
            artist: "\n",
            album: "",
            isPlaying: false,
            duration: 0,
            elapsedTime: 0
        )

        XCTAssertEqual(track.displayTitle, "Nothing Playing")
        XCTAssertEqual(track.displayArtist, "Open a media app")
        XCTAssertEqual(track.title, "  ")
    }

    func testPlayingBackgroundBrowserIsProbedWhenSpotifyIsMediaRemoteSource() {
        let runningBundleIdentifiers: Set<String> = [
            "com.google.Chrome",
            "com.spotify.client"
        ]

        XCTAssertTrue(
            MediaService.shouldProbeBrowsers(
                frontmostBundleIdentifier: "com.google.antigravity",
                remoteBundleIdentifier: "com.spotify.client",
                runningBundleIdentifiers: runningBundleIdentifiers
            )
        )
        XCTAssertEqual(
            MediaService.prioritizedMediaBundleIdentifiers(
                frontmostBundleIdentifier: "com.google.antigravity",
                runningBundleIdentifiers: runningBundleIdentifiers
            ),
            ["com.google.Chrome", "com.spotify.client"]
        )
    }

    func testCalendarEventsGroupByLocalDayAndStayChronological() {
        let day = Calendar.current.startOfDay(for: Date())
        let later = UpcomingCalendarEvent(
            title: "Later",
            startDate: day.addingTimeInterval(7200),
            endDate: day.addingTimeInterval(10800),
            isAllDay: false
        )
        let earlier = UpcomingCalendarEvent(
            title: "Earlier",
            startDate: day.addingTimeInterval(3600),
            endDate: day.addingTimeInterval(5400),
            isAllDay: false
        )

        let grouped = CalendarService.groupedEvents([later, earlier])

        XCTAssertEqual(grouped[CalendarService.dayKey(for: day)]?.map(\.title), ["Earlier", "Later"])
    }

    func testCalendarEventIndicatorRequiresCurrentPermission() {
        let event = UpcomingCalendarEvent(
            title: "Planning",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            isAllDay: false
        )

        XCTAssertTrue(CalendarService.hasEventIndicator(hasPermission: true, events: [event]))
        XCTAssertFalse(CalendarService.hasEventIndicator(hasPermission: false, events: [event]))
    }

    func testShelfPersistenceDropsMissingPaths() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }

        let existing = directory.appendingPathComponent("kept.txt")
        try Data("kept".utf8).write(to: existing)
        let missing = directory.appendingPathComponent("gone.txt")

        XCTAssertEqual(
            LazyShelfStore.validStoredPaths([existing.path, missing.path]),
            [existing.path]
        )
    }

    func testShelfQueueSelectionReorderingAndAirDropPayloads() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }

        let urls = ["one.txt", "two.txt", "three.txt"].map { directory.appendingPathComponent($0) }
        for url in urls {
            try Data(url.lastPathComponent.utf8).write(to: url)
        }

        let suiteName = "LazyShelfTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var sentURLs: [URL] = []
        let store = LazyShelfStore(defaults: defaults) { urls in
            sentURLs = urls
            return true
        }

        store.add(urls: urls)
        XCTAssertEqual(store.items.map(\.url), urls)

        store.focus(store.items[0])
        let focusedID = store.focusedItemID
        store.toggleSelection(of: store.items[1], extendingRange: false)
        XCTAssertEqual(store.focusedItemID, focusedID)
        store.toggleSelection(of: store.items[2], extendingRange: true)
        XCTAssertEqual(store.selectedItemIDs, Set(store.items[1...2].map(\.id)))

        store.beginDragging(store.items[1])
        XCTAssertTrue(store.sendDraggedItemsViaAirDrop())
        XCTAssertEqual(sentURLs, Array(urls[1...2]))

        store.moveDraggedItems(before: store.items[0].id)
        XCTAssertEqual(store.items.map(\.url), [urls[1], urls[2], urls[0]])

        store.moveDraggedItems(before: nil)
        XCTAssertEqual(store.items.map(\.url), [urls[0], urls[1], urls[2]])

        store.moveDraggedItems(before: store.items[0].id)
        XCTAssertEqual(store.items.map(\.url), [urls[1], urls[2], urls[0]])

        let restored = LazyShelfStore(defaults: defaults) { _ in true }
        XCTAssertEqual(restored.items.map(\.url), [urls[1], urls[2], urls[0]])
        XCTAssertTrue(restored.selectedItemIDs.isEmpty)

        XCTAssertTrue(store.sendAllViaAirDrop())
        XCTAssertEqual(sentURLs, [urls[1], urls[2], urls[0]])
    }

    func testShelfSingleSelectionReplacesSelectionAndAirDropsSelectedItems() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }

        let urls = ["one.txt", "two.txt"].map { directory.appendingPathComponent($0) }
        for url in urls {
            try Data(url.lastPathComponent.utf8).write(to: url)
        }

        let suiteName = "LazyShelfSelectionTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var sentURLs: [URL] = []
        let store = LazyShelfStore(defaults: defaults) { urls in
            sentURLs = urls
            return true
        }

        store.add(urls: urls)
        store.selectOnly(store.items[0])
        XCTAssertEqual(store.selectedItemIDs, [store.items[0].id])

        store.selectOnly(store.items[1])
        XCTAssertEqual(store.selectedItemIDs, [store.items[1].id])
        XCTAssertTrue(store.sendSelectedItemsViaAirDrop())
        XCTAssertEqual(sentURLs, [urls[1]])
    }

    func testShelfAirDropReportsShareSheetOpenedWithoutClaimingDelivery() async throws {
        let suiteName = "LazyShelfAirDropStatusTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = LazyShelfStore(defaults: defaults) { _ in true }
        let url = URL(fileURLWithPath: "/tmp/example.txt")

        XCTAssertTrue(store.sendViaAirDrop([url]))
        XCTAssertEqual(store.airDropState, .opening)

        try await Task.sleep(for: .milliseconds(400))

        XCTAssertEqual(store.airDropState, .opened)
    }

    func testShelfDraggingOverItemsMovesInTheDragDirection() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }

        let urls = ["one.txt", "two.txt", "three.txt"].map { directory.appendingPathComponent($0) }
        for url in urls {
            try Data(url.lastPathComponent.utf8).write(to: url)
        }

        let suiteName = "LazyShelfReorderTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = LazyShelfStore(defaults: defaults) { _ in true }

        store.add(urls: urls)
        store.beginDragging(store.items[0])
        store.moveDraggedItems(over: store.items[1].id)

        XCTAssertEqual(store.items.map(\.url), [urls[1], urls[0], urls[2]])

        store.endDragging()
        store.beginDragging(store.items[2])
        store.moveDraggedItems(over: store.items[0].id)

        XCTAssertEqual(store.items.map(\.url), [urls[2], urls[1], urls[0]])
    }

    func testCodexUsageWindowClampsRemainingPercent() {
        let window = CodexUsageService.parseWindow([
            "usedPercent": 125,
            "resetsAt": 1_700_000_000,
            "windowDurationMins": 300
        ])

        XCTAssertEqual(window?.remainingPercent, 0)
        XCTAssertEqual(window?.durationMinutes, 300)
        XCTAssertEqual(window?.resetsAt, Date(timeIntervalSince1970: 1_700_000_000))
    }

    func testCodexUsageStateUsesUnavailableWhenUsageCannotBeRead() {
        XCTAssertEqual(CodexUsageState.loading.displayLabel, "Loading")
        XCTAssertEqual(CodexUsageState.unavailable.displayLabel, "Unavailable")
    }

    func testCollapsedLiveActivityHitRegionReachesHostingView() {
        let viewModel = ShellViewModel()
        viewModel.compactSize = CGSize(width: 200, height: 32)
        viewModel.hasActiveLiveActivity = true

        let hostingView = ShellHostingView(rootView: ShellContentView(viewModel: viewModel))
        hostingView.viewModel = viewModel
        hostingView.frame = NSRect(x: 0, y: 0, width: 770, height: 380)
        hostingView.layoutSubtreeIfNeeded()

        XCTAssertTrue(hostingView.isFlipped)
        XCTAssertEqual(hostingView.bounds.size, CGSize(width: 770, height: 380))
        XCTAssertTrue(viewModel.isActivityContentVisible)
        let bottomOriginClickPoint = NSPoint(
            x: hostingView.bounds.midX,
            y: hostingView.bounds.maxY - 16
        )
        XCTAssertNotNil(hostingView.hitTest(bottomOriginClickPoint))
    }

    func testExpandedShelfHitRegionUsesHostingViewCoordinates() {
        let viewModel = ShellViewModel()
        viewModel.openShelf()

        let hostingView = ShellHostingView(rootView: ShellContentView(viewModel: viewModel))
        hostingView.viewModel = viewModel
        hostingView.frame = NSRect(x: 0, y: 0, width: 770, height: 380)
        hostingView.layoutSubtreeIfNeeded()

        let bottomOriginShelfPoint = NSPoint(
            x: hostingView.bounds.midX,
            y: hostingView.bounds.maxY - 100
        )

        XCTAssertNotNil(hostingView.hitTest(bottomOriginShelfPoint))
    }

    func testShellHostingViewDoesNotClaimInternalShelfDrags() {
        let internalTypes: [NSPasteboard.PasteboardType] = [
            .init("com.lazynotch.shelf-items"),
            .fileURL
        ]
        let hostingView = ShellHostingView(rootView: ShellContentView(viewModel: ShellViewModel()))

        XCTAssertTrue(ShellHostingView.isInternalShelfDrag(internalTypes))
        XCTAssertFalse(ShellHostingView.isInternalShelfDrag([NSPasteboard.PasteboardType.fileURL]))
        XCTAssertTrue(ShellHostingView.isExternalFileDrag([.fileURL]))
        XCTAssertFalse(ShellHostingView.isExternalFileDrag(internalTypes))
        XCTAssertTrue(ShellHostingView.isInternalShelfDrag([.fileURL], sourceIsInsideShell: true))
        XCTAssertFalse(ShellHostingView.isExternalFileDrag([.fileURL], sourceIsInsideShell: true))
        XCTAssertTrue(ShellHostingView.isInternalShelfDrag([.fileURL], hasActiveShelfDrag: true))
        XCTAssertFalse(ShellHostingView.isExternalFileDrag([.fileURL], hasActiveShelfDrag: true))
        XCTAssertTrue(hostingView.registeredDraggedTypes.contains(.init(LazyShelfDrag.type.identifier)))
        XCTAssertTrue(hostingView.registeredDraggedTypes.contains(.fileURL))
    }

    func testExpandedShellDefersShelfDropsToSwiftUI() {
        XCTAssertTrue(ShellHostingView.shouldDeferDropToSwiftUI(isExpanded: true))
        XCTAssertFalse(ShellHostingView.shouldDeferDropToSwiftUI(isExpanded: false))
    }

    func testShelfDragPasteboardCarriesSelectedItemsAndFileURL() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }

        let urls = ["one.txt", "two.txt"].map { directory.appendingPathComponent($0) }
        for url in urls {
            try Data(url.lastPathComponent.utf8).write(to: url)
        }

        let suiteName = "LazyShelfDragPayloadTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = LazyShelfStore(defaults: defaults) { _ in true }
        store.add(urls: urls)
        store.selectAll()

        let item = store.items[0]
        store.beginDragging(item)
        let pasteboardItem = LazyShelfDrag.pasteboardItem(
            for: item.url,
            itemIDs: store.draggedItemIDs
        )

        XCTAssertEqual(store.draggedItemIDs, store.items.map(\.id))
        XCTAssertTrue(pasteboardItem.types.contains(.fileURL))
        XCTAssertTrue(pasteboardItem.types.contains(.string))
        XCTAssertTrue(
            pasteboardItem.types.contains(
                NSPasteboard.PasteboardType(LazyShelfDrag.type.identifier)
            )
        )
        XCTAssertEqual(
            pasteboardItem.string(
                forType: NSPasteboard.PasteboardType(LazyShelfDrag.type.identifier)
            ),
            store.draggedItemIDs.map(\.uuidString).joined(separator: "\n")
        )

        let provider = LazyShelfDrag.provider(for: item, itemIDs: store.draggedItemIDs)
        XCTAssertTrue(provider.registeredTypeIdentifiers.contains(UTType.fileURL.identifier))
        XCTAssertTrue(provider.registeredTypeIdentifiers.contains(LazyShelfDrag.type.identifier))
    }

    func testShelfPayloadIsNeverAcceptedAsAnExternalFileDrop() {
        XCTAssertFalse(
            LazyShelfDrag.acceptsExternalDrop(
                types: [UTType.fileURL, LazyShelfDrag.type],
                hasActiveShelfDrag: true
            )
        )
        XCTAssertFalse(
            LazyShelfDrag.acceptsExternalDrop(
                types: [UTType.fileURL, LazyShelfDrag.type],
                hasActiveShelfDrag: false
            )
        )
        XCTAssertTrue(
            LazyShelfDrag.acceptsExternalDrop(
                types: [UTType.fileURL],
                hasActiveShelfDrag: false
            )
        )
    }

    func testShelfDragTypeIsDeclaredInAppInfoPlist() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let data = try Data(contentsOf: repositoryRoot.appendingPathComponent("Info.plist"))
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
        let declarations = try XCTUnwrap(plist["UTExportedTypeDeclarations"] as? [[String: Any]])
        let shelfType = try XCTUnwrap(
            declarations.first { $0["UTTypeIdentifier"] as? String == LazyShelfDrag.type.identifier }
        )

        XCTAssertEqual(shelfType["UTTypeConformsTo"] as? [String], [UTType.data.identifier])
    }
}
