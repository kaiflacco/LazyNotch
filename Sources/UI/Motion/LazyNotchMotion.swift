import SwiftUI

/// Centralized motion configuration for LazyNotch.
/// Implements the physics parameters from the Master Specification:
/// - Opening: Fast initial response (~250-350ms main expansion, 50-100ms settle),
///   subtle controlled overshoot, low bounce, quick settling.
/// - Closing: Snappy contraction (~180-250ms), minimal overshoot.
/// - Micro-interactions: Restrained, tactile spring responses.
public enum LazyNotchMotion {
    // MARK: - Core Spring Constants

    /// NotchNook / Dynamic Island opening spring: quick expansion with ONE clearly visible
    /// overshoot (~4-6% peak at ~0.25s, settled ~0.6s) — measured from NotchNook's
    /// click-to-expand motion. Bouncy but clean: no multi-oscillation wobble.
    public static let openResponse: Double = 0.40
    public static let openDamping: Double = 0.72

    /// Closing spring: mirrors the opening spring exactly (same response/damping) so
    /// hover-out collapses with the same bouncy, single-overshoot feel as the open —
    /// symmetric motion like NotchNook instead of a stiff snap shut.
    public static let closeResponse: Double = 0.40
    public static let closeDamping: Double = 0.72

    /// Content choreography spring: Slides down smoothly from the notch opening.
    public static let contentResponse: Double = 0.32
    public static let contentDamping: Double = 0.76

    /// Content morph spring (NotchNook-style): deliberately slow, lightly damped entrance so
    /// the blur phase is actually visible (~1s) — content stays soft/out-of-focus while it
    /// settles into the freshly-grown shell with a slight grow-overshoot, then snaps sharp.
    public static let contentMorphResponse: Double = 0.62
    public static let contentMorphDamping: Double = 0.80
    /// Beat between the shell starting to grow and the content following it.
    public static let contentMorphDelay: Double = 0.10

    /// Tactile hover tension: Bottle-neck swell when cursor touches the notch.
    /// Damped enough that hover settles in one soft motion (NotchNook-style), no wobble.
    public static let hoverResponse: Double = 0.24
    public static let hoverDamping: Double = 0.78

    // MARK: - Shell Morphing Springs

    /// Opening spring: Fast initial burst, controlled organic overshoot, quick settling.
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

    // MARK: - Content Choreography Springs

    /// Slow, blur-friendly entrance used for the compact → expanded content morph.
    public static let contentMorphSpring: Animation = .spring(
        response: contentMorphResponse,
        dampingFraction: contentMorphDamping,
        blendDuration: 0.0
    )

    /// Content entrance spring: Moves down into place smoothly during shell expansion.
    public static let contentEntranceSpring: Animation = .spring(
        response: contentResponse,
        dampingFraction: contentDamping,
        blendDuration: 0.0
    )

    /// Content exit spring: Rapidly recedes as the shell contracts.
    public static let contentExitSpring: Animation = .spring(
        response: 0.18,
        dampingFraction: 0.90,
        blendDuration: 0.0
    )

    // MARK: - Micro-interaction Springs

    /// Interactive spring for buttons, icons, and hover responses.
    public static let interactiveSpring: Animation = .spring(
        response: hoverResponse,
        dampingFraction: hoverDamping,
        blendDuration: 0.0
    )

    /// Tactile hover spring for pre-expansion bottle neck elasticity.
    public static let hoverSpring: Animation = .spring(
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
