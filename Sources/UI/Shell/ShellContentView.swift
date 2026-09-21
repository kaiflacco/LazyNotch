import SwiftUI

// MARK: - Siri / Apple Intelligence Chromatic Palette

public struct SiriColors {
    public static let cyan = Color(red: 0.00, green: 0.88, blue: 0.96)
    public static let azure = Color(red: 0.10, green: 0.52, blue: 1.00)
    public static let purple = Color(red: 0.62, green: 0.26, blue: 0.98)
    public static let magenta = Color(red: 1.00, green: 0.18, blue: 0.68)
    public static let coral = Color(red: 1.00, green: 0.46, blue: 0.28)

    public static var fullGradient: LinearGradient {
        LinearGradient(
            colors: [cyan, azure, purple, magenta, coral],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public static var horizontalGradient: LinearGradient {
        LinearGradient(
            colors: [cyan, azure, purple, magenta, coral],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    public static var angularGradient: AngularGradient {
        AngularGradient(
            colors: [cyan, azure, purple, magenta, coral, cyan],
            center: .center
        )
    }
}

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

// MARK: - Blur Transition


extension AnyTransition {
    static var blurAndScale: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.85, anchor: .top)
                .combined(with: .opacity)
                .combined(with: .modifier(active: BlurModifier(radius: 12), identity: BlurModifier(radius: 0))),
            removal: .scale(scale: 0.85, anchor: .top)
                .combined(with: .opacity)
                .combined(with: .modifier(active: BlurModifier(radius: 12), identity: BlurModifier(radius: 0)))
        )
    }
}

// MARK: - Morphing Notch Island (Organic Continuous Physical Surface)

struct MorphingNotchIsland: View {
    @ObservedObject var viewModel: ShellViewModel
    @Namespace private var heroNamespace

    // Live Activity sizing geometry
    static let liveActivityTopRadius: CGFloat = 10.0
    static let liveActivityBottomRadius: CGFloat = 18.0
    static let liveActivityVisibleWingWidth: CGFloat = 30.0
    static let liveActivityBorderMargin: CGFloat = 2.0
    static var liveActivityWingExtension: CGFloat {
        liveActivityVisibleWingWidth + liveActivityTopRadius + liveActivityBorderMargin // 42.0pt
    }

    private var isDropHUDActive: Bool {
        viewModel.isExpanded && viewModel.globalDragZone != .none
    }

    private var targetWidth: CGFloat {
        if isDropHUDActive {
            return LazyNotchWindowController.dropHUDWidth
        } else if viewModel.isExpanded {
            return LazyNotchWindowController.openWidth
        } else if viewModel.hasActiveLiveActivity {
            return viewModel.compactSize.width + Self.liveActivityWingExtension * 2 + (viewModel.isHovered ? 6 : 0)
        } else {
            return viewModel.compactSize.width + (viewModel.isHovered ? 8 : 0)
        }
    }

    private var targetHeight: CGFloat {
        if isDropHUDActive {
            return LazyNotchWindowController.dropHUDHeight
        } else if viewModel.isExpanded {
            return LazyNotchWindowController.openHeight
        } else {
            // Strictly sync vertical size with the physical Mac notch, plus a tactile swell on hover
            return viewModel.compactSize.height + (viewModel.isHovered ? 4 : 0)
        }
    }

    private var targetTopRadius: CGFloat {
        if isDropHUDActive {
            return 16.0
        } else if viewModel.isExpanded {
            return 26.0
        } else if viewModel.hasActiveLiveActivity {
            return Self.liveActivityTopRadius + (viewModel.isHovered ? 2 : 0)
        } else {
            return viewModel.isHovered ? 4.0 : 0.0
        }
    }

