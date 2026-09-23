import XCTest
@testable import LazyNotch

@MainActor
final class ShellViewModelTests: XCTestCase {
    func testOpeningShelfSelectsShelfAndExpands() {
        let viewModel = ShellViewModel()

        viewModel.openShelf()

        XCTAssertTrue(viewModel.isExpanded)
        XCTAssertEqual(viewModel.activeTab, .shelf)
        XCTAssertFalse(viewModel.showsCodexDetails)
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
}
