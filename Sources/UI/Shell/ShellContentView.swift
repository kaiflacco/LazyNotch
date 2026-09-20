import SwiftUI

struct BlurModifier: ViewModifier, Animatable {
    nonisolated var radius: CGFloat
    
    nonisolated var animatableData: CGFloat {
        get { radius }
        set { radius = newValue }
    }
    
    func body(content: Content) -> some View {
        content.blur(radius: radius)
    }
}

extension AnyTransition {
    static func blur(radius: CGFloat) -> AnyTransition {
        .modifier(
            active: BlurModifier(radius: radius),
            identity: BlurModifier(radius: 0)
        )
    }
}

/// The LazyNotch silhouette: concave top "ears" that tuck against the physical
/// notch's rounded lower corners, so the panel reads as one continuous cutout.
struct NotchShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    init(topCornerRadius: CGFloat = 10, bottomCornerRadius: CGFloat = 26) {
        self.topCornerRadius = topCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
    }

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { .init(topCornerRadius, bottomCornerRadius) }
        set { topCornerRadius = newValue.first; bottomCornerRadius = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY + topCornerRadius),
            control: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY - bottomCornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topCornerRadius + bottomCornerRadius, y: rect.maxY),
            control: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - topCornerRadius - bottomCornerRadius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY - bottomCornerRadius),
            control: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - topCornerRadius, y: rect.minY + topCornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - topCornerRadius, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        return path
    }
}

/// Mini live audio waveform shown on the closed notch like Dynamic Island.
struct MiniAudioWaveform: View {
    var color: Color = Color(red: 0.98, green: 0.18, blue: 0.33)
    @State private var phase: CGFloat = 0

    var body: some View {
        HStack(spacing: 2.5) {
            bar(multiplier: 0.6)
            bar(multiplier: 1.0)
            bar(multiplier: 0.75)
            bar(multiplier: 0.45)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true)) {
                phase = 1.0
            }
        }
    }

    private func bar(multiplier: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(color)
            .frame(width: 2.5, height: 6 + (phase > 0.5 ? 13 * multiplier : 4 * multiplier))
            .animation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true), value: phase)
    }
}

/// Root SwiftUI view of the LazyNotch shell.
struct ShellContentView: View {
    @ObservedObject var viewModel: ShellViewModel

    enum ShellTab: String, CaseIterable {
        case home = "Home"
        case shelf = "Shelf"
    }

