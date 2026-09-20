import AppKit
import Foundation

/// Represents the currently playing media item.
public struct MediaTrack: Equatable, @unchecked Sendable {
    public let title: String
    public let artist: String
    public let album: String
    public let isPlaying: Bool
    public let duration: TimeInterval
    public let elapsedTime: TimeInterval
    public let artwork: NSImage?
    public let artworkUrl: String?
    public let appName: String

    public init(
        title: String,
        artist: String,
        album: String,
        isPlaying: Bool,
        duration: TimeInterval,
        elapsedTime: TimeInterval,
        artwork: NSImage? = nil,
        artworkUrl: String? = nil,
        appName: String = "Music"
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.isPlaying = isPlaying
        self.duration = duration
        self.elapsedTime = elapsedTime
        self.artwork = artwork
        self.artworkUrl = artworkUrl
        self.appName = appName
    }

    public static func == (lhs: MediaTrack, rhs: MediaTrack) -> Bool {
        lhs.title == rhs.title &&
        lhs.artist == rhs.artist &&
        lhs.album == rhs.album &&
        lhs.isPlaying == rhs.isPlaying &&
        lhs.appName == rhs.appName &&
        lhs.artworkUrl == rhs.artworkUrl
    }
}
