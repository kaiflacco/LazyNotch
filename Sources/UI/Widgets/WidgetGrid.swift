import AppKit
import SwiftUI

// MARK: - Home Row (Premium Layout)

struct HomeRow: View {
    let namespace: Namespace.ID
    var progress: CGFloat = 1.0
    var isExpanded: Bool = true
    init(namespace: Namespace.ID, progress: CGFloat = 1.0, isExpanded: Bool = true) {
        self.namespace = namespace
        self.progress = progress
        self.isExpanded = isExpanded
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Left: Full media player
            MediaWidget(namespace: namespace, progress: progress, isExpanded: isExpanded)
                .frame(maxWidth: .infinity)

            // Hairline divider
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 0.5)
                .padding(.vertical, 14)
                .morphReveal(progress)

            // Right: Calendar
            CalendarWidget()
                .frame(width: 216)
                .padding(.leading, 14)
                .morphReveal(progress)
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Vinyl Artwork

@MainActor
enum MediaSourceIconResolver {
    private static var cache: [String: NSImage] = [:]

    static func icon(for track: MediaTrack?) -> NSImage? {
        guard let track else { return nil }

        let bundleIdentifier = track.bundleIdentifier ?? {
            if track.appName == "Spotify" { return "com.spotify.client" }
            if track.appName == "Music" || track.appName == "Apple Music" { return "com.apple.Music" }
            return nil
        }()
        guard let bundleIdentifier else { return nil }
        if let cached = cache[bundleIdentifier] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return nil }

        let icon = NSWorkspace.shared.icon(forFile: url.path)
        cache[bundleIdentifier] = icon
        return icon
    }
}

struct VinylArtwork: View {
    var track: MediaTrack?
    let namespace: Namespace.ID
    var progress: CGFloat = 1.0
    var isExpanded: Bool = true
    @ObservedObject private var mediaService = MediaService.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    init(track: MediaTrack?, namespace: Namespace.ID, progress: CGFloat = 1.0, isExpanded: Bool = true) {
        self.track = track
        self.namespace = namespace
        self.progress = progress
        self.isExpanded = isExpanded
    }

    private var isSpotify: Bool {
        track?.appName == "Spotify"
    }

    private var appIcon: NSImage? {
        MediaSourceIconResolver.icon(for: track)
    }

    var body: some View {
        Button {
            MediaService.shared.activateApp()
        } label: {
            GeometryReader { geo in
                let side = geo.size.height
                let cornerRadius = side * 0.18

                ZStack(alignment: .bottomTrailing) {
                    // The halo belongs to the expanded artwork only. Leaving it mounted
                    // during collapse creates the detached glow seen beside the shell.
                    if isExpanded {
                        artworkContent
                            .frame(width: side, height: side)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                            .blur(radius: 20 * progress)
                            .opacity(Double(progress) * 0.55)
                            .scaleEffect(1.15)
                            .allowsHitTesting(false)
                    }

                    // Keep the real artwork mounted until the shell finishes collapsing.
                    // CompactNotchContent is mounted at the same time, so SwiftUI can
                    // animate this view all the way back to the live-activity cover.
                    artworkContent
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        .matchedGeometryEffect(id: "albumArt", in: namespace, isSource: isExpanded)
                        .frame(width: side, height: side)
                        // Use the same blur curve in both directions: opening resolves
                        // from blurred to sharp, and closing defocuses before the cover
                        // reaches the compact live-activity endpoint.
                        .blur(radius: reduceMotion ? 0 : (1.0 - progress) * LazyNotchMotion.heroBlurRadius)
                        .scaleEffect(isHovered && isExpanded ? 1.03 : 1.0)
                        .animation(.spring(response: 0.30, dampingFraction: 0.70), value: isHovered)

                    // Keep the badge mounted through the close so it defocuses with the
                    // artwork instead of disappearing sharply at the state flip.
                    appIconBadge
                        .opacity(Double(progress))
                        .blur(radius: reduceMotion ? 0 : (1.0 - progress) * LazyNotchMotion.heroBlurRadius)
                        .padding(4)
                }
                .frame(width: side, height: side)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    @ViewBuilder
    private var artworkContent: some View {
        if let image = mediaService.cachedArtwork {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(1, contentMode: .fill)
                .clipped()
        } else {
            fallbackVinyl
        }
    }

    @ViewBuilder
    private var appIconBadge: some View {
        if let icon = appIcon {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .shadow(color: .black.opacity(0.6), radius: 4, y: 2)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        isSpotify
                            ? LinearGradient(
                                colors: [Color(red: 0.12, green: 0.86, blue: 0.38), Color(red: 0.08, green: 0.70, blue: 0.30)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color(red: 1.0, green: 0.25, blue: 0.40), Color(red: 0.90, green: 0.12, blue: 0.28)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                    )
                    .frame(width: 22, height: 22)
                    .shadow(color: (isSpotify ? Color.green : Color.lnMusicRed).opacity(0.5), radius: 4, y: 1)
                Image(systemName: isSpotify ? "waveform" : "music.note")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }

    private var fallbackVinyl: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.16, green: 0.14, blue: 0.18), Color(red: 0.09, green: 0.08, blue: 0.10)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Image(systemName: "music.note")
                .font(.system(size: 32, weight: .thin))
                .foregroundStyle(Color.white.opacity(0.20))
        }
    }
}

// MARK: - Media Widget (Premium)

struct MediaWidget: View {
    let namespace: Namespace.ID
    var progress: CGFloat = 1.0
    var isExpanded: Bool = true
    @ObservedObject var mediaService = MediaService.shared

    init(namespace: Namespace.ID, progress: CGFloat = 1.0, isExpanded: Bool = true) {
        self.namespace = namespace
        self.progress = progress
        self.isExpanded = isExpanded
    }

    private var isPlaying: Bool {
        mediaService.currentTrack?.isPlaying ?? false
    }

    private var appColor: Color {
        (mediaService.currentTrack?.appName == "Spotify") ? Color(red: 0.12, green: 0.86, blue: 0.38) : Color(red: 0.98, green: 0.18, blue: 0.33)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // Album art — reacts to track changes via cachedArtwork and id(title)
            // NOT morph-revealed: the artwork is the matchedGeometryEffect hero element
            // that flies in from the live-activity strip and must stay visible mid-flight.
            VinylArtwork(track: mediaService.currentTrack, namespace: namespace, progress: progress, isExpanded: isExpanded)
                .frame(maxHeight: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .id(mediaService.currentTrack?.title ?? "")

            // Info + controls
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)

                // Title
                Text(mediaService.currentTrack?.displayTitle ?? "Nothing Playing")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)

                // Artist
                Text(mediaService.currentTrack?.displayArtist ?? "Open a media app")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .lineLimit(1)
                    .padding(.top, 3)

                Spacer(minLength: 8)

                // Progress bar + time
                if let track = mediaService.currentTrack, track.duration > 0 {
                    let progress = min(max(track.elapsedTime / track.duration, 0), 1)
                    VStack(alignment: .leading, spacing: 4) {
                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.15))
                                    .frame(height: 3)
                                Capsule()
                                    .fill(Color.white.opacity(0.85))
                                    .frame(width: geo.size.width * progress, height: 3)
                            }
                        }
                        .frame(height: 3)

