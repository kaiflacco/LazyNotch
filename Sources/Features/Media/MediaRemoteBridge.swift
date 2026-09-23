import AppKit
import Foundation

struct MediaRemoteTrack: @unchecked Sendable {
    let title: String
    let artist: String
    let album: String
    let isPlaying: Bool
    let duration: TimeInterval
    let elapsedTime: TimeInterval
    let playbackRate: Double
    let elapsedTimeSampledAt: TimeInterval
    let artworkData: Data?
    let artworkUrl: String?
    let appName: String
    let bundleIdentifier: String?
}

/// ponytail: soft-links Apple's private Now Playing service for zero-setup browser media;
/// replace with a public API if Apple exposes one.
@MainActor
final class MediaRemoteBridge {
    static let shared = MediaRemoteBridge()

    private typealias RegisterFunction = @convention(c) (DispatchQueue) -> Void
    private typealias GetInfoFunction = @convention(c) (DispatchQueue, @escaping ([String: Any]?) -> Void) -> Void
    private typealias GetPIDFunction = @convention(c) (DispatchQueue, @escaping (Int32) -> Void) -> Void
    private typealias GetPlayingFunction = @convention(c) (DispatchQueue, @escaping (Bool) -> Void) -> Void
    private typealias SendCommandFunction = @convention(c) (Int32, Any?) -> Bool

    private let registerFunction: RegisterFunction?
    private let getInfoFunction: GetInfoFunction?
    private let getPIDFunction: GetPIDFunction?
    private let getPlayingFunction: GetPlayingFunction?
    private let sendCommandFunction: SendCommandFunction?

    private nonisolated static let appleSignedQuery = #"""
    ObjC.import("Foundation");

    function run() {
      try {
        const mediaRemote = $.NSBundle.bundleWithPath("/System/Library/PrivateFrameworks/MediaRemote.framework/");
        mediaRemote.load;

        const requestType = $.NSClassFromString("MRNowPlayingRequest");
        if (!requestType) return JSON.stringify({ error: "MediaRemote is unavailable" });

        const result = { isPlaying: requestType.localIsPlaying ? true : false };
        const item = requestType.localNowPlayingItem;
        if (item && item.nowPlayingInfo) {
          const info = item.nowPlayingInfo;
          const keys = info.keyEnumerator;
          let key;

          while ((key = keys.nextObject) && !key.isNil()) {
            const name = ObjC.unwrap(key);
            const value = info.objectForKey(key);
            if (!value || value.isNil()) continue;

            const outputKey = name.replace("kMRMediaRemoteNowPlayingInfo", "");
            if (value.isKindOfClass($.NSDate)) {
              result[outputKey] = value.timeIntervalSince1970;
            } else if (value.isKindOfClass($.NSData)) {
              result[outputKey] = ObjC.unwrap(value.base64EncodedStringWithOptions(0));
            } else if (value.isKindOfClass($.NSNumber) || value.isKindOfClass($.NSString)) {
              result[outputKey] = ObjC.unwrap(value);
            }
          }
        }

        const playerPath = requestType.localNowPlayingPlayerPath;
        if (playerPath && playerPath.client) {
          const client = playerPath.client;
          if (client.parentApplicationBundleIdentifier && !client.parentApplicationBundleIdentifier.isNil()) {
            result.ParentBundle = ObjC.unwrap(client.parentApplicationBundleIdentifier);
          }
          if (client.bundleIdentifier && !client.bundleIdentifier.isNil()) {
            result.Bundle = ObjC.unwrap(client.bundleIdentifier);
          }
          result.SourcePID = client.processIdentifier;
        }

        return JSON.stringify(result);
      } catch (error) {
        return JSON.stringify({ error: error.toString() });
      }
    }

