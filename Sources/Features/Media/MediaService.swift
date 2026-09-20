import AppKit
import Combine
import Foundation

/// Service for monitoring and controlling media playback (Apple Music & Spotify).
@MainActor
public final class MediaService: ObservableObject {
    public static let shared = MediaService()

    @Published public var currentTrack: MediaTrack?
    @Published public var isAvailable: Bool = false
    @Published public var cachedArtwork: NSImage?

    private var pollTimer: Timer?
    private var notificationObservers: [NSObjectProtocol] = []
    private var lastArtworkUrl: String?

    public init() {
        startMonitoring()
    }

    public func startMonitoring() {
        guard pollTimer == nil else { return }

        // Setup distributed notifications for instantaneous updates
        let spotifyCenter = DistributedNotificationCenter.default()
        let obs1 = spotifyCenter.addObserver(
            forName: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshTrack()
            }
        }
        let obs2 = spotifyCenter.addObserver(
            forName: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshTrack()
            }
        }
        notificationObservers = [obs1, obs2]

        // Poll every 1.5 seconds for progress and external state changes
        let timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshTrack()
            }
        }
        pollTimer = timer
        RunLoop.main.add(timer, forMode: .common)

        // Immediate check
        refreshTrack()
    }

    public func refreshTrack() {
        Task.detached(priority: .userInitiated) {
            let track = Self.fetchCurrentTrack()
            await MainActor.run {
                self.currentTrack = track
                self.isAvailable = track != nil
                
                if track?.artworkUrl != self.lastArtworkUrl {
                    self.lastArtworkUrl = track?.artworkUrl
                    if let urlStr = track?.artworkUrl, let url = URL(string: urlStr) {
                        Task {
                            if let (data, _) = try? await URLSession.shared.data(from: url), let img = NSImage(data: data) {
                                await MainActor.run { self.cachedArtwork = img }
                            }
                        }
                    } else {
                        self.cachedArtwork = nil
                    }
                }
            }
        }
    }

    // MARK: - Playback Controls

    public func togglePlayPause() {
        guard let track = currentTrack else { return }
        let app = track.appName == "Spotify" ? "Spotify" : "Music"
        Task.detached(priority: .userInitiated) {
            let script = "tell application \"\(app)\" to playpause"
            var error: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&error)
            
            try? await Task.sleep(nanoseconds: 100_000_000)
            let updated = Self.fetchCurrentTrack()
            await MainActor.run {
                self.currentTrack = updated
            }
        }
    }

    public func nextTrack() {
        guard let track = currentTrack else { return }
        let app = track.appName == "Spotify" ? "Spotify" : "Music"
        Task.detached(priority: .userInitiated) {
            let script = "tell application \"\(app)\" to next track"
            var error: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&error)
            
            try? await Task.sleep(nanoseconds: 150_000_000)
            let updated = Self.fetchCurrentTrack()
            await MainActor.run {
                self.currentTrack = updated
            }
        }
    }

    public func activateApp() {
        guard let track = currentTrack else {
            if let spotify = NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").first {
                spotify.activate()
                return
            }
            if let music = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").first {
                music.activate()
                return
            }
            return
        }

        let bundleId = track.appName == "Spotify" ? "com.spotify.client" : "com.apple.Music"
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first {
            app.activate()
            return
        }

        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            return
        }

        let script = "tell application \"\(track.appName)\" to activate"
        var err: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&err)
    }

    public func previousTrack() {
        guard let track = currentTrack else { return }
        let app = track.appName == "Spotify" ? "Spotify" : "Music"
        Task.detached(priority: .userInitiated) {
            let script = "tell application \"\(app)\" to previous track"
            var error: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&error)
            
            try? await Task.sleep(nanoseconds: 150_000_000)
            let updated = Self.fetchCurrentTrack()
            await MainActor.run {
                self.currentTrack = updated
            }
        }
    }

    // MARK: - Background Script Querying

    private nonisolated static func fetchCurrentTrack() -> MediaTrack? {
        let isSpotifyRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty
        let isMusicRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty

        // If Spotify is running, check it
        if isSpotifyRunning, let track = querySpotifyApp() {
            return track
        }

        // If Music is running, check it
        if isMusicRunning, let track = queryMusicApp() {
            return track
        }

        return nil
    }

    private nonisolated static func querySpotifyApp() -> MediaTrack? {
        let script = """
        tell application "Spotify"
            try
                set trackName to name of current track
                set artistName to artist of current track
                set albumName to album of current track
                set pos to player position
                set dur to (duration of current track) / 1000
                set pState to player state as string
                set artUrl to artwork url of current track
                return trackName & "|||" & artistName & "|||" & albumName & "|||" & pos & "|||" & dur & "|||" & pState & "|||Spotify|||" & artUrl
            on error
                return ""
            end try
        end tell
        """
        return executeMediaScript(script, defaultApp: "Spotify")
    }

    private nonisolated static func queryMusicApp() -> MediaTrack? {
        let script = """
        tell application "Music"
            try
                set pState to player state as string
                if pState is "playing" or pState is "paused" then
                    set trackName to name of current track
                    set artistName to artist of current track
                    set albumName to album of current track
                    set pos to player position
                    set dur to duration of current track
                    return trackName & "|||" & artistName & "|||" & albumName & "|||" & pos & "|||" & dur & "|||" & pState & "|||Music"
                end if
            on error
                return ""
            end try
        end tell
        """
        return executeMediaScript(script, defaultApp: "Music")
    }

    private nonisolated static func executeMediaScript(_ source: String, defaultApp: String) -> MediaTrack? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source),
              let desc = script.executeAndReturnError(&error).stringValue,
              !desc.isEmpty else {
            return nil
        }

        let parts = desc.components(separatedBy: "|||")
        guard parts.count >= 6 else { return nil }

        let title = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let artist = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let album = parts[2].trimmingCharacters(in: .whitespacesAndNewlines)
        let pos = Double(parts[3]) ?? 0
        let dur = Double(parts[4]) ?? 0
        let isPlaying = parts[5].lowercased() == "playing"
        let appName = parts.count > 6 ? parts[6] : defaultApp
        let artworkUrl = (parts.count > 7 && !parts[7].isEmpty) ? parts[7].trimmingCharacters(in: .whitespacesAndNewlines) : nil

        guard !title.isEmpty else { return nil }

        return MediaTrack(
            title: title,
            artist: artist,
            album: album,
            isPlaying: isPlaying,
            duration: dur,
            elapsedTime: pos,
            artwork: nil,
            artworkUrl: artworkUrl,
            appName: appName
        )
    }
}
