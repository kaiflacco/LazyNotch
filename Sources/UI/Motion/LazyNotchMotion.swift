import SwiftUI

/// Shared shell and interaction timing.
public enum LazyNotchMotion {
    // MARK: - Core Spring Constants

    /// Allows the shell to grow before content sharpens, with a visible, single overshoot.
    public static let openResponse: Double = 0.44
    public static let openDamping: Double = 0.80

    /// A softer return into the compact strip; response is not total settling time.
    public static let closeResponse: Double = 0.34
    public static let closeDamping: Double = 0.90

    /// Content sharpens in 0.45s, ahead of the final shell settling.
    public static let contentRevealDelay: Double = 0.05
    public static let contentRevealDuration: Double = 0.30
    public static let contentExitDuration: Double = 0.16
    public static let collapseDelay: Double = 0.04
    public static let collapseSettleDuration: Double = 0.44

    /// Keep text crisp while it travels; blur is a transition cue, not a resting style.
    public static let contentBlurRadius: CGFloat = 7
    public static let compactBlurRadius: CGFloat = 5
    public static let heroBlurRadius: CGFloat = 6

    /// Tactile hover tension: Bottle-neck swell when cursor touches the notch.
    /// Damped enough that hover settles in one soft motion (NotchNook-style), no wobble.
    public static let hoverResponse: Double = 0.20
    public static let hoverDamping: Double = 0.86

    // MARK: - Shell Morphing Springs

    /// Opening spring: gradual expansion with a visible, controlled overshoot.
    public static let openingSpring: Animation = .spring(
        response: openResponse,
        dampingFraction: openDamping,
        blendDuration: 0.0
    )

    /// Closing spring: Faster contraction into the notch, minimal overshoot.
    public static let closingSpring: Animation = .spring(
        response: closeResponse,
        dampingFraction: closeDamping,
        blendDuration: 0.0
    )

    /// Dynamic shell spring selecting opening or closing curves based on expansion state.
    public static func shellSpring(isExpanded: Bool) -> Animation {
        isExpanded ? openingSpring : closingSpring
    }

    /// Fluid pill morphing spring between idle notch and compact live activity.
    public static let pillMorphSpring: Animation = .spring(
        response: 0.28,
        dampingFraction: 0.82,
        blendDuration: 0.0
    )

    /// Small press feedback for activity strips and controls.
    public static let pressSpring: Animation = .spring(
        response: 0.18,
        dampingFraction: 0.80,
        blendDuration: 0.0
    )

    // MARK: - Micro-interaction Springs

    /// Interactive spring for buttons, icons, and hover responses.
    public static let interactiveSpring: Animation = .spring(
        response: hoverResponse,
        dampingFraction: hoverDamping,
        blendDuration: 0.0
    )

    /// Tactile tab switcher spring.
    public static let tabSpring: Animation = .spring(
        response: 0.22,
        dampingFraction: 0.86,
        blendDuration: 0.0
    )
}
