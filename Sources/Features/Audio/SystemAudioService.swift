import CoreAudio
import Combine
import Foundation

/// Reads and writes the default macOS output volume without opening System Settings.
/// The service is intentionally small so Shelf can expose a useful volume control
/// without taking ownership of media playback or introducing another window.
@MainActor
final class SystemAudioService: ObservableObject {
    static let shared = SystemAudioService()

    @Published private(set) var volume: Double = 0.5
    @Published private(set) var isMuted = false
    @Published private(set) var isAvailable = false

    private var refreshTimer: Timer?

    private init() {
        refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
        if let refreshTimer {
            RunLoop.main.add(refreshTimer, forMode: .common)
        }
    }

    func refresh() {
        guard let deviceID = defaultOutputDevice() else {
            isAvailable = false
            return
        }

        let currentVolume = readScalar(
            deviceID: deviceID,
            selector: kAudioDevicePropertyVolumeScalar
        )
        let currentMute = readMute(deviceID: deviceID)

        guard let currentVolume else {
            isAvailable = false
            return
        }

        volume = Double(min(max(currentVolume, 0), 1))
        isMuted = currentMute ?? false
        isAvailable = true
    }

    func setVolume(_ value: Double) {
        guard let deviceID = defaultOutputDevice() else { return }
        let clamped = min(max(value, 0), 1)
        guard writeScalar(clamped, deviceID: deviceID) else { return }
        volume = clamped
        isAvailable = true
    }

    func toggleMute() {
        guard let deviceID = defaultOutputDevice(),
              let muted = readMute(deviceID: deviceID),
              writeMute(!muted, deviceID: deviceID) else { return }
        isMuted = !muted
        isAvailable = true
    }

    private func defaultOutputDevice() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &deviceID
        )
        guard status == noErr, deviceID != 0 else { return nil }
        return deviceID
    }

    private func readScalar(deviceID: AudioDeviceID, selector: AudioObjectPropertySelector) -> Float32? {
        var value = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value)
        return status == noErr ? value : nil
    }

    private func readMute(deviceID: AudioDeviceID) -> Bool? {
        var value = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value)
        return status == noErr ? value != 0 : nil
    }

    private func writeScalar(_ value: Double, deviceID: AudioDeviceID) -> Bool {
        var scalar = Float32(value)
        let size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        return AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &scalar) == noErr
    }

    private func writeMute(_ muted: Bool, deviceID: AudioDeviceID) -> Bool {
        var value = muted ? UInt32(1) : UInt32(0)
        let size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        return AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &value) == noErr
    }
}
