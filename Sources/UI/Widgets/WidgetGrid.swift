import SwiftUI

struct HomeRow: View {
    let namespace: Namespace.ID

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            MediaWidget(namespace: namespace)
                .frame(width: 224, alignment: .leading)

            Spacer(minLength: 0)

            MirrorButton()

            Spacer(minLength: 0)

            CalendarWidget()
                .frame(width: 224, alignment: .center)
        }
        .frame(maxHeight: .infinity)
    }
}

// MARK: - Vinyl Artwork

struct VinylArtwork: View {
    var track: MediaTrack?
    let namespace: Namespace.ID
    @State private var isHovered = false

    private var isSpotify: Bool {
        track?.appName == "Spotify"
    }

    private var appIcon: NSImage? {
        if isSpotify {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.spotify.client") {
                return NSWorkspace.shared.icon(forFile: url.path)
            }
        } else if track?.appName == "Music" || track?.appName == "Apple Music" {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Music") {
                return NSWorkspace.shared.icon(forFile: url.path)
            }
        }
        if let appName = track?.appName,
           let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appName) {
            return NSWorkspace.shared.icon(forFile: appUrl.path)
        }
        return nil
    }

    var body: some View {
        Button {
            MediaService.shared.activateApp()
        } label: {
            ZStack(alignment: .bottomTrailing) {
                // Real Album Artwork or Stylized Fallback Vinyl Record
                Group {
                    if let artUrl = track?.artworkUrl, let url = URL(string: artUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure:
                                fallbackVinyl
                            case .empty:
                                ZStack {
                                    Color(red: 0.12, green: 0.12, blue: 0.14)
                                    ProgressView()
                                        .scaleEffect(0.6)
                                }
                            @unknown default:
                                fallbackVinyl
                            }
                        }
                    } else if let image = track?.artwork {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        fallbackVinyl
                    }
                }
                .frame(width: 94, height: 94)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(isHovered ? 0.35 : 0.14), lineWidth: isHovered ? 1.0 : 0.75)
                )
                .shadow(color: .black.opacity(isHovered ? 0.55 : 0.35), radius: isHovered ? 7 : 4, y: isHovered ? 3.5 : 2)
                .scaleEffect(isHovered ? 1.04 : 1.0)
                .animation(.spring(response: 0.35, dampingFraction: 0.72), value: isHovered)

                // Real App Icon at bottom-right of the album cover
                Group {
                    if let icon = appIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 22, height: 22)
                            .shadow(color: .black.opacity(0.55), radius: 3, y: 1.5)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(
                                    isSpotify
                                        ? LinearGradient(
                                            colors: [Color(red: 0.12, green: 0.86, blue: 0.38), Color(red: 0.08, green: 0.70, blue: 0.30)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                        : LinearGradient(
                                            colors: [Color(red: 1.0, green: 0.25, blue: 0.40), Color(red: 0.90, green: 0.12, blue: 0.28)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                )
                                .frame(width: 20, height: 20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                                )
                                .shadow(color: (isSpotify ? Color.green : Color.lnMusicRed).opacity(0.4), radius: 3.5, y: 1)

                            Image(systemName: isSpotify ? "waveform" : "music.note")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .offset(x: 4, y: 4)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var fallbackVinyl: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.14, green: 0.14, blue: 0.15), Color(red: 0.08, green: 0.08, blue: 0.09)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .strokeBorder(Color.white.opacity(isHovered ? 0.09 : 0.06), lineWidth: 1)
                .padding(3.5)
            Circle()
                .strokeBorder(Color.white.opacity(isHovered ? 0.07 : 0.04), lineWidth: 1)
                .padding(7)
            Circle()
                .strokeBorder(Color.white.opacity(isHovered ? 0.06 : 0.03), lineWidth: 1)
                .padding(10.5)

            Circle()
                .fill(Color(red: 0.83, green: 0.78, blue: 0.70))
                .padding(13)
                .overlay(
                    Circle()
                        .strokeBorder(Color(red: 0.25, green: 0.23, blue: 0.21), lineWidth: 3)
                        .padding(13)
                )

            VStack(spacing: 1) {
                Text(track?.appName.uppercased() ?? "VINYL")
                    .font(.system(size: 4.2, weight: .bold))
                    .foregroundStyle(Color(red: 0.18, green: 0.16, blue: 0.15))
                    .kerning(0.2)
                    .padding(.top, 17)

                Spacer()

                VStack(spacing: 0.5) {
                    Text(track?.title.prefix(10).uppercased() ?? "RECORD")
                        .font(.system(size: 6.5, weight: .black, design: .serif))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 3.5)
                        .padding(.vertical, 0.5)
                        .background(Color(red: 0.15, green: 0.14, blue: 0.13))
                    Text(track?.artist.prefix(12).uppercased() ?? "ALBUM")
                        .font(.system(size: 4.5, weight: .heavy))
                        .foregroundStyle(Color(red: 0.18, green: 0.16, blue: 0.15))
                        .kerning(0.3)
                }

                Spacer()

                Text(track != nil ? (track!.isPlaying ? "PLAYING" : "PAUSED") : "READY")
                    .font(.system(size: 4.2, weight: .medium))
                    .foregroundStyle(Color(red: 0.22, green: 0.20, blue: 0.18))
                    .padding(.bottom, 17)
            }

            Circle()
                .fill(Color.black)
                .frame(width: 6.5, height: 6.5)
        }
    }
}