    var body: some View {
        ZStack(alignment: .top) {
            MorphingNotchIsland(viewModel: viewModel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Morphing Notch Island (Organic Continuous Physical Surface)

struct MorphingNotchIsland: View {
    @ObservedObject var viewModel: ShellViewModel
    @Namespace private var heroNamespace

    // Live Activity sizing geometry
    static let liveActivityTopRadius: CGFloat = 6.0
    static let liveActivityBottomRadius: CGFloat = 10.0
    static let liveActivityVisibleWingWidth: CGFloat = 30.0
    static let liveActivityBorderMargin: CGFloat = 2.0
    static var liveActivityWingExtension: CGFloat {
        liveActivityVisibleWingWidth + liveActivityTopRadius + liveActivityBorderMargin // 38.0pt
    }

    private var targetWidth: CGFloat {
        if viewModel.isExpanded {
            return LazyNotchWindowController.openWidth
        } else if viewModel.hasActiveLiveActivity {
            return viewModel.compactSize.width + Self.liveActivityWingExtension * 2
        } else {
            return viewModel.compactSize.width
        }
    }

    private var targetHeight: CGFloat {
        if viewModel.isExpanded {
            return LazyNotchWindowController.openHeight
        } else {
            // Strictly sync vertical size with the physical Mac notch
            return viewModel.compactSize.height
        }
    }

    private var targetTopRadius: CGFloat {
        if viewModel.isExpanded {
            return 20.0
        } else if viewModel.hasActiveLiveActivity {
            return Self.liveActivityTopRadius
        } else {
            return 0.0
        }
    }

    private var targetBottomRadius: CGFloat {
        if viewModel.isExpanded {
            return 36.0
        } else if viewModel.hasActiveLiveActivity {
            return Self.liveActivityBottomRadius
        } else {
            return 10.0
        }
    }

    private var isIslandVisible: Bool {
        viewModel.isExpanded || viewModel.hasActiveLiveActivity
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Morphing black notch hardware shell — solid continuous physical surface
            NotchShape(
                topCornerRadius: targetTopRadius,
                bottomCornerRadius: targetBottomRadius
            )
            .fill(Color.black)
            .shadow(
                color: Color.black.opacity(
                    viewModel.isExpanded ? 0.38 : (viewModel.hasActiveLiveActivity ? 0.22 : 0.0)
                ),
                radius: viewModel.isExpanded ? 20 : 8,
                x: 0,
                y: viewModel.isExpanded ? 10 : 3
            )
            .shadow(
                color: Color.black.opacity(viewModel.isExpanded ? 0.25 : 0.0),
                radius: viewModel.isExpanded ? 30 : 0,
                x: 0,
                y: viewModel.isExpanded ? 14 : 0
            )

            // Content container clipped to the current morphing notch silhouette
            ZStack(alignment: .top) {
                // Collapsed Live Activity Strip
                if !viewModel.isExpanded && viewModel.hasActiveLiveActivity {
                    CompactNotchContent(viewModel: viewModel, namespace: heroNamespace)
                        .frame(width: targetWidth, height: targetHeight)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.86, anchor: .top).combined(with: .opacity).combined(with: .blur(radius: 4)),
                            removal: .scale(scale: 0.86, anchor: .top).combined(with: .opacity).combined(with: .blur(radius: 4))
                        ))
                }

                // Expanded Full Nook Island Content
                if viewModel.isExpanded {
                    ExpandedNotchContent(viewModel: viewModel, selectedTab: $viewModel.activeTab, namespace: heroNamespace)
                        .frame(
                            width: LazyNotchWindowController.openWidth,
                            height: LazyNotchWindowController.openHeight,
                            alignment: .top
                        )
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.92, anchor: .top).combined(with: .opacity).combined(with: .offset(y: -12)).combined(with: .blur(radius: 12)),
                            removal: .scale(scale: 0.92, anchor: .top).combined(with: .opacity).combined(with: .offset(y: -12)).combined(with: .blur(radius: 12))
                        ))
                }
            }
            .frame(width: targetWidth, height: targetHeight, alignment: .top)
            .clipShape(
                NotchShape(
                    topCornerRadius: targetTopRadius,
                    bottomCornerRadius: targetBottomRadius
                )
            )
        }
        .frame(width: targetWidth, height: targetHeight, alignment: .top)
        .contentShape(
            NotchShape(
                topCornerRadius: targetTopRadius,
                bottomCornerRadius: targetBottomRadius
            )
        )
        .onTapGesture {
            if !viewModel.isExpanded {
                withAnimation(LazyNotchMotion.shellSpring(isExpanded: true)) {
                    viewModel.isExpanded = true
                }
            }
        }
        .opacity(isIslandVisible ? 1.0 : 0.0)
        .animation(LazyNotchMotion.interactiveSpring, value: isIslandVisible)
        // Master organic spring physics matching NotchNook / iOS Dynamic Island:
        .animation(LazyNotchMotion.shellSpring(isExpanded: viewModel.isExpanded), value: viewModel.isExpanded)
        .animation(LazyNotchMotion.pillMorphSpring, value: viewModel.hasActiveLiveActivity)
        .animation(LazyNotchMotion.hoverSpring, value: viewModel.isHovered)
    }
}

struct CompactNotchContent: View {
    @ObservedObject var viewModel: ShellViewModel
    let namespace: Namespace.ID
    @ObservedObject var mediaService = MediaService.shared

    private var isSpotify: Bool {
        mediaService.currentTrack?.appName == "Spotify"
    }

    private var appColor: Color {
        isSpotify ? Color(red: 0.12, green: 0.86, blue: 0.38) : Color(red: 0.98, green: 0.18, blue: 0.33)
    }

    var body: some View {
        if viewModel.hasActiveLiveActivity {
            let topRadius = MorphingNotchIsland.liveActivityTopRadius
            let borderMargin = MorphingNotchIsland.liveActivityBorderMargin
            let wingWidth = MorphingNotchIsland.liveActivityVisibleWingWidth
            let contentHeight = viewModel.compactSize.height
            let totalWidth = viewModel.compactSize.width + (topRadius + borderMargin + wingWidth) * 2

            HStack(spacing: 0) {
                // 1. Left top-ear flare & 2px border margin inset
                Spacer()
                    .frame(width: topRadius + borderMargin, height: contentHeight)

                // 2. Visible Left Wing Section (strictly centered in the visible black body!)
                ZStack(alignment: .center) {
                    if let image = mediaService.cachedArtwork {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 20, height: 20)
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .frame(width: 20, height: 20)
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                        )
                    } else {
                        fallbackAppIcon
                            .frame(width: 20, height: 20)
                    }
                }
                .frame(width: wingWidth, height: contentHeight, alignment: .center)

                // 3. Hardware Notch Cutout Gap
                Spacer()
                    .frame(width: viewModel.compactSize.width, height: contentHeight)

                // 4. Visible Right Wing Section (strictly centered in the visible black body!)
                ZStack(alignment: .center) {
                    MiniAudioWaveform(color: appColor)
                }
                .frame(width: wingWidth, height: contentHeight, alignment: .center)

                // 5. Right top-ear flare & 2px border margin inset
                Spacer()
                    .frame(width: topRadius + borderMargin, height: contentHeight)
            }
            .frame(width: totalWidth, height: contentHeight)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(LazyNotchMotion.shellSpring(isExpanded: true)) {
                    viewModel.isExpanded = true
                }
            }
            .opacity(viewModel.isHovered ? 1.0 : 0.94)
            .animation(LazyNotchMotion.interactiveSpring, value: viewModel.isHovered)
        }
    }

    private var fallbackAppIcon: some View {
        Circle()
            .fill(appColor)
            .frame(width: 11, height: 11)
            .overlay(
                Image(systemName: isSpotify ? "waveform" : "music.note")
                    .font(.system(size: 5.5, weight: .bold))
                    .foregroundStyle(.white)
            )
    }
}

