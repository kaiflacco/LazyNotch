import SwiftUI
import ServiceManagement

public struct SettingsSheet: View {
    @Binding var isPresented: Bool
    
    @ObservedObject var calendarService = CalendarService.shared
    @ObservedObject var cameraManager = CameraManager.shared

    @AppStorage("openOnHover") private var openOnHover: Bool = true
    @AppStorage("showLiveMediaActivity") private var showLiveMediaActivity: Bool = true
    @AppStorage("showCodexUsage") private var showCodexUsage: Bool = true
    @AppStorage("hoverGraceDuration") private var hoverGraceDuration: Double = 0.15
    @State private var launchAtLogin: Bool = (SMAppService.mainApp.status == .enabled)
    @State private var selectedTab: SettingsTab = .general

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case permissions = "Permissions"
        case notch = "Notch"
        case shelf = "LazyShelf"
        case about = "About"
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header bar
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.lnAccentBlue)
                    Text("LazyNotch Settings")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }

                Spacer()

                Button {
                    withAnimation(LazyNotchMotion.interactiveSpring) {
                        isPresented = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Picker("Settings", selection: $selectedTab) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            Divider()
                .background(Color.white.opacity(0.08))

            // Body content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    switch selectedTab {
                    case .general:
                        generalSettingsSection
                    case .permissions:
                        permissionsSettingsSection
                    case .notch:
                        notchSettingsSection
                    case .shelf:
                        shelfSettingsSection
                    case .about:
                        aboutSettingsSection
                    }
                }
                .padding(20)
            }
            .frame(maxHeight: 280)

            Divider()
                .background(Color.white.opacity(0.08))

            // Bottom bar with Quit
            HStack {
                Button(role: .destructive) {
                    NSApplication.shared.terminate(nil)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "power")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Quit LazyNotch")
                            .font(.system(size: 11.5, weight: .medium))
                    }
                    .foregroundStyle(Color.red.opacity(0.85))
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    withAnimation(LazyNotchMotion.interactiveSpring) {
                        isPresented = false
                    }
                } label: {
                    Text("Done")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.lnAccentBlue))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.3))
        }
        .frame(width: 440)
        .background(
            ZStack {
                Color(red: 0.10, green: 0.10, blue: 0.11)
                VisualEffectBlurView(material: .hudWindow, blendingMode: .withinWindow)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.6), radius: 24, y: 12)
    }

    // MARK: - Sections

    private var generalSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $launchAtLogin) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Launch at Login")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Automatically launch LazyNotch when your Mac starts up.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .lnAccentBlue))
            .onChange(of: launchAtLogin) { _, newValue in
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    print("Failed to toggle launch at login: \(error)")
                }
            }

            Divider().background(Color.white.opacity(0.06))

            Toggle(isOn: $openOnHover) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Expand Notch on Mouse Hover")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Hover opens the idle notch; activity strips stay click-only.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .lnAccentBlue))

            Divider().background(Color.white.opacity(0.06))

            Toggle(isOn: $showLiveMediaActivity) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dynamic Island Live Media Pill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Show compact album art and animated equalizer wings for system media, including browser tabs, with no browser setup.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .lnAccentBlue))

            Divider().background(Color.white.opacity(0.06))

            Toggle(isOn: $showCodexUsage) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show Codex Usage Remaining")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Keep Codex usage available in the main widget; show it as the live pill while coding.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .lnAccentBlue))
        }
    }

    private var permissionsSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Calendar Permission Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.lnAccentBlue)

                    Text("Calendar Access")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    // Status Pill
                    HStack(spacing: 4) {
                        Circle()
                            .fill(calendarService.hasPermission ? Color.green : Color.orange)
                            .frame(width: 6, height: 6)
                        Text(calendarService.hasPermission ? "Granted" : "Not Enabled")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(calendarService.hasPermission ? Color.green : Color.orange)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.06)))
                }

                Text("Allows LazyNotch to display upcoming events and schedule in the calendar widget.")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    if !calendarService.hasPermission {
                        Button {
                            calendarService.requestAccess()
                        } label: {
                            Text("Request Access")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.lnAccentBlue))
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        calendarService.openCalendarSettings()
                    } label: {
                        HStack(spacing: 3.5) {
                            Text("Open System Settings")
                                .font(.system(size: 11.5, weight: .medium))
                            Image(systemName: "arrow.up.forward.square")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(Color.white.opacity(0.85))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 0.75))

            // Camera Permission Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.green)

                    Text("Camera Access")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)

                    Spacer()

                    // Status Pill
                    HStack(spacing: 4) {
                        Circle()
                            .fill(cameraManager.hasPermission ? Color.green : Color.orange)
                            .frame(width: 6, height: 6)
                        Text(cameraManager.hasPermission ? "Granted" : "Not Enabled")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(cameraManager.hasPermission ? Color.green : Color.orange)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.06)))
                }

                Text("Allows LazyNotch to display the live Hand Mirror camera dropdown from the physical notch.")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    if !cameraManager.hasPermission {
                        Button {
                            cameraManager.requestAccess()
                        } label: {
                            Text("Request Access")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.green))
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 3.5) {
                            Text("Open System Settings")
                                .font(.system(size: 11.5, weight: .medium))
                            Image(systemName: "arrow.up.forward.square")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(Color.white.opacity(0.85))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.white.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 0.75))
        }
    }

    private var notchSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Hover Grace Duration (\(String(format: "%.2f", hoverGraceDuration))s)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Adjust how quickly the notch reacts when the pointer leaves the hot zone.")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)

                Slider(value: $hoverGraceDuration, in: 0.05...0.4, step: 0.05)
                    .tint(.lnAccentBlue)
            }

            Divider().background(Color.white.opacity(0.06))

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Top Concave Ear Radius")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Fluid 22 pt Apple-style organic ear flare curve.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Text("22 pt")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.lnAccentBlue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.lnAccentBlue.opacity(0.18)))
            }
        }
    }

    private var shelfSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Clear All Staged Files")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Remove all files currently held in LazyShelf.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button("Clear Shelf") {
                    LazyShelfStore.shared.clearAll()
                }
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Color.red.opacity(0.9))
                .buttonStyle(.bordered)
            }

            Divider().background(Color.white.opacity(0.06))

            HStack(spacing: 12) {
                Image(systemName: "info.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.lnAccentBlue)
                Text("LazyShelf lets you drop files into the open shelf, preview them, drag them to other apps, and send them with AirDrop.")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var aboutSettingsSection: some View {
        VStack(alignment: .center, spacing: 10) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 36))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.lnAccentBlue, Color.purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("LazyNotch")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            Text("Version 1.0.0 · Production Suite")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))

            Text("Designed for macOS Sonoma & Sequoia.\nFluid spring physics, physical notch blending, and Dynamic Island widgets.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