    private var targetBottomRadius: CGFloat {
        if isDropHUDActive {
            return 28.0
        } else if viewModel.isExpanded {
            return 42.0
        } else if viewModel.hasActiveLiveActivity {
            return Self.liveActivityBottomRadius + (viewModel.isHovered ? 4 : 0)
        } else {
            return viewModel.isHovered ? 14.0 : 10.0
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
            .overlay(
                // Siri iridescent perimeter rim when in drop mode
                NotchShape(
                    topCornerRadius: targetTopRadius,
                    bottomCornerRadius: targetBottomRadius
                )
                .stroke(
                    isDropHUDActive
                        ? AnyShapeStyle(SiriColors.horizontalGradient.opacity(0.65))
                        : AnyShapeStyle(Color.clear),
                    lineWidth: 1.2
                )
            )
            .shadow(
                color: isDropHUDActive
                    ? SiriColors.purple.opacity(0.38)
                    : Color.black.opacity(
                        viewModel.isExpanded ? 0.38 : (viewModel.hasActiveLiveActivity ? (viewModel.isHovered ? 0.45 : 0.22) : 0.0)
                    ),
                radius: isDropHUDActive ? 22 : (viewModel.isExpanded ? 20 : (viewModel.hasActiveLiveActivity && viewModel.isHovered ? 16 : 8)),
                x: 0,
                y: isDropHUDActive ? 6 : (viewModel.isExpanded ? 10 : 3)
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
                        .transition(.blurAndScale)
                }

                // Expanded Full Nook Island Content
                if viewModel.isExpanded {
                    ExpandedNotchContent(viewModel: viewModel, selectedTab: $viewModel.activeTab, namespace: heroNamespace)
                        .frame(
                            width: targetWidth,
                            height: targetHeight,
                            alignment: .top
                        )
                        .transition(.blurAndScale)
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
                            .overlay(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                            )
                    } else {
                        fallbackAppIcon
                            .frame(width: 20, height: 20)
                    }
                }
                .matchedGeometryEffect(id: "albumArt", in: namespace)
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
                .frame(
                    width: LazyNotchWindowController.dropHUDWidth,
                    height: LazyNotchWindowController.dropHUDHeight
                )
                .transition(.opacity)
        } else {
            VStack(spacing: 2) {
                TopBar(selectedTab: $selectedTab)
                    .padding(.top, 12)
                    .padding(.horizontal, 36)

                Group {
                    switch selectedTab {
                    case .home:
                        HomeRow(namespace: namespace)
                    case .shelf:
                        LazyShelfView()
                    }
                }
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 36)
                .padding(.top, 4)
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .transition(.opacity)
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

            // Mirror button beside gear
            MirrorButton(compact: true)

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

// MARK: - Global Drop Zones (Siri Chromatic Drop Capsule)

struct GlobalDropZonesView: View {
    let activeZone: GlobalDragZone
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 10) {
            DropPod(
                title: "Files Tray",
                subtitle: "Drop to stage",
                systemImage: "tray.and.arrow.down.fill",
                isActive: activeZone == .tray,
                isPulse: pulse
            )

            DropPod(
                title: "AirDrop",
                subtitle: "Drop to share",
                systemImage: "airdrop",
                isActive: activeZone == .airdrop,
                isPulse: pulse
            )
        }
        .padding(.horizontal, 14)
        .padding(.top, 28) // Clear hardware notch
        .padding(.bottom, 10)
        .frame(
            width: LazyNotchWindowController.dropHUDWidth,
            height: LazyNotchWindowController.dropHUDHeight
        )
        .onAppear {
            withAnimation(
                .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
            ) {
                pulse = true
            }
        }
    }
}

// MARK: - Drop Pod

struct DropPod: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isActive: Bool
    let isPulse: Bool

    var body: some View {
        ZStack {
            // Ambient luminous backlight when active
            if isActive {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(SiriColors.horizontalGradient)
                    .blur(radius: 8)
                    .opacity(0.38)
            }

            // Glass background
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(
                    isActive
                        ? Color.white.opacity(0.12)
                        : Color.white.opacity(0.045)
                )

            // Dynamic border: Siri gradient border when active, ultra-fine glass stroke when resting
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(
                    isActive
                        ? AnyShapeStyle(SiriColors.horizontalGradient)
                        : AnyShapeStyle(Color.white.opacity(0.12)),
                    lineWidth: isActive ? 1.5 : 0.8
                )

            // Content
            HStack(spacing: 10) {
                // Icon badge with glowing aura
                ZStack {
                    Circle()
                        .fill(
                            isActive
                                ? AnyShapeStyle(SiriColors.fullGradient.opacity(0.25))
                                : AnyShapeStyle(Color.white.opacity(0.06))
                        )
                        .frame(width: 30, height: 30)

                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(
                            isActive
                                ? AnyShapeStyle(SiriColors.horizontalGradient)
                                : AnyShapeStyle(Color.white.opacity(0.72))
                        )
                        .scaleEffect(isActive ? (isPulse ? 1.08 : 1.0) : 1.0)
                }

                VStack(alignment: .leading, spacing: 1.5) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(isActive ? Color.white : Color.white.opacity(0.85))

                    Text(subtitle)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(
                            isActive
                                ? Color.white.opacity(0.75)
                                : Color.white.opacity(0.42)
                        )
                }

                Spacer(minLength: 0)

                // Active glowing indicator dot
                if isActive {
                    Circle()
                        .fill(SiriColors.horizontalGradient)
                        .frame(width: 6, height: 6)
                        .scaleEffect(isPulse ? 1.2 : 0.8)
                        .padding(.trailing, 2)
                }
            }
            .padding(.horizontal, 11)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scaleEffect(isActive ? 1.02 : 1.0)
        .animation(LazyNotchMotion.interactiveSpring, value: isActive)
    }
}