    run();
    """#

    var isAvailable: Bool {
        getInfoFunction != nil && sendCommandFunction != nil
    }

    private init() {
        let path = "/System/Library/PrivateFrameworks/MediaRemote.framework"
        let bundle = CFBundleCreate(kCFAllocatorDefault, URL(fileURLWithPath: path) as CFURL)

        func function<T>(_ name: String, as type: T.Type) -> T? {
            guard let bundle,
                  let pointer = CFBundleGetFunctionPointerForName(bundle, name as CFString) else { return nil }
            return unsafeBitCast(pointer, to: type)
        }

        registerFunction = function("MRMediaRemoteRegisterForNowPlayingNotifications", as: RegisterFunction.self)
        getInfoFunction = function("MRMediaRemoteGetNowPlayingInfo", as: GetInfoFunction.self)
        getPIDFunction = function("MRMediaRemoteGetNowPlayingApplicationPID", as: GetPIDFunction.self)
        getPlayingFunction = function("MRMediaRemoteGetNowPlayingApplicationIsPlaying", as: GetPlayingFunction.self)
        sendCommandFunction = function("MRMediaRemoteSendCommand", as: SendCommandFunction.self)
    }

    func start() {
        guard isAvailable else { return }
        registerFunction?(DispatchQueue.main)
    }

    func requestTrack(completion: @escaping (MediaRemoteTrack?) -> Void) {
        guard let getInfoFunction else {
            requestViaAppleSignedHost(completion: completion)
            return
        }

        getInfoFunction(DispatchQueue.main) { [weak self] info in
            guard let self else {
                completion(nil)
                return
            }

            let finish: (Int32?, Bool?) -> Void = { pid, isPlaying in
                if let track = self.makeTrack(info: info, pid: pid, isPlaying: isPlaying) {
                    completion(track)
                } else {
                    self.requestViaAppleSignedHost(completion: completion)
                }
            }

            if let getPIDFunction = self.getPIDFunction {
                getPIDFunction(DispatchQueue.main) { [weak self] pid in
                    guard let self else {
                        completion(nil)
                        return
                    }
                    self.readPlayingState(info: info, pid: pid, finish: finish)
                }
            } else {
                self.readPlayingState(info: info, pid: nil, finish: finish)
            }
        }
    }

    @discardableResult
    func send(command: String) -> Bool {
        guard let sendCommandFunction else { return false }

        let commandID: Int32
        switch command {
        case "playpause": commandID = 2
        case "next track": commandID = 4
        case "previous track": commandID = 5
        default: return false
        }
        return sendCommandFunction(commandID, nil)
    }

    private func readPlayingState(
        info: [String: Any]?,
        pid: Int32?,
        finish: @escaping (Int32?, Bool?) -> Void
    ) {
        if let getPlayingFunction {
            getPlayingFunction(DispatchQueue.main) { isPlaying in
                finish(pid, isPlaying)
            }
        } else {
            let rate = (info?["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? NSNumber)?.doubleValue ?? 0
            finish(pid, rate > 0)
        }
    }

    private func requestViaAppleSignedHost(completion: @escaping (MediaRemoteTrack?) -> Void) {
        let task = Task.detached(priority: .userInitiated) {
            Self.queryViaAppleSignedHost()
        }

        Task { @MainActor in
            completion(await task.value)
        }
    }

    private func makeTrack(info: [String: Any]?, pid: Int32?, isPlaying: Bool?) -> MediaRemoteTrack? {
        guard let info,
              let title = (info["kMRMediaRemoteNowPlayingInfoTitle"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else { return nil }

        let application = pid.flatMap { NSRunningApplication(processIdentifier: pid_t($0)) }
        let duration = (info["kMRMediaRemoteNowPlayingInfoDuration"] as? NSNumber)?.doubleValue ?? 0
        let elapsedTime = (info["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? NSNumber)?.doubleValue ?? 0
        let playbackRate = (info["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? NSNumber)?.doubleValue ?? 0
        let elapsedTimeSampledAt = (info["kMRMediaRemoteNowPlayingInfoTimestamp"] as? NSNumber)?.doubleValue ?? Date().timeIntervalSince1970
        let artworkData = (info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data)

        return MediaRemoteTrack(
            title: title,
            artist: (info["kMRMediaRemoteNowPlayingInfoArtist"] as? String) ?? "",
            album: (info["kMRMediaRemoteNowPlayingInfoAlbum"] as? String) ?? "",
            isPlaying: isPlaying ?? (playbackRate > 0),
            duration: duration,
            elapsedTime: elapsedTime,
            playbackRate: playbackRate,
            elapsedTimeSampledAt: elapsedTimeSampledAt,
            artworkData: artworkData,
            artworkUrl: nil,
            appName: application?.localizedName ?? "Now Playing",
            bundleIdentifier: application?.bundleIdentifier
        )
    }

    private nonisolated static func queryViaAppleSignedHost() -> MediaRemoteTrack? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-l", "JavaScript", "-e", appleSignedQuery]

        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        let watchdog = DispatchWorkItem { process.terminate() }
        DispatchQueue.global().asyncAfter(deadline: .now() + 5, execute: watchdog)
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        watchdog.cancel()

        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["error"] == nil,
              let title = (object["Title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else { return nil }

        func string(_ key: String) -> String {
            (object[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }

        func number(_ key: String) -> Double {
            (object[key] as? NSNumber)?.doubleValue ?? 0
        }

        let pidValue = number("SourcePID")
        let pid = (pidValue > 0 && pidValue < 2_147_483_647) ? Int32(pidValue) : 0
        let application = pid > 0 ? NSRunningApplication(processIdentifier: pid_t(pid)) : nil
        let bundleIdentifier = string("ParentBundle").isEmpty ? string("Bundle") : string("ParentBundle")
        let artworkData = string("ArtworkData").isEmpty ? nil : Data(base64Encoded: string("ArtworkData"))
        let appName = application?.localizedName ?? (bundleIdentifier.isEmpty ? "Now Playing" : bundleIdentifier)
        let artworkUrl = artworkData == nil ? browserArtworkURL(bundleIdentifier: bundleIdentifier) : nil

        return MediaRemoteTrack(
            title: title,
            artist: string("Artist"),
            album: string("Album"),
            isPlaying: (object["isPlaying"] as? Bool) ?? (number("PlaybackRate") > 0),
            duration: number("Duration"),
            elapsedTime: number("ElapsedTime"),
            playbackRate: number("PlaybackRate"),
            elapsedTimeSampledAt: number("Timestamp") > 0 ? number("Timestamp") : Date().timeIntervalSince1970,
            artworkData: artworkData,
            artworkUrl: artworkUrl,
            appName: appName,
            bundleIdentifier: bundleIdentifier.isEmpty ? application?.bundleIdentifier : bundleIdentifier
        )
    }

    private nonisolated static func browserArtworkURL(bundleIdentifier: String) -> String? {
        let browserBundleIdentifiers = [
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
        guard browserBundleIdentifiers.contains(bundleIdentifier) else { return nil }

        let appID = appleScriptQuote(bundleIdentifier)
        let source: String
        if bundleIdentifier == "com.apple.Safari" || bundleIdentifier == "com.apple.SafariTechnologyPreview" {
            source = """
            using terms from application "Safari"
                tell application id \(appID)
                    if (count windows) > 0 then return URL of current tab of front window
                end tell
            end using terms from
            """
        } else {
            source = """
            using terms from application "Google Chrome"
                tell application id \(appID)
                    if (count windows) > 0 then return URL of active tab of front window
                end tell
            end using terms from
            """
        }

        guard let urlString = executeAppleScript(source),
              let components = URLComponents(string: urlString),
              let host = components.host?.lowercased() else { return nil }

        let videoID: String?
        if host == "youtu.be" {
            videoID = components.path.split(separator: "/").first.map(String.init)
        } else if host == "youtube.com" || host.hasSuffix(".youtube.com") {
            if let queryID = components.queryItems?.first(where: { $0.name == "v" })?.value {
                videoID = queryID
            } else {
                let parts = components.path.split(separator: "/")
                videoID = ["shorts", "embed", "live"].contains(parts.first.map(String.init) ?? "")
                    ? parts.dropFirst().first.map(String.init)
                    : nil
            }
        } else {
            videoID = nil
        }

        guard let videoID,
              (6...20).contains(videoID.count),
              videoID.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }) else { return nil }
        return "https://i.ytimg.com/vi/\(videoID)/hqdefault.jpg"
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
