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

/// iOS Dynamic Island–style waveform: center-anchored bars that grow symmetrically
/// up AND down from the midpoint, with pill-shaped caps — exactly like the reference image.
struct MiniAudioWaveform: View {
    var color: Color = Color(red: 0.98, green: 0.18, blue: 0.33)

    var body: some View {
        TimelineView(.animation) { tl in
            DynamicIslandEQ(time: tl.date.timeIntervalSinceReferenceDate,
                            color: color)
        }
        .frame(width: 22, height: 20)
    }
}

private struct DynamicIslandEQ: View {
    let time: Double
    let color: Color

    // 5 bars — outer bars shorter, center tallest (natural bell-curve envelope)
    private let speeds:  [Double]  = [2.3, 2.9, 1.8, 2.6, 2.1]
    private let offsets: [Double]  = [0.0, 1.3, 2.6, 0.7, 1.9]
    // min/max as fraction of the total half-height (bars grow up & down from center)
    private let minFrac: [CGFloat] = [0.12, 0.16, 0.22, 0.16, 0.12]
    private let maxFrac: [CGFloat] = [0.50, 0.78, 1.00, 0.78, 0.50]

    private let barWidth: CGFloat = 2.0
    private let barGap:   CGFloat = 1.6
    private let maxHalf:  CGFloat = 10.0  // max half-height (total = 20pt, matching 20pt cover art)

    var body: some View {
        Canvas { ctx, size in
            let totalW = CGFloat(speeds.count) * barWidth + CGFloat(speeds.count - 1) * barGap
            let startX = (size.width - totalW) / 2
            let cy     = size.height / 2  // vertical center

            for i in speeds.indices {
                let raw    = sin(time * speeds[i] + offsets[i]) // -1…1
                let norm   = CGFloat((raw + 1) / 2)             //  0…1
                let frac   = minFrac[i] + (maxFrac[i] - minFrac[i]) * norm
                let halfH  = max(1.2, frac * maxHalf)

                let x = startX + CGFloat(i) * (barWidth + barGap)
                let y = cy - halfH                              // grows UP & DOWN from center
                let h = halfH * 2

                let rect = CGRect(x: x, y: y, width: barWidth, height: h)
                ctx.fill(
                    Path(roundedRect: rect, cornerRadius: barWidth / 2),
                    with: .color(color)
                )
            }
        }
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

// MARK: - Fluid Notch Content Transition

/// Text and controls sharpen in place while the album cover follows its own hero path.
struct MorphRevealModifier: ViewModifier, Animatable {
    nonisolated var progress: CGFloat // 0.0 = hidden/blurred, 1.0 = revealed/sharp

    nonisolated var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .opacity(Double(progress))
            .blur(radius: (1.0 - progress) * 12)
    }
}

extension View {
    func morphReveal(_ progress: CGFloat) -> some View {
        modifier(MorphRevealModifier(progress: progress))
    }

}

// MARK: - Morphing Notch Island (Organic Continuous Physical Surface)

struct MorphingNotchIsland: View {
    @ObservedObject var viewModel: ShellViewModel
    @Namespace private var heroNamespace
    /// Drives the NotchNook-style content morph explicitly (blur → sharp) so the effect
    /// runs even when SwiftUI skips insertion transitions (e.g. inside matched geometry).
    @State private var contentProgress: CGFloat = 0.0
    /// Visual shell phase trails logical close so content can defocus before clipping.
    @State private var shellExpanded = false
    /// Keeps the expanded content in the tree briefly during collapse so it can blur out
    /// in place (symmetric with how it blurs in on expand) instead of vanishing instantly.
    @State private var expandedContentMounted = false
    /// Gradually reveals the compact banner during the cover's return flight.
    @State private var compactRevealProgress: CGFloat = 1.0