                        // Time labels
                        HStack {
                            Text(formatTime(track.elapsedTime))
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.45))
                            Spacer()
                            Text(formatTime(track.duration))
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.35))
                        }
                    }
                }

                Spacer(minLength: 8)

                // Controls row
                HStack(spacing: 0) {
                    MediaControlButton(systemName: "backward.fill", size: 13) {
                        mediaService.previousTrack()
                    }
                    MediaControlButton(systemName: isPlaying ? "pause.fill" : "play.fill", size: 18, isProminent: true) {
                        mediaService.togglePlayPause()
                    }
                    MediaControlButton(systemName: "forward.fill", size: 13) {
                        mediaService.nextTrack()
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .morphReveal(progress)
        }
        .frame(maxHeight: .infinity)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

struct MediaControlButton: View {
    let systemName: String
    let size: CGFloat
    var isProminent: Bool = false
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: isProminent ? .bold : .semibold))
                .foregroundStyle(.white.opacity(isHovered ? 1.0 : 0.80))
                .frame(width: isProminent ? 36 : 30, height: isProminent ? 36 : 30)
                .background(
                    Circle()
                        .fill(isProminent
                            ? Color.white.opacity(isHovered ? 0.18 : 0.10)
                            : Color.white.opacity(isHovered ? 0.10 : 0.0))
                )
                .scaleEffect(isPressed ? 0.96 : (isHovered ? 1.03 : 1.0))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeIn(duration: 0.08)) { isPressed = true } }
                .onEnded { _ in withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isPressed = false } }
        )
        .onHover { hovering in
            withAnimation(LazyNotchMotion.interactiveSpring) { isHovered = hovering }
        }
    }
}

// MARK: - Mirror button

struct MirrorButton: View {
    var compact: Bool = false
    @State private var isHovered = false

    var body: some View {
        Button {
            NotificationCenter.default.post(name: NSNotification.Name("LazyNotchCollapseRequest"), object: nil)
            MirrorWindowController.shared.toggleMirror()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: compact ? 10 : 27, style: .continuous)
                    .fill(Color.white.opacity(isHovered ? 0.14 : 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: compact ? 10 : 27, style: .continuous)
                            .stroke(Color.white.opacity(isHovered ? 0.22 : 0.10), lineWidth: 0.75)
                    )
                    .frame(width: compact ? 36 : 54, height: compact ? 30 : 54)

                Image(systemName: "web.camera")
                    .font(.system(size: compact ? 14 : 20, weight: .medium))
                    .foregroundStyle(isHovered ? .white : Color.white.opacity(0.80))
            }
            .scaleEffect(isHovered ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(LazyNotchMotion.interactiveSpring) { isHovered = hovering }
        }
    }
}

// MARK: - Calendar widget (Apple glass week strip & schedule glance)

