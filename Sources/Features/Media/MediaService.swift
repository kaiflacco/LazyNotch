import AppKit
import Combine
import Foundation

/// Service for monitoring and controlling media playback from native apps and browser tabs.
@MainActor
public final class MediaService: ObservableObject {
    public static let shared = MediaService()

    private nonisolated static let browserBundleIdentifiers: Set<String> = [
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview",
        "com.google.Chrome",
        "com.google.Chrome.beta",
        "com.google.Chrome.canary",
        "com.brave.Browser",
        "com.microsoft.edgemac",
        "com.vivaldi.Vivaldi",
        "com.operasoftware.Opera",
        "company.thebrowser.Browser",
        "org.chromium.Chromium",
    ]

    private nonisolated static let browserBundleOrder = [
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview",
        "com.google.Chrome",
        "com.google.Chrome.beta",
        "com.google.Chrome.canary",
        "com.brave.Browser",
        "com.microsoft.edgemac",
        "com.vivaldi.Vivaldi",
        "com.operasoftware.Opera",
        "company.thebrowser.Browser",
        "org.chromium.Chromium",
    ]

    private nonisolated static let knownNativeBundleIdentifiers = [
        "com.spotify.client",
        "com.apple.Music",
        "com.tidal.desktop",
        "org.videolan.vlc",
        "com.colliderli.iina",
        "com.coppertino.Vox",
        "com.swinsian.Swinsian",
        "com.audirvana.Audirvana",
        "com.deezer.deezer-desktop",
        "com.cindori.Doppler",
    ]

    @Published public var currentTrack: MediaTrack?
    @Published public var cachedArtwork: NSImage?

    private let mediaRemote = MediaRemoteBridge.shared
    private var pollTimer: Timer?
    private var notificationObservers: [NSObjectProtocol] = []
    private var lastArtworkUrl: String?
    private var lastArtworkData: Data?
    private var refreshTask: Task<Void, Never>?
    private var artworkTask: Task<Void, Never>?
    private var progressTimer: Timer?
    private var currentRefreshID: UInt64 = 0

    private struct BrowserScriptResult: Sendable {
        let value: String
        let windowIndex: Int?
        let tabIndex: Int?
    }

    private nonisolated static let browserResultSeparator = "␞"

    nonisolated static func shouldProbeBrowsers(
        frontmostBundleIdentifier: String?,
        remoteBundleIdentifier: String?,
        runningBundleIdentifiers: Set<String>
    ) -> Bool {
        browserBundleIdentifiers.contains(frontmostBundleIdentifier ?? "") ||
            remoteBundleIdentifier.map(browserBundleIdentifiers.contains) == true ||
            runningBundleIdentifiers.contains(where: browserBundleIdentifiers.contains)
    }