    // Live Activity sizing geometry
    static let liveActivityTopRadius: CGFloat = 10.0
    static let liveActivityBottomRadius: CGFloat = 18.0
    static let liveActivityVisibleWingWidth: CGFloat = 30.0
    static let liveActivityBorderMargin: CGFloat = 2.0
    static var liveActivityWingExtension: CGFloat {
        liveActivityVisibleWingWidth + liveActivityTopRadius + liveActivityBorderMargin // 42.0pt
    }

    private var isDropHUDActive: Bool {
        shellExpanded && viewModel.globalDragZone != .none
    }

    private var targetWidth: CGFloat {
        if isDropHUDActive {
            return LazyNotchWindowController.dropHUDWidth
        } else if shellExpanded {
            return LazyNotchWindowController.openWidth
        } else if viewModel.hasActiveLiveActivity {
            // NotchNook hover look: island droops slightly wider, anchored at the notch
            return viewModel.compactSize.width + Self.liveActivityWingExtension * 2 + (viewModel.isHovered ? 8 : 0)
        } else {
            return viewModel.compactSize.width
        }
    }

    private var targetHeight: CGFloat {
        if isDropHUDActive {
            return LazyNotchWindowController.dropHUDHeight
        } else if shellExpanded {
            return LazyNotchWindowController.openHeight
        } else if viewModel.hasActiveLiveActivity {
            // Subtle, sleek hover droop without excessive empty space at bottom
            return viewModel.compactSize.height + (viewModel.isHovered ? 5 : 0)
        } else {
            return viewModel.compactSize.height
        }
    }

    private var targetTopRadius: CGFloat {
        if isDropHUDActive {
            return 16.0
        } else if shellExpanded {
            return 26.0
        } else if viewModel.hasActiveLiveActivity {
            return Self.liveActivityTopRadius
        } else {
            return 0.0
        }
    }

    private var targetBottomRadius: CGFloat {
        if isDropHUDActive {
            return 28.0
        } else if shellExpanded {
            return 42.0
        } else if viewModel.hasActiveLiveActivity {
            return Self.liveActivityBottomRadius + (viewModel.isHovered ? 1.5 : 0)
        } else {
            return 10.0
        }
    }

    /// The shell only renders when there's something to show (live activity, expanded
    /// panel, drop HUD). In the idle state it draws NOTHING — the physical notch shows
    /// through untouched, instead of a black "copy" silhouette sitting on top of it.
    private var shouldShowShell: Bool {
        viewModel.hasActiveLiveActivity || shellExpanded
    }