// MARK: - Expanded Content

struct ExpandedNotchContent: View {
    @ObservedObject var viewModel: ShellViewModel
    @Binding var selectedTab: ShellContentView.ShellTab
    let namespace: Namespace.ID

    var body: some View {
        if viewModel.globalDragZone != .none {
            GlobalDropZonesView(activeZone: viewModel.globalDragZone)
        } else {
            VStack(spacing: 4) {
            TopBar(selectedTab: $selectedTab)
                .padding(.top, 12)
                .padding(.horizontal, 34)

            Group {
                switch selectedTab {
                case .home:
                    HomeRow(namespace: namespace)
                case .shelf:
                    LazyShelfView()
                }
            }
            .frame(maxHeight: .infinity)
            .padding(.horizontal, 34)
            .padding(.top, 2)
            .padding(.bottom, 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

// MARK: - Top bar

struct TopBar: View {
    @Binding var selectedTab: ShellContentView.ShellTab
    @Namespace private var tabNamespace
    @State private var gearHovered = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ShellContentView.ShellTab.allCases, id: \.self) { tab in
                let isSelected = selectedTab == tab
                Button {
                    withAnimation(LazyNotchMotion.tabSpring) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 4.5) {
                        Image(systemName: tab == .home ? "house.fill" : "square.stack.fill")
                            .font(.system(size: 11, weight: .medium))
                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.55))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(Color.white.opacity(0.18))
                                .matchedGeometryEffect(id: "activeTab", in: tabNamespace)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button {
                SettingsWindowController.shared.showSettings()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(gearHovered ? Color.white : Color.white.opacity(0.7))
                    .frame(width: 26, height: 26)
                    .background(
                        Circle()
                            .fill(gearHovered ? Color.white.opacity(0.14) : Color.clear)
                    )
                    .scaleEffect(gearHovered ? 1.06 : 1.0)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(LazyNotchMotion.interactiveSpring) {
                    gearHovered = hovering
                }
            }
        }
    }
}

// MARK: - Global Drop Zones

struct GlobalDropZonesView: View {
    let activeZone: GlobalDragZone
    @State private var pulse = false

    private let blue = Color(red: 0.18, green: 0.49, blue: 0.97)
    private let navyBg = Color(red: 0.07, green: 0.13, blue: 0.28)

    var body: some View {
        HStack(spacing: 10) {
            trayZone
            airdropZone
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
            ) { pulse = true }
        }
    }

    // MARK: Files Tray
    private var trayZone: some View {
        let isActive = activeZone == .tray
        return ZStack {
            // Background
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isActive
                    ? Color.black.opacity(0.85)
                    : Color.white.opacity(0.04)
                )

            // Border
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    isActive ? blue.opacity(pulse ? 1.0 : 0.65) : Color.white.opacity(0.12),
                    style: StrokeStyle(lineWidth: isActive ? 1.8 : 1.0, dash: [7, 5])
                )
                .animation(isActive ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true) : .default, value: pulse)

            // Content
            VStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill(isActive ? blue.opacity(0.15) : Color.clear)
                        .frame(width: 38, height: 38)
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isActive ? blue : Color.white.opacity(0.55))
                        .scaleEffect(isActive ? (pulse ? 1.08 : 1.0) : 1.0)
                        .animation(isActive ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true) : .default, value: pulse)
                }

                Text("Files Tray")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isActive ? blue : Color.white.opacity(0.55))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(LazyNotchMotion.interactiveSpring, value: isActive)
    }

    // MARK: AirDrop
    private var airdropZone: some View {
        let isActive = activeZone == .airdrop
        return ZStack {
            // Background — solid dark navy when idle, slightly lighter when active
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isActive
                    ? navyBg.opacity(0.95)
                    : navyBg.opacity(0.7)
                )

            // Subtle inner glow rim
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    isActive ? blue.opacity(0.45) : Color.white.opacity(0.06),
                    lineWidth: 1
                )

            // Content
            VStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill(isActive ? blue.opacity(0.2) : Color.white.opacity(0.05))
                        .frame(width: 38, height: 38)
                    // AirDrop radiating waves icon
                    Image(systemName: "wifi")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isActive ? blue : Color.white.opacity(0.70))
                        .rotationEffect(.degrees(180))
                        .scaleEffect(isActive ? (pulse ? 1.08 : 1.0) : 1.0)
                        .animation(isActive ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true) : .default, value: pulse)
                }

                Text("AirDrop")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isActive ? Color.white : Color.white.opacity(0.70))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(LazyNotchMotion.interactiveSpring, value: isActive)
    }
}
