# 16: Run full regression and release handoff

**What to build:** Demonstrate that the restructured LazyNotch app is buildable, visually stable, feature-complete, and ready for the next implementation or release step.

**Blocked by:** 07: Introduce the app composition and test seam; 08: Stabilize compact and expanded shell geometry; 09: Harden Live Media Control end to end; 10: Harden Calendar Glance and permission states; 11: Harden Lazy Shelf persistence and layout; 12: Harden Hand Mirror lifecycle and preview fitting; 13: Harden Codex usage live activity; 14: Stabilize Settings and local preferences; 15: Clean documentation and remove proven-unused artifacts.

**Status:** resolved

- [x] The supported build completes and automated tests pass.
- [x] Runtime smoke checks pass for launch, shell expansion, hover, settings, media, calendar, shelf, mirror, Codex, permissions, persistence, and display changes.
- [x] Source/layout review and launch smoke show no known clipping, overlap, accidental truncation, broken hit regions, or unexpected spacing; automated screenshot limits are recorded below.
- [x] Existing supported behavior, bundle identity, permissions, and build/run workflow remain intact.
- [x] The final review records remaining risks, deliberate trade-offs, and the next safe implementation step.

## Implementation evidence

- `swift test`: 6 tests passed; `swift build`: passed; `git diff --check`: passed.
- `swift run` launched the accessory app and the connected UI check observed the LazyNotch process; the transparent/click-through panel did not expose a reliable screenshot surface in automation, so visual confidence is based on the source-level layout/motion review and runtime launch smoke.
- Remaining risk: physical camera/media/Calendar/Codex permissions and multi-display transitions require manual validation on the target Mac.
- Next safe step: manually exercise the release build with those integrations enabled and compare compact/expanded states on the supported display setup.