// MARK: - Media widget

struct MediaWidget: View {
    let namespace: Namespace.ID
    @ObservedObject var mediaService = MediaService.shared

    private var isPlaying: Bool {
        mediaService.currentTrack?.isPlaying ?? false
    }

    private var appColor: Color {
        (mediaService.currentTrack?.appName == "Spotify") ? Color(red: 0.12, green: 0.86, blue: 0.38) : Color(red: 0.98, green: 0.18, blue: 0.33)
    }

    var body: some View {
        HStack(spacing: 12) {
            VinylArtwork(track: mediaService.currentTrack, namespace: namespace)

            VStack(alignment: .leading, spacing: 3) {
                Text(mediaService.currentTrack?.title ?? "No Media Playing")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.lnTextPrimary)
                    .lineLimit(1)

                Text(mediaService.currentTrack?.album.replacingOccurrences(of: "\"", with: "") ?? "Open Media Player")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.lnTextSecondary)
                    .lineLimit(1)

                Text(mediaService.currentTrack?.artist ?? "Ready")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.45))
                    .lineLimit(1)

                HStack(spacing: 14) {
                    MediaControlButton(systemName: "backward.fill", size: 12) {
                        mediaService.previousTrack()
                    }

                    MediaControlButton(systemName: isPlaying ? "pause.fill" : "play.fill", size: 15, isProminent: true) {
                        mediaService.togglePlayPause()
                    }

                    MediaControlButton(systemName: "forward.fill", size: 12) {
                        mediaService.nextTrack()
                    }
                }
                .padding(.top, 2)
            }
            // Fill the fixed column width from HomeRow so the media widget occupies
            // its full 224pt slot — keeps the gap to the camera button even with
            // the gap to the calendar widget (Spacer would otherwise leave slack).
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct MediaControlButton: View {
    let systemName: String
    let size: CGFloat
    var isProminent: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: isProminent ? .bold : .semibold))
                .foregroundStyle(isHovered ? .white : (isProminent ? .white : .white.opacity(0.85)))
                .frame(width: isProminent ? 28 : 24, height: isProminent ? 28 : 24)
                .background(
                    Circle()
                        .fill(isHovered ? Color.white.opacity(0.14) : Color.clear)
                )
                .scaleEffect(isHovered ? 1.08 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(LazyNotchMotion.interactiveSpring) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Mirror button (Dynamic Island quick action)

struct MirrorButton: View {
    @State private var isHovered = false

    var body: some View {
        Button {
            NotificationCenter.default.post(name: NSNotification.Name("LazyNotchCollapseRequest"), object: nil)
            MirrorWindowController.shared.toggleMirror()
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isHovered ? 0.16 : 0.10),
                                Color.white.opacity(isHovered ? 0.08 : 0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 54, height: 54)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(isHovered ? 0.26 : 0.14),
                                        Color.white.opacity(isHovered ? 0.10 : 0.04)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.75
                            )
                    )
                    .shadow(color: Color.black.opacity(isHovered ? 0.35 : 0.2), radius: isHovered ? 5 : 3, y: 1.5)

                Image(systemName: "web.camera")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(isHovered ? .white : Color.white.opacity(0.92))
            }
            .scaleEffect(isHovered ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(LazyNotchMotion.interactiveSpring) {
                isHovered = hovering
            }
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

    private var monthAndYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: selectedDate)
    }

    private func weekdayLetter(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"
        return formatter.string(from: date).uppercased()
    }

    private func weekdayLong(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
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

// MARK: - Shelf tab placeholder

struct ShelfPlaceholder: View {
    @State private var isHovered = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(isHovered ? 0.06 : 0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.white.opacity(isHovered ? 0.20 : 0.10), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                )
                .animation(.easeInOut(duration: 0.2), value: isHovered)

            VStack(spacing: 6) {
                Image(systemName: "tray.and.arrow.down")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(isHovered ? Color.white : Color.white.opacity(0.6))
                    .scaleEffect(isHovered ? 1.08 : 1.0)
                    .animation(LazyNotchMotion.interactiveSpring, value: isHovered)

                Text("Drop files here to stage them")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(Color.lnTextSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
