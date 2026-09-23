import SwiftUI

/// Shared shell and interaction timing.
public enum LazyNotchMotion {
    // MARK: - Core Spring Constants

    /// Allows the shell to grow before content sharpens, with a visible, single overshoot.
    public static let openResponse: Double = 0.50
    public static let openDamping: Double = 0.66

    /// A softer return into the compact strip; response is not total settling time.
    public static let closeResponse: Double = 0.45
    public static let closeDamping: Double = 0.82

    /// Content sharpens in 0.45s, ahead of the final shell settling.
    public static let contentRevealDelay: Double = 0.08
    public static let contentRevealDuration: Double = 0.37
    public static let contentExitDuration: Double = 0.20
    public static let collapseDelay: Double = 0.06
    public static let collapseSettleDuration: Double = 0.55

    /// Tactile hover tension: Bottle-neck swell when cursor touches the notch.
    /// Damped enough that hover settles in one soft motion (NotchNook-style), no wobble.
    public static let hoverResponse: Double = 0.24
    public static let hoverDamping: Double = 0.78

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
        response: 0.32,
        dampingFraction: 0.75,
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
        response: 0.26,
        dampingFraction: 0.82,
        blendDuration: 0.0
    )
}