    /// Actual render visibility. Shown instantly when the shell grows out of the physical
    /// notch; hidden only AFTER the collapse spring has fully shrunk it back, so the idle
    /// silhouette never lingers on screen as a duplicate of the physical notch.
    @State private var shellVisible = false

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
                        shellExpanded ? 0.38 : (viewModel.hasActiveLiveActivity ? (viewModel.isHovered ? 0.45 : 0.22) : (viewModel.isHovered ? 0.25 : 0.0))
                    ),
                radius: isDropHUDActive ? 22 : (shellExpanded ? 20 : (viewModel.hasActiveLiveActivity && viewModel.isHovered ? 18 : 8)),
                x: 0,
                y: isDropHUDActive ? 6 : (shellExpanded ? 10 : (viewModel.hasActiveLiveActivity && viewModel.isHovered ? 5 : 3))
            )
            .shadow(
                color: Color.black.opacity(shellExpanded ? 0.25 : 0.0),
                radius: shellExpanded ? 30 : 0,
                x: 0,
                y: shellExpanded ? 14 : 0
            )

            // Content container clipped to the current morphing notch silhouette
            ZStack(alignment: .top) {
                // Keep the live-activity endpoint mounted in both directions. During
                // opening it is hidden under blur while the main cover grows from it;
                // during closing it becomes the destination as the cover returns.
                if viewModel.hasActiveLiveActivity && (!viewModel.isExpanded || expandedContentMounted) {
                    CompactNotchContent(viewModel: viewModel, namespace: heroNamespace)
                        .frame(
                            width: viewModel.compactSize.width + Self.liveActivityWingExtension * 2,
                            height: viewModel.compactSize.height,
                            alignment: .top
                        )
                        .opacity(Double(compactRevealProgress))
                        .modifier(BlurModifier(radius: (1.0 - compactRevealProgress) * 8))
                        .allowsHitTesting(!viewModel.isExpanded)
                        .transition(.identity)
                }

                // Expanded Full Nook Island Content
                // Mounted the moment expansion starts (so it enters blurred within the same
                // transaction), and kept mounted briefly after collapse begins so it can
                // blur out in place — symmetric choreography both directions.
                if viewModel.isExpanded || expandedContentMounted {
                    ExpandedNotchContent(viewModel: viewModel, selectedTab: $viewModel.activeTab, namespace: heroNamespace, progress: contentProgress)
                        .frame(
                            width: viewModel.isExpanded ? targetWidth : LazyNotchWindowController.openWidth,
                            height: viewModel.isExpanded ? targetHeight : LazyNotchWindowController.openHeight,
                            alignment: .top
                        )
                        // The album artwork is EXCLUDED from the blur choreography (handled
                        // per-element inside) so its matchedGeometryEffect hero flight from
                        // the live-activity strip stays visible, like NotchNook.
                        // On collapse the content stays at open size and blurs out in place
                        // while the shrinking shell clips it — symmetric with the entrance.
                        .allowsHitTesting(viewModel.isExpanded)
                        .transition(.identity)
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
            if !viewModel.isExpanded && !viewModel.hasActiveLiveActivity {
                withAnimation(LazyNotchMotion.shellSpring(isExpanded: true)) {
                    viewModel.isExpanded = true
                }
            }
        }
        .opacity(shellVisible ? 1.0 : 0.0)
        .onAppear {
            shellExpanded = viewModel.isExpanded
            contentProgress = viewModel.isExpanded ? 1 : 0
            expandedContentMounted = viewModel.isExpanded
            compactRevealProgress = viewModel.isExpanded ? 0 : 1
            shellVisible = shouldShowShell
        }
        .onChange(of: shouldShowShell) { _, show in
            if show {
                // Appear instantly — the shell grows out of the physical notch, which is
                // already black, so no fade is needed and nothing pops.
                shellVisible = true
            } else {
                // Let the collapse spring shrink the shell back into the physical notch
                // first, then hide the idle silhouette with a quick fade so it never
                // reads as a copy of the notch.
                DispatchQueue.main.asyncAfter(deadline: .now() + LazyNotchMotion.collapseSettleDuration) {
                    guard !shouldShowShell else { return }
                    withAnimation(.easeOut(duration: 0.15)) {
                        shellVisible = false
                    }
                }
            }
        }
        .onChange(of: viewModel.isExpanded) { _, expanded in
            if expanded {
                shellExpanded = true
                expandedContentMounted = true
                compactRevealProgress = 0
                contentProgress = 0.0
                withAnimation(.easeInOut(duration: LazyNotchMotion.contentRevealDuration).delay(LazyNotchMotion.contentRevealDelay)) {
                    contentProgress = 1.0
                }
            } else {
                // Keep both geometry endpoints mounted while the cover returns, then
                // resolve the compact cover and waveform together from blur.
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    compactRevealProgress = 0
                }
                withAnimation(.easeInOut(duration: LazyNotchMotion.closeResponse)) {
                    compactRevealProgress = 1.0
                }
                withAnimation(.easeIn(duration: LazyNotchMotion.contentExitDuration)) {
                    contentProgress = 0.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + LazyNotchMotion.collapseDelay) {
                    guard !viewModel.isExpanded else { return }
                    withAnimation(LazyNotchMotion.shellSpring(isExpanded: false)) {
                        shellExpanded = false
                    }
                }
                // End the matched-geometry handoff when the cover return finishes;
                // leaving the expanded endpoint alive beyond that creates a last-frame snap.
                DispatchQueue.main.asyncAfter(deadline: .now() + LazyNotchMotion.collapseDelay + LazyNotchMotion.closeResponse) {
                    guard !viewModel.isExpanded else { return }
                    expandedContentMounted = false
                }
            }
        }
        // Geometry follows the visual phase, including the delayed collapse.
        .animation(LazyNotchMotion.shellSpring(isExpanded: shellExpanded), value: shellExpanded)
        .animation(LazyNotchMotion.pillMorphSpring, value: viewModel.hasActiveLiveActivity)
        .animation(LazyNotchMotion.interactiveSpring, value: viewModel.isHovered)
    }
}

