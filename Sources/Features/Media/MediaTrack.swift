import Foundation

/// Represents the currently playing media item.
public struct MediaTrack: Equatable, @unchecked Sendable {
    public let title: String
    public let artist: String
    public let album: String
    public let isPlaying: Bool
    public let duration: TimeInterval
    public let elapsedTime: TimeInterval
    public let playbackRate: Double
    public let elapsedTimeSampledAt: TimeInterval
    public let artworkUrl: String?
    public let artworkData: Data?
    public let appName: String
    public let bundleIdentifier: String?
    /// Browser tab coordinates are only set for tracks discovered by the tab scan.
    /// They keep controls pointed at the same tab when several tabs can play media.
    public let browserWindowIndex: Int?
    public let browserTabIndex: Int?

    public var displayTitle: String {
        let value = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Nothing Playing" : value
    }

    public var displayArtist: String {
        let value = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Open a media app" : value
    }

    public init(
        title: String,
        artist: String,
        album: String,
        isPlaying: Bool,
        duration: TimeInterval,
        elapsedTime: TimeInterval,
        playbackRate: Double? = nil,
        elapsedTimeSampledAt: TimeInterval? = nil,
        artworkUrl: String? = nil,
        artworkData: Data? = nil,
        appName: String = "Music",
        bundleIdentifier: String? = nil,
        browserWindowIndex: Int? = nil,
        browserTabIndex: Int? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.isPlaying = isPlaying
        self.duration = duration
        self.elapsedTime = elapsedTime
        self.playbackRate = playbackRate ?? (isPlaying ? 1 : 0)
        self.elapsedTimeSampledAt = elapsedTimeSampledAt ?? Date().timeIntervalSince1970
        self.artworkUrl = artworkUrl
        self.artworkData = artworkData
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.browserWindowIndex = browserWindowIndex
        self.browserTabIndex = browserTabIndex
    }

    public static func == (lhs: MediaTrack, rhs: MediaTrack) -> Bool {
        lhs.title == rhs.title &&
        lhs.artist == rhs.artist &&
        lhs.album == rhs.album &&
        lhs.isPlaying == rhs.isPlaying &&
        lhs.playbackRate == rhs.playbackRate &&
        lhs.elapsedTimeSampledAt == rhs.elapsedTimeSampledAt &&
        lhs.elapsedTime == rhs.elapsedTime &&
        lhs.appName == rhs.appName &&
        lhs.bundleIdentifier == rhs.bundleIdentifier &&
        lhs.browserWindowIndex == rhs.browserWindowIndex &&
        lhs.browserTabIndex == rhs.browserTabIndex &&
        lhs.artworkUrl == rhs.artworkUrl &&
        lhs.artworkData == rhs.artworkData
    }
}
