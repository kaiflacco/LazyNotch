# 08: Stabilize compact and expanded shell geometry

**What to build:** Make the compact pill and expanded island fit their content while preserving the current Apple-inspired UX: glanceable compact status, on-demand expanded detail, existing hover/click behavior, alignment, hit regions, display anchoring, and calm physical transitions across supported display conditions.

**Blocked by:** 07: Introduce the app composition and test seam.

**Status:** resolved

- [x] Compact and expanded shell states have no accidental clipping or overlap.
- [x] Content alignment, insets, spacing, and interactive hit regions remain consistent during transitions.
- [x] The compact pill remains glanceable, active media/Codex strips remain click-first, and the expanded island preserves the existing Home/Shelf hierarchy and utility actions.
- [x] Hover expansion remains optional for idle state, the shell stays open across its interactive region, and departure grace plus shelf hold-open behavior remain predictable.
- [x] Motion uses restrained expansion overshoot, quiet closing, limited travel-only blur, crisp resting content, artwork-led morphing, latest-intent transition handling, and Reduce Motion support.
- [x] The shell stays anchored to the correct display through supported display changes.
- [x] Representative shell source/layout and launch visual checks cover compact, expanded, empty, and active states; automated capture limits are recorded in the release handoff.
- [x] Build and runtime smoke checks pass without changing supported user-facing behavior.

## Implementation evidence

- Centralized shell state transitions and corrected AppKit hit-test coordinate handling.
- Tuned existing springs, travel blur, press states, and Reduce Motion behavior without changing the established visual system.
- `swift test` and `swift build` pass; launch smoke completed.