/// NotchNook-style press feedback for the live-activity strip: the content (cover +
/// waveform) squishes vertically ~12% for one beat at mouse-down — the tactile
/// "you clicked it" feel — while the shell itself never shrinks. Release springs
/// back into the expansion morph.
struct NotchStripPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(x: configuration.isPressed ? 0.98 : 1.0, y: configuration.isPressed ? 0.88 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.15, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

struct CompactNotchContent: View {
    @ObservedObject var viewModel: ShellViewModel
    let namespace: Namespace.ID
    @ObservedObject var mediaService = MediaService.shared
    @State private var waveformAppeared = false

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

            Button {
                withAnimation(LazyNotchMotion.shellSpring(isExpanded: true)) {
                    viewModel.isExpanded = true
                }
            } label: {
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
                            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                            )
                    } else {
                        fallbackAppIcon
                    }
                }
                .matchedGeometryEffect(id: "albumArt", in: namespace, isSource: !viewModel.isExpanded)
                .frame(width: 20, height: 20)
                .frame(width: wingWidth, height: contentHeight, alignment: .center)
                .scaleEffect(viewModel.isHovered ? 1.15 : 1.0)
                .offset(y: viewModel.isHovered ? 1.0 : 0)

                // 3. Hardware Notch Cutout Gap
                Spacer()
                    .frame(width: viewModel.compactSize.width, height: contentHeight)

                // 4. Visible Right Wing Section (strictly centered in the visible black body!)
                ZStack(alignment: .center) {
                    MiniAudioWaveform(color: appColor)
                }
                .frame(width: wingWidth, height: contentHeight, alignment: .center)
                .offset(x: -2, y: viewModel.isHovered ? 1.0 : 0)
                .scaleEffect(viewModel.isHovered ? 1.15 : 1.0)
                .opacity(waveformAppeared ? 1.0 : 0.0)
                .blur(radius: waveformAppeared ? 0 : 4)
                .onAppear {
                    waveformAppeared = false
                    withAnimation(.easeOut(duration: 0.38).delay(0.04)) {
                        waveformAppeared = true
                    }
                }
                .onChange(of: viewModel.isExpanded) { _, expanded in
                    if !expanded {
                        waveformAppeared = false
                        withAnimation(.easeOut(duration: 0.38).delay(0.04)) {
                            waveformAppeared = true
                        }
                    }
                }

                // 5. Right top-ear flare & 2px border margin inset
                Spacer()
                    .frame(width: topRadius + borderMargin, height: contentHeight)
            }
                .frame(width: totalWidth, height: contentHeight)
                .contentShape(Rectangle())
            }
            // Press squish lives in NotchStripPressStyle (cover + waveform flatten on
            // mouse-down, like NotchNook) — a real Button, so the click can never be
            // eaten by a competing drag gesture.
            .buttonStyle(NotchStripPressStyle())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .contentShape(Rectangle())
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
    var progress: CGFloat = 1.0

    init(viewModel: ShellViewModel, selectedTab: Binding<ShellContentView.ShellTab>, namespace: Namespace.ID, progress: CGFloat = 1.0) {
        self.viewModel = viewModel
        self._selectedTab = selectedTab
        self.namespace = namespace
        self.progress = progress
    }

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
                    .morphReveal(progress)

                Group {
                    switch selectedTab {
                    case .home:
                        HomeRow(namespace: namespace, progress: progress, isExpanded: viewModel.isExpanded)
                    case .shelf:
                        LazyShelfView()
                            .morphReveal(progress)
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
