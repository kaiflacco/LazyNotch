# 11: Harden Lazy Shelf persistence and layout

**What to build:** Preserve the complete Lazy Shelf workflow—stage, preview, drag, open, AirDrop, and clear—while keeping tiles and empty states fully visible and valid local state durable.

**Blocked by:** 08: Stabilize compact and expanded shell geometry.

**Status:** resolved

- [x] Users can add files, preview them, drag or open them, send them with AirDrop, and clear the shelf.
- [x] Valid staged items survive restart and missing files are handled cleanly.
- [x] Empty, single-item, and many-item layouts avoid clipping, overlap, and excess spacing.
- [x] Persistence and item filtering have deterministic automated coverage.
- [x] Shelf interactions pass representative runtime and visual checks.

## Implementation evidence

- Preserved the existing stage, preview, drag, open, AirDrop, and clear actions.
- Filtered missing persisted paths before rebuilding shelf items and added deterministic coverage.
- Build and tests pass.
