import SwiftUI

/// Centralized motion configuration for LazyNotch.
/// Implements the physics parameters from the Master Specification:
/// - Opening: Fast initial response (~250-350ms main expansion, 50-100ms settle),
///   subtle controlled overshoot, low bounce, quick settling.
/// - Closing: Snappy contraction (~180-250ms), minimal overshoot.
/// - Micro-interactions: Restrained, tactile spring responses.
public enum LazyNotchMotion {
    // MARK: - Core Spring Constants

    /// NotchNook / Dynamic Island opening spring: Fluid organic drop-down expansion (~360ms settle).
    public static let openResponse: Double = 0.45
    public static let openDamping: Double = 0.60 // More bounce

    /// Closing spring: Crisp contraction into the notch (~250ms), clean settling.
    public static let closeResponse: Double = 0.35
    public static let closeDamping: Double = 0.85

    /// Content choreography spring: Slides down smoothly from the notch opening.
    public static let contentResponse: Double = 0.32
    public static let contentDamping: Double = 0.76

    /// Tactile hover tension: Bottle-neck swell when cursor touches the notch.
    public static let hoverResponse: Double = 0.22
    public static let hoverDamping: Double = 0.70

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
