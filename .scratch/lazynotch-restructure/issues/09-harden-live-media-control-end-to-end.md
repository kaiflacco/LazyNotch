# 09: Harden Live Media Control end to end

**What to build:** Preserve the complete media path from system media integration through shell state into the compact and expanded widgets, including resilient artwork and metadata handling.

**Blocked by:** 08: Stabilize compact and expanded shell geometry.

**Status:** resolved

- [x] Current track, playback state, artwork, and controls remain usable.
- [x] Missing artwork, long titles, long artists, and unavailable media degrade without layout breakage.
- [x] External media effects are isolated from presentation state.
- [x] Deterministic mapping or service behavior has automated coverage.
- [x] Active and inactive media states pass representative visual and runtime checks.

## Implementation evidence

- Preserved the native/browser media path and added display-safe fallback metadata.
- Added refresh-generation and monitoring shutdown guards so stale media work cannot update the shell after teardown.
- Added fallback mapping coverage; build and tests pass.
