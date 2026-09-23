import AppKit
import Combine

struct CodexUsageWindow: Equatable {
    let usedPercent: Int
    let resetsAt: Date?
    let durationMinutes: Int?

    var remainingPercent: Int {
        max(0, min(100, 100 - usedPercent))
    }
}

struct CodexUsage: Equatable {
    let primary: CodexUsageWindow
    let secondary: CodexUsageWindow
    let planName: String?
    let fetchedAt: Date
}

/// Reads the same authenticated Codex app-server endpoint used by the IDE extension.
/// It reports account quota; it does not infer usage from the host app or process list.
@MainActor
final class CodexUsageService: ObservableObject {
    static let shared = CodexUsageService()

    @Published private(set) var usage: CodexUsage?
    @Published private(set) var hostIsActive = false
    @Published private(set) var activeHostBundleIdentifier: String?
    @Published private(set) var activeHostName: String?
    @Published private(set) var codexIcon: NSImage?
    @Published private(set) var codexAccentColor: NSColor = .systemBlue

    private var pollTimer: Timer?
    private var workspaceObserver: NSObjectProtocol?
    private var process: Process?
    private var input: FileHandle?
    private var outputBuffer = Data()

    private init() {}

    func start() {
        guard pollTimer == nil else { return }

        refreshHostState()
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refreshHostState()
            }
        }

        pollTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.refresh()
            }
        }
        RunLoop.main.add(pollTimer!, forMode: .common)
        refresh()
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
            self.workspaceObserver = nil
        }
        finishProcess()
        usage = nil
        hostIsActive = false
        activeHostBundleIdentifier = nil
        activeHostName = nil
    }

    func refresh() {
        guard process == nil, let executableURL = codexExecutableURL() else { return }

        let child = Process()
        let stdin = Pipe()
        let stdout = Pipe()

        child.executableURL = executableURL
        child.arguments = ["app-server", "--listen", "stdio://"]
        child.standardInput = stdin
        child.standardOutput = stdout
        child.standardError = FileHandle.nullDevice
        child.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.finishProcess()
            }
        }

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            DispatchQueue.main.async {
                self?.consume(data)
            }
        }

        do {
            try child.run()
        } catch {
            return
        }

        process = child
        input = stdin.fileHandleForWriting
        send([
            "method": "initialize",
            "id": 1,
            "params": [
                "clientInfo": [
                    "name": "lazynotch",
                    "version": "0.1.0"
                ]
            ]
        ])
    }

    private func refreshHostState() {
        let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let supportedHosts = [
            "com.google.antigravity-ide",
            "com.openai.codex",
            "com.openai.chatgpt"
        ]
        let activeHost = bundleID.flatMap { supportedHosts.contains($0) ? $0 : nil }
        let lazyNotchBundleIDs = Set([
            "com.lazynotch.app",
            Bundle.main.bundleIdentifier,
            NSRunningApplication.current.bundleIdentifier
        ].compactMap { $0 })

        if let activeHost {
            activeHostBundleIdentifier = activeHost
            activeHostName = Self.hostName(for: activeHost)
            hostIsActive = true
        } else if activeHostBundleIdentifier != nil && (bundleID == nil || bundleID.map { lazyNotchBundleIDs.contains($0) } == true) {
            // LazyNotch uses a non-activating panel, but AppKit can still report it as
            // frontmost for a click. Keep the last supported host visible in that gap.
            hostIsActive = true
        } else {
            activeHostBundleIdentifier = nil
            activeHostName = nil
            hostIsActive = false
        }
        codexIcon = Self.codexIcon()
        codexAccentColor = Self.accentColor(for: codexIcon)
    }

    private static func hostName(for bundleID: String) -> String {
        switch bundleID {
        case "com.google.antigravity-ide": return "Antigravity"
        case "com.openai.codex": return "Codex"
        case "com.openai.chatgpt": return "ChatGPT"
        default: return "supported app"
        }
    }

    private static func codexIcon() -> NSImage? {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let extensionRoots = [
            home.appendingPathComponent(".antigravity-ide/extensions"),
            home.appendingPathComponent(".vscode/extensions")
        ]

        for root in extensionRoots {
            guard let entries = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { continue }
            for entry in entries
                .filter({ $0.lastPathComponent.hasPrefix("openai.chatgpt-") })
                .sorted(by: { $0.lastPathComponent > $1.lastPathComponent }) {
                let iconURL = entry.appendingPathComponent("resources/blossom.dark.png")
                if let icon = NSImage(contentsOf: iconURL) {
                    return icon
                }
            }
        }

        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.chatgpt") {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Codex")
    }

    private static func accentColor(for icon: NSImage?) -> NSColor {
        guard let icon,
              let bitmap = NSBitmapImageRep(
                  bitmapDataPlanes: nil,
                  pixelsWide: 16,
                  pixelsHigh: 16,
                  bitsPerSample: 8,
                  samplesPerPixel: 4,
                  hasAlpha: true,
                  isPlanar: false,
                  colorSpaceName: .deviceRGB,
                  bitmapFormat: [],
                  bytesPerRow: 0,
                  bitsPerPixel: 0
              ) else {
            return .systemBlue
        }

        let bounds = NSRect(x: 0, y: 0, width: 16, height: 16)
        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            NSGraphicsContext.restoreGraphicsState()
            return .systemBlue
        }
        NSGraphicsContext.current = context
        icon.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1)
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        var red = CGFloat.zero
        var green = CGFloat.zero
        var blue = CGFloat.zero
        var weight = CGFloat.zero
        var fallbackRed = CGFloat.zero
        var fallbackGreen = CGFloat.zero
        var fallbackBlue = CGFloat.zero
        var fallbackWeight = CGFloat.zero

        for y in 0..<16 {
            for x in 0..<16 {
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(NSColorSpace.deviceRGB) else { continue }
                var r = CGFloat.zero
                var g = CGFloat.zero
                var b = CGFloat.zero
                var a = CGFloat.zero
                color.getRed(&r, green: &g, blue: &b, alpha: &a)
                guard a > 0.15 else { continue }

                fallbackRed += r * a
                fallbackGreen += g * a
                fallbackBlue += b * a
                fallbackWeight += a

                let saturation = max(r, g, b) - min(r, g, b)
                guard saturation > 0.12 else { continue }
                let pixelWeight = saturation * a
                red += r * pixelWeight
                green += g * pixelWeight
                blue += b * pixelWeight
                weight += pixelWeight
            }
        }

        let totalWeight = weight > 0 ? weight : fallbackWeight
        guard totalWeight > 0 else { return .systemBlue }

        let average = NSColor(
            calibratedRed: (weight > 0 ? red : fallbackRed) / totalWeight,
            green: (weight > 0 ? green : fallbackGreen) / totalWeight,
            blue: (weight > 0 ? blue : fallbackBlue) / totalWeight,
            alpha: 1
        )

        var hue = CGFloat.zero
        var saturation = CGFloat.zero
        var brightness = CGFloat.zero
        var alpha = CGFloat.zero
        average.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        guard saturation >= 0.12 else {
            return NSColor(calibratedWhite: min(0.95, max(0.65, brightness)), alpha: 1)
        }
        return NSColor(
            calibratedHue: hue,
            saturation: min(0.9, max(0.48, saturation)),
            brightness: min(0.95, max(0.65, brightness)),
            alpha: 1
        )
    }

    private func consume(_ data: Data) {
        outputBuffer.append(data)

        while let newline = outputBuffer.firstIndex(of: 10) {
            let line = outputBuffer.prefix(upTo: newline)
            outputBuffer.removeSubrange(...newline)
            guard let message = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { continue }
            handle(message)
        }
    }

    private func handle(_ message: [String: Any]) {
        guard let id = (message["id"] as? NSNumber)?.intValue else { return }

        if id == 1 {
            send(["method": "initialized", "params": [:]])
            send([
                "method": "account/rateLimits/read",
                "id": 2,
                "params": NSNull()
            ])
            return
        }

        guard id == 2,
              let result = message["result"] as? [String: Any],
              let snapshot = ((result["rateLimitsByLimitId"] as? [String: Any])?["codex"] as? [String: Any])
                ?? (result["rateLimits"] as? [String: Any]),
              let primary = Self.parseWindow(snapshot["primary"] as? [String: Any]),
              let secondary = Self.parseWindow(snapshot["secondary"] as? [String: Any]) else {
            finishProcess()
            return
        }

        usage = CodexUsage(
            primary: primary,
            secondary: secondary,
            planName: snapshot["planType"] as? String,
            fetchedAt: Date()
        )
        finishProcess()
    }

    static func parseWindow(_ value: [String: Any]?) -> CodexUsageWindow? {
        guard let value,
              let usedPercent = (value["usedPercent"] as? NSNumber)?.intValue else { return nil }

        let resetDate: Date?
        if let seconds = (value["resetsAt"] as? NSNumber)?.doubleValue {
            resetDate = Date(timeIntervalSince1970: seconds)
        } else {
            resetDate = nil
        }

        return CodexUsageWindow(
            usedPercent: usedPercent,
            resetsAt: resetDate,
            durationMinutes: (value["windowDurationMins"] as? NSNumber)?.intValue
        )
    }

    private func send(_ message: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: message), let input else { return }
        input.write(data)
        input.write(Data([10]))
    }

    private func finishProcess() {
        if let output = process?.standardOutput as? Pipe {
            output.fileHandleForReading.readabilityHandler = nil
        }
        process?.terminate()
        process = nil
        input = nil
        outputBuffer.removeAll(keepingCapacity: true)
    }

    private func codexExecutableURL() -> URL? {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        let directPaths = [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex"
        ]

        for path in directPaths where fileManager.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }

        let extensionRoots = [
            home.appendingPathComponent(".antigravity-ide/extensions"),
            home.appendingPathComponent(".vscode/extensions")
        ]

        for root in extensionRoots {
            guard let entries = try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { continue }
            for entry in entries
                .filter({ $0.lastPathComponent.hasPrefix("openai.chatgpt-") })
                .sorted(by: { $0.lastPathComponent > $1.lastPathComponent }) {
                let candidate = entry.appendingPathComponent("bin/macos-aarch64/codex")
                if fileManager.isExecutableFile(atPath: candidate.path) {
                    return candidate
                }
            }
        }

        return nil
    }
}