    nonisolated static func prioritizedMediaBundleIdentifiers(
        frontmostBundleIdentifier: String?,
        runningBundleIdentifiers: Set<String>
    ) -> [String] {
        var ordered: [String] = []

        func appendIfRunning(_ bundleIdentifier: String) {
            guard runningBundleIdentifiers.contains(bundleIdentifier),
                  !ordered.contains(bundleIdentifier) else { return }
            ordered.append(bundleIdentifier)
        }

        if let frontmostBundleIdentifier,
           browserBundleIdentifiers.contains(frontmostBundleIdentifier) ||
           knownNativeBundleIdentifiers.contains(frontmostBundleIdentifier) {
            appendIfRunning(frontmostBundleIdentifier)
        }
        browserBundleOrder.forEach(appendIfRunning)
        knownNativeBundleIdentifiers.forEach(appendIfRunning)
        return ordered
    }

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
        let mediaRemoteObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshTrack()
            }
        }
        notificationObservers = [obs1, obs2, mediaRemoteObserver]
        mediaRemote.start()

        // Poll every 1.5 seconds for progress and external state changes
        let timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshTrack()
            }
        }
        pollTimer = timer
        RunLoop.main.add(timer, forMode: .common)

        // MediaRemote reports elapsed time as a sample. Advance that sample locally
        // between polls so browser video progress stays live even when the browser
        // does not publish a new elapsed-time value every tick.
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advanceProgress()
            }
        }
        self.progressTimer = progressTimer
        RunLoop.main.add(progressTimer, forMode: .common)

        // Immediate check
        refreshTrack()
    }

    public func stopMonitoring() {
        currentRefreshID &+= 1
        pollTimer?.invalidate()
        pollTimer = nil
        progressTimer?.invalidate()
        progressTimer = nil
        refreshTask?.cancel()
        refreshTask = nil
        artworkTask?.cancel()
        artworkTask = nil

        let center = DistributedNotificationCenter.default()
        notificationObservers.forEach { center.removeObserver($0) }
        notificationObservers.removeAll()
    }

    public func refreshTrack() {
        refreshTask?.cancel()
        currentRefreshID &+= 1
        let refreshID = currentRefreshID

        if mediaRemote.isAvailable {
            mediaRemote.requestTrack { [weak self] remoteTrack in
                guard let self, self.currentRefreshID == refreshID else { return }
                if let remoteTrack {
                    self.applyRemoteTrack(Self.makeMediaTrack(from: remoteTrack), refreshID: refreshID)
                } else {
                    self.refreshViaAppleScript(refreshID: refreshID)
                }
            }
        } else {
            refreshViaAppleScript(refreshID: refreshID)
        }
    }

    private func applyRemoteTrack(_ remoteTrack: MediaTrack, refreshID: UInt64) {
        let frontmostBundleIdentifier = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let runningBundleIdentifiers = Set(
            NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
        )

        if Self.shouldProbeBrowsers(
            frontmostBundleIdentifier: frontmostBundleIdentifier,
            remoteBundleIdentifier: remoteTrack.bundleIdentifier,
            runningBundleIdentifiers: runningBundleIdentifiers
        ) {
            refreshTask = Task { [weak self] in
                let detectedTrack = await Task.detached(priority: .userInitiated) {
                    // A paused browser record can be stale while Spotify or a
                    // background browser tab is actively playing. Query every
                    // candidate so active media always wins.
                    Self.fetchCurrentTrack()
                }.value

                guard !Task.isCancelled, let self, self.currentRefreshID == refreshID else { return }
                // Prefer an actually playing browser tab. If the browser probe is
                // unavailable, retain MediaRemote's native fallback instead.
                if let detectedTrack, detectedTrack.isPlaying || !remoteTrack.isPlaying {
                    self.apply(detectedTrack)
                } else {
                    self.apply(remoteTrack)
                }
            }
            return
        }

        guard let bundleIdentifier = remoteTrack.bundleIdentifier ?? Self.inferredBundleIdentifier(for: remoteTrack.appName),
              Self.knownNativeBundleIdentifiers.contains(bundleIdentifier),
              remoteTrack.artworkData == nil,
              remoteTrack.artworkUrl == nil else {
            apply(remoteTrack)
            return
        }

        // MediaRemote is the right source for playback state, but some native
        // players expose artwork only through their AppleScript dictionary.
        refreshTask = Task { [weak self] in
            let nativeTrack = await Task.detached(priority: .userInitiated) {
                Self.queryNativeMediaApp(bundleIdentifier: bundleIdentifier, appName: remoteTrack.appName)
            }.value

            guard !Task.isCancelled, let self, self.currentRefreshID == refreshID else { return }
            self.apply(nativeTrack ?? remoteTrack)
        }
    }

    private func refreshViaAppleScript(refreshID: UInt64) {
        refreshTask = Task { [weak self] in
            let track = await Task.detached(priority: .userInitiated) {
                Self.fetchCurrentTrack()
            }.value

            guard !Task.isCancelled, let self, self.currentRefreshID == refreshID else { return }
            self.apply(track)
        }
    }

    private func apply(_ track: MediaTrack?) {
        guard let track else {
            currentTrack = nil
            updateArtwork(for: nil)
            return
        }

        let now = Date().timeIntervalSince1970
        let projectedElapsed = projectedElapsedTime(for: track, at: now)
        let liveTrack = Self.copy(track, elapsedTime: projectedElapsed, sampledAt: now)
        currentTrack = liveTrack
        updateArtwork(for: liveTrack)
    }

    private func advanceProgress() {
        guard let track = currentTrack,
              track.isPlaying,
              track.playbackRate > 0 else { return }

        let now = Date().timeIntervalSince1970
        let elapsed = projectedElapsedTime(for: track, at: now)
        guard abs(elapsed - track.elapsedTime) >= 0.05 else { return }
        currentTrack = Self.copy(track, elapsedTime: elapsed, sampledAt: now)
    }

    private func projectedElapsedTime(for track: MediaTrack, at now: TimeInterval) -> TimeInterval {
        let elapsed = track.elapsedTime + max(0, now - track.elapsedTimeSampledAt) * track.playbackRate
        guard track.duration > 0 else { return max(0, elapsed) }
        return min(max(0, elapsed), track.duration)
    }

    private nonisolated static func copy(
        _ track: MediaTrack,
        elapsedTime: TimeInterval,
        sampledAt: TimeInterval
    ) -> MediaTrack {
        MediaTrack(
            title: track.title,
            artist: track.artist,
            album: track.album,
            isPlaying: track.isPlaying,
            duration: track.duration,
            elapsedTime: elapsedTime,
            playbackRate: track.playbackRate,
            elapsedTimeSampledAt: sampledAt,
            artworkUrl: track.artworkUrl,
            artworkData: track.artworkData,
            appName: track.appName,
            bundleIdentifier: track.bundleIdentifier,
            browserWindowIndex: track.browserWindowIndex,
            browserTabIndex: track.browserTabIndex
        )
    }

    private func updateArtwork(for track: MediaTrack?) {
        let artworkUrl = track?.artworkUrl
        let artworkData = track?.artworkData
        guard artworkUrl != lastArtworkUrl || artworkData != lastArtworkData else { return }

        lastArtworkUrl = artworkUrl
        lastArtworkData = artworkData
        artworkTask?.cancel()

        if let artworkData {
            cachedArtwork = NSImage(data: artworkData)
            return
        }

        guard let artworkUrl, let url = URL(string: artworkUrl) else {
            cachedArtwork = nil
            return
        }

        artworkTask = Task { [weak self] in
            let image = await Task.detached(priority: .userInitiated) { () -> NSImage? in
                guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
                return NSImage(data: data)
            }.value

            guard !Task.isCancelled, let self, self.lastArtworkUrl == artworkUrl else { return }
            if let image {
                self.cachedArtwork = image
            } else {
                // Let the next poll retry a transient artwork download failure.
                self.lastArtworkUrl = nil
            }
        }
    }

    private nonisolated static func makeMediaTrack(from remoteTrack: MediaRemoteTrack) -> MediaTrack {
        MediaTrack(
            title: remoteTrack.title,
            artist: remoteTrack.artist,
            album: remoteTrack.album,
            isPlaying: remoteTrack.isPlaying,
            duration: remoteTrack.duration,
            elapsedTime: remoteTrack.elapsedTime,
            playbackRate: remoteTrack.playbackRate,
            elapsedTimeSampledAt: remoteTrack.elapsedTimeSampledAt,
            artworkUrl: remoteTrack.artworkUrl,
            artworkData: remoteTrack.artworkData,
            appName: remoteTrack.appName,
            bundleIdentifier: remoteTrack.bundleIdentifier ?? inferredBundleIdentifier(for: remoteTrack.appName)
        )
    }

    private nonisolated static func inferredBundleIdentifier(for appName: String) -> String? {
        switch appName.lowercased() {
        case "spotify": return "com.spotify.client"
        case "music", "apple music": return "com.apple.Music"
        case "safari": return "com.apple.Safari"
        case "google chrome", "chrome": return "com.google.Chrome"
        case "microsoft edge", "edge": return "com.microsoft.edgemac"
        case "brave browser", "brave": return "com.brave.Browser"
        default: return nil
        }
    }

    // MARK: - Playback Controls

    public func togglePlayPause() {
        performPlaybackCommand("playpause", refreshAfter: 100_000_000)
    }

    public func nextTrack() {
        performPlaybackCommand("next track", refreshAfter: 150_000_000)
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

        guard let bundleId = track.bundleIdentifier else {
            let script = "tell application \(Self.appleScriptQuote(track.appName)) to activate"
            var err: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&err)
            return
        }

        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first {
            app.activate()
            return
        }

        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            return
        }

    }

    public func previousTrack() {
        performPlaybackCommand("previous track", refreshAfter: 150_000_000)
    }

    private func performPlaybackCommand(_ command: String, refreshAfter nanoseconds: UInt64) {
        guard let track = currentTrack else { return }
        let sourceBundleIdentifier = track.bundleIdentifier ?? Self.inferredBundleIdentifier(for: track.appName)

        // MediaRemote commands are global. Browser media must be addressed in
        // the selected tab first or another app (for example Spotify) can win.
        if let bundleIdentifier = sourceBundleIdentifier,
           Self.browserBundleIdentifiers.contains(bundleIdentifier) {
            Task {
                await Task.detached(priority: .userInitiated) {
                    Self.sendPlaybackCommand(command, to: track)
                    try? await Task.sleep(nanoseconds: nanoseconds)
                }.value
                self.refreshTrack()
            }
            return
        }

        // Spotify and Music have reliable app-specific commands. Keep the
        // global bridge as the fallback for native players that do not expose
        // an AppleScript dictionary.
        if sourceBundleIdentifier == "com.spotify.client" || sourceBundleIdentifier == "com.apple.Music" {
            Task {
                await Task.detached(priority: .userInitiated) {
                    Self.sendPlaybackCommand(command, to: track)
                    try? await Task.sleep(nanoseconds: nanoseconds)
                }.value
                self.refreshTrack()
            }
            return
        }

        if mediaRemote.send(command: command) {
            Task {
                try? await Task.sleep(nanoseconds: nanoseconds)
                self.refreshTrack()
            }
            return
        }
        Task {
            await Task.detached(priority: .userInitiated) {
                Self.sendPlaybackCommand(command, to: track)
                try? await Task.sleep(nanoseconds: nanoseconds)
            }.value
            self.refreshTrack()
        }
    }

    // MARK: - Background Script Querying

    private nonisolated static func fetchCurrentTrack() -> MediaTrack? {
        let runningApps = NSWorkspace.shared.runningApplications
            .compactMap { app -> (bundleIdentifier: String, name: String)? in
                guard let bundleIdentifier = app.bundleIdentifier else { return nil }
                return (bundleIdentifier, app.localizedName ?? bundleIdentifier)
            }

        let appsByBundleIdentifier = runningApps.reduce(into: [String: String]()) { apps, app in
            apps[app.bundleIdentifier] = app.name
        }
        var orderedBundleIdentifiers: [String] = []
        let mediaKeywords = ["audio", "deezer", "iina", "music", "podcast", "player", "radio", "sonos", "spotify", "stream", "tidal", "video", "vlc", "vox"]

        func appendIfRunning(_ bundleIdentifier: String) {
            guard appsByBundleIdentifier[bundleIdentifier] != nil,
                  !orderedBundleIdentifiers.contains(bundleIdentifier) else { return }
            orderedBundleIdentifiers.append(bundleIdentifier)
        }

        if let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           browserBundleIdentifiers.contains(frontmost) || knownNativeBundleIdentifiers.contains(frontmost) ||
           mediaKeywords.contains(where: { frontmost.lowercased().contains($0) || (appsByBundleIdentifier[frontmost]?.lowercased().contains($0) ?? false) }) {
            appendIfRunning(frontmost)
        }
        Self.prioritizedMediaBundleIdentifiers(
            frontmostBundleIdentifier: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
            runningBundleIdentifiers: Set(appsByBundleIdentifier.keys)
        ).forEach(appendIfRunning)

        // Small keyword filter keeps the generic AppleScript fallback away from unrelated apps.
        for app in runningApps where mediaKeywords.contains(where: { app.name.lowercased().contains($0) || app.bundleIdentifier.lowercased().contains($0) }) {
            appendIfRunning(app.bundleIdentifier)
        }

        var pausedTrack: MediaTrack?
        for bundleIdentifier in orderedBundleIdentifiers {
            let appName = appsByBundleIdentifier[bundleIdentifier] ?? bundleIdentifier
            let track: MediaTrack?
            switch bundleIdentifier {
            case "com.spotify.client":
                track = querySpotifyApp()
            case "com.apple.Music":
                track = queryMusicApp()
            case _ where browserBundleIdentifiers.contains(bundleIdentifier):
                track = queryBrowserApp(bundleIdentifier: bundleIdentifier, appName: appName)
            default:
                track = queryNativeApp(bundleIdentifier: bundleIdentifier, appName: appName)
            }

            if let track {
                if track.isPlaying { return track }
                if pausedTrack == nil { pausedTrack = track }
            }
        }

        return pausedTrack
    }

    private nonisolated static func queryNativeMediaApp(bundleIdentifier: String, appName: String) -> MediaTrack? {
        switch bundleIdentifier {
        case "com.spotify.client":
            return querySpotifyApp()
        case "com.apple.Music":
            return queryMusicApp()
        default:
            return queryNativeApp(bundleIdentifier: bundleIdentifier, appName: appName)
        }
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
        return executeMediaScript(script, defaultApp: "Spotify", bundleIdentifier: "com.spotify.client")
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
        return executeMediaScript(script, defaultApp: "Music", bundleIdentifier: "com.apple.Music")
    }

    private nonisolated static func queryNativeApp(bundleIdentifier: String, appName: String) -> MediaTrack? {
        let script = """
        using terms from application "Music"
            tell application id \(appleScriptQuote(bundleIdentifier))
                try
                    set pState to player state as string
                    if pState is "playing" or pState is "paused" then
                        set trackName to name of current track
                        set artistName to artist of current track
                        set albumName to album of current track
                        set pos to player position
                        set dur to duration of current track
                        set artUrl to ""
                        try
                            set artUrl to artwork url of current track
                        end try
                        return trackName & "|||" & artistName & "|||" & albumName & "|||" & pos & "|||" & dur & "|||" & pState & "|||" & \(appleScriptQuote(appName)) & "|||" & artUrl
                    end if
                on error
                    return ""
                end try
            end tell
        end using terms from
        """
        return executeMediaScript(script, defaultApp: appName, bundleIdentifier: bundleIdentifier)
    }

    private nonisolated static func browserProbeJavaScript(requirePlaying: Bool) -> String {
        let playbackFilter = requirePlaying ? " && !element.paused" : ""
        return #"""
        (() => {
            const media = [...document.querySelectorAll('audio,video')]
                .filter(element => !element.ended && !element.muted && element.volume > 0\#(playbackFilter))
                .sort((a, b) => Number(a.paused) - Number(b.paused))[0];
            const metadata = navigator.mediaSession && navigator.mediaSession.metadata;
            const title = (metadata && metadata.title) || document.title.replace(/\s+-\s+(YouTube|YouTube Music)$/i, '');
            if (!media || !title) return '';
            const pageArtwork = document.querySelector('meta[property="og:image"],meta[name="twitter:image"]');
            const artwork = metadata && metadata.artwork && metadata.artwork.length
                ? metadata.artwork[metadata.artwork.length - 1].src
                : (pageArtwork && pageArtwork.content) || '';
            return JSON.stringify({
                title: title,
                artist: (metadata && metadata.artist) || '',
                album: (metadata && metadata.album) || '',
                position: Number(media.currentTime) || 0,
                duration: Number.isFinite(media.duration) ? media.duration : 0,
                state: media.paused ? 'paused' : 'playing',
                artworkUrl: artwork || ''
            });
        })()
        """#
    }

    private nonisolated static func queryBrowserApp(bundleIdentifier: String, appName: String) -> MediaTrack? {
        // Scan playing elements first. This prevents a paused tab from masking
        // a different tab that is actually producing audio.
        let result = executeBrowserJavaScript(
            bundleIdentifier: bundleIdentifier,
            javascript: browserProbeJavaScript(requirePlaying: true)
        ) ?? executeBrowserJavaScript(
            bundleIdentifier: bundleIdentifier,
            javascript: browserProbeJavaScript(requirePlaying: false)
        )

        guard let result,
              let data = result.value.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let title = (payload["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else { return nil }

        let artist = (payload["artist"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let album = (payload["album"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let position = (payload["position"] as? NSNumber)?.doubleValue ?? 0
        let duration = (payload["duration"] as? NSNumber)?.doubleValue ?? 0
        let isPlaying = (payload["state"] as? String)?.lowercased() == "playing"
        let artworkUrl = (payload["artworkUrl"] as? String).flatMap { $0.isEmpty ? nil : $0 }

        return MediaTrack(
            title: title,
            artist: artist.isEmpty ? appName : artist,
            album: album,
            isPlaying: isPlaying,
            duration: duration,
            elapsedTime: position,
            artworkUrl: artworkUrl,
            appName: appName,
            bundleIdentifier: bundleIdentifier,
            browserWindowIndex: result.windowIndex,
            browserTabIndex: result.tabIndex
        )
    }

    private nonisolated static func executeMediaScript(_ source: String, defaultApp: String, bundleIdentifier: String? = nil) -> MediaTrack? {
        guard let desc = executeAppleScript(source), !desc.isEmpty else { return nil }

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
            artworkUrl: artworkUrl,
            appName: appName,
            bundleIdentifier: bundleIdentifier
        )
    }

    private nonisolated static func sendPlaybackCommand(_ command: String, to track: MediaTrack) {
        if let bundleIdentifier = track.bundleIdentifier ?? inferredBundleIdentifier(for: track.appName),
           browserBundleIdentifiers.contains(bundleIdentifier) {
            let javascript: String
            switch command {
            case "playpause":
                javascript = """
                (() => { const media = [...document.querySelectorAll('audio,video')].filter(element => !element.ended).sort((a, b) => Number(a.paused) - Number(b.paused))[0]; if (!media) return ''; media.paused ? media.play() : media.pause(); return 'ok'; })()
                """
            case "next track":
                javascript = browserSkipJavaScript(labels: ["next", "skip forward", "next song"])
            default:
                javascript = browserSkipJavaScript(labels: ["previous", "back", "rewind", "previous song"])
            }
            _ = executeBrowserJavaScript(
                bundleIdentifier: bundleIdentifier,
                javascript: javascript,
                windowIndex: track.browserWindowIndex,
                tabIndex: track.browserTabIndex
            )
            return
        }

        let target: String
        if let bundleIdentifier = track.bundleIdentifier ?? inferredBundleIdentifier(for: track.appName) {
            target = "application id \(appleScriptQuote(bundleIdentifier))"
        } else {
            target = "application \(appleScriptQuote(track.appName))"
        }
        let script = """
        using terms from application "Music"
            tell \(target) to \(command)
        end using terms from
        """
        _ = executeAppleScript(script)
    }

    private nonisolated static func browserSkipJavaScript(labels: [String]) -> String {
        let labelsLiteral = labels.map { appleScriptQuote($0) }.joined(separator: ",")
        return """
        (() => { const labels = [\(labelsLiteral)].map(value => value.toLowerCase()); const button = [...document.querySelectorAll('button,[role=button]')].find(element => { const value = ((element.getAttribute('aria-label') || '') + ' ' + (element.getAttribute('title') || '') + ' ' + (element.textContent || '')).toLowerCase(); return labels.some(label => value.includes(label)); }); if (!button) return ''; button.click(); return 'ok'; })()
        """
    }

    private nonisolated static func executeBrowserJavaScript(
        bundleIdentifier: String,
        javascript: String,
        windowIndex: Int? = nil,
        tabIndex: Int? = nil
    ) -> BrowserScriptResult? {
        let appID = appleScriptQuote(bundleIdentifier)
        let javascriptLiteral = appleScriptQuote(javascript)
        let source: String
        let separator = appleScriptQuote(browserResultSeparator)

        if bundleIdentifier == "com.apple.Safari" || bundleIdentifier == "com.apple.SafariTechnologyPreview" {
            if let windowIndex, let tabIndex {
                source = """
                using terms from application "Safari"
                    tell application id \(appID)
                        try
                            set browserTab to tab \(tabIndex) of window \(windowIndex)
                            set mediaResult to do JavaScript \(javascriptLiteral) in browserTab
                            if mediaResult is not "" then return mediaResult
                        end try
                    end tell
                end using terms from
                """
            } else {
                source = browserScanScript(
                    appID: appID,
                    javascriptLiteral: javascriptLiteral,
                    activeTabProperty: "current tab",
                    safari: true,
                    separator: separator
                )
            }
        } else {
            if let windowIndex, let tabIndex {
                source = """
                using terms from application "Google Chrome"
                    tell application id \(appID)
                        try
                            set browserTab to tab \(tabIndex) of window \(windowIndex)
                            set mediaResult to execute browserTab javascript \(javascriptLiteral)
                            if mediaResult is not "" then return mediaResult
                        end try
                    end tell
                end using terms from
                """
            } else {
                source = browserScanScript(
                    appID: appID,
                    javascriptLiteral: javascriptLiteral,
                    activeTabProperty: "active tab",
                    safari: false,
                    separator: separator
                )
            }
        }

        guard let raw = executeAppleScript(source), !raw.isEmpty else { return nil }
        guard windowIndex == nil || tabIndex == nil else {
            return BrowserScriptResult(value: raw, windowIndex: windowIndex, tabIndex: tabIndex)
        }

        let parts = raw.components(separatedBy: browserResultSeparator)
        guard parts.count >= 3,
              let resultWindowIndex = Int(parts[0]),
              let resultTabIndex = Int(parts[1]) else {
            return BrowserScriptResult(value: raw, windowIndex: nil, tabIndex: nil)
        }
        return BrowserScriptResult(
            value: parts.dropFirst(2).joined(separator: browserResultSeparator),
            windowIndex: resultWindowIndex,
            tabIndex: resultTabIndex
        )
    }

    private nonisolated static func browserScanScript(
        appID: String,
        javascriptLiteral: String,
        activeTabProperty: String,
        safari: Bool,
        separator: String
    ) -> String {
        let evaluate = safari
            ? "do JavaScript \(javascriptLiteral) in browserTab"
            : "execute browserTab javascript \(javascriptLiteral)"

        return """
        using terms from application "\(safari ? "Safari" : "Google Chrome")"
            tell application id \(appID)
                -- The active tab wins when it is playing. The second pass
                -- finds audio in background tabs when the active tab is silent.
                repeat with windowIndex from 1 to (count windows)
                    set browserWindow to window windowIndex
                    try
                        set browserTab to \(activeTabProperty) of browserWindow
                        set tabIndex to index of browserTab
                        set mediaResult to \(evaluate)
                        if mediaResult is not "" then return (windowIndex as text) & \(separator) & (tabIndex as text) & \(separator) & mediaResult
                    end try
                end repeat
                repeat with windowIndex from 1 to (count windows)
                    set browserWindow to window windowIndex
                    repeat with tabIndex from 1 to (count tabs of browserWindow)
                        try
                            set browserTab to tab tabIndex of browserWindow
                            set mediaResult to \(evaluate)
                            if mediaResult is not "" then return (windowIndex as text) & \(separator) & (tabIndex as text) & \(separator) & mediaResult
                        end try
                    end repeat
                end repeat
            end tell
        end using terms from
        """
    }

    private nonisolated static func executeAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source),
              let result = script.executeAndReturnError(&error).stringValue else { return nil }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated static func appleScriptQuote(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