struct CalendarWidget: View {
    @ObservedObject private var calendarService = CalendarService.shared
    private let calendar = Calendar.current
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date.now)

    struct DayItem: Identifiable {
        let id = UUID()
        let date: Date
        let weekday: String
        let dayNumber: String
        let isToday: Bool
        let isSelected: Bool
        let hasEvents: Bool
    }

    private var displayDays: [DayItem] {
        let today = Date.now
        let selectedDayStart = calendar.startOfDay(for: selectedDate)

        // 7 days centered around today (-3 to +3)
        return (-3...3).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: today) ?? today
            let dayStart = calendar.startOfDay(for: date)
            let dayNum = calendar.component(.day, from: date)
            let isToday = (offset == 0)
            let isSelected = (dayStart == selectedDayStart)
            let weekday = weekdayLetter(date)
            let dayKey = CalendarService.dayKey(for: date)
            let hasEvents = !(calendarService.weekEvents[dayKey]?.isEmpty ?? true)

            return DayItem(
                date: date,
                weekday: weekday,
                dayNumber: "\(dayNum)",
                isToday: isToday,
                isSelected: isSelected,
                hasEvents: hasEvents
            )
        }
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter
    }()

    private static let weekdayLetterFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"
        return formatter
    }()

    private static let weekdayLongFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    private var monthAndYear: String {
        Self.monthFormatter.string(from: selectedDate)
    }

    private func weekdayLetter(_ date: Date) -> String {
        Self.weekdayLetterFormatter.string(from: date).uppercased()
    }

    private func weekdayLong(_ date: Date) -> String {
        Self.weekdayLongFormatter.string(from: date)
    }

    var body: some View {
        let selectedEvents = calendarService.events(for: selectedDate)

        VStack(alignment: .leading, spacing: 6) {
            // 1. Header: Month title + Today shortcut
            HStack(alignment: .center) {
                Text(monthAndYear)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.92))

                Spacer()

                if !calendar.isDateInToday(selectedDate) {
                    Button {
                        withAnimation(LazyNotchMotion.interactiveSpring) {
                            selectedDate = calendar.startOfDay(for: Date.now)
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 8.5, weight: .bold))
                            Text("Today")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(Color.white.opacity(0.85))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(weekdayLong(Date.now))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.42))
                }
            }
            .padding(.horizontal, 2)

            // 2. 7-Day Apple Glass Week Strip
            HStack(spacing: 3) {
                ForEach(displayDays) { item in
                    DayCell(item: item) {
                        withAnimation(LazyNotchMotion.interactiveSpring) {
                            selectedDate = calendar.startOfDay(for: item.date)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)

            // 3. Schedule Glance Card
            Group {
                if !calendarService.hasPermission {
                    Button {
                        calendarService.requestAccess()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(Color(red: 1.0, green: 0.65, blue: 0.2))

                            Text("Connect Calendar Access")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.90))

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.35))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5.5)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.045))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                } else if let first = selectedEvents.first {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color(red: 0.35, green: 0.65, blue: 1.0))
                            .frame(width: 3, height: 14)

                        Text(first.title)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.92))
                            .lineLimit(1)

                        Spacer(minLength: 4)

                        Text(first.formattedTime)
                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.55))

                        if selectedEvents.count > 1 {
                            Text("+\(selectedEvents.count - 1)")
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.8))
                                .padding(.horizontal, 4.5)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.white.opacity(0.12)))
                        }
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5.5)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                            )
                    )
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.35))

                        Text(calendar.isDateInToday(selectedDate) ? "No events scheduled today" : "No events scheduled")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.50))
                            .lineLimit(1)

                        Spacer()
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5.5)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.035))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                            )
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Day Cell Component

private struct DayCell: View {
    let item: CalendarWidget.DayItem
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2.5) {
                // Weekday letter (M, T, W, etc.)
                Text(item.weekday)
                    .font(.system(size: 9.5, weight: item.isSelected || item.isToday ? .bold : .medium))
                    .foregroundStyle(
                        item.isSelected
                            ? Color.white
                            : (item.isToday ? Color(red: 0.35, green: 0.65, blue: 1.0) : Color.white.opacity(0.40))
                    )

                // Day number (e.g. "20")
                Text(item.dayNumber)
                    .font(.system(size: 13, weight: item.isSelected || item.isToday ? .bold : .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(
                        item.isSelected
                            ? Color.white
                            : (item.isToday ? Color.white : Color.white.opacity(0.80))
                    )

                // Event dot
                Circle()
                    .fill(item.isSelected ? Color.white : Color(red: 0.35, green: 0.65, blue: 1.0))
                    .frame(width: 3.5, height: 3.5)
                    .opacity(item.hasEvents ? 0.9 : 0.0)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background {
                if item.isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.30), lineWidth: 0.75)
                        )
                        .shadow(color: Color.black.opacity(0.25), radius: 3, y: 1.5)
                } else if item.isToday {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(red: 0.35, green: 0.65, blue: 1.0).opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color(red: 0.35, green: 0.65, blue: 1.0).opacity(0.35), lineWidth: 0.75)
                        )
                } else if isHovered {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { h in
            isHovered = h
        }
    }
}
