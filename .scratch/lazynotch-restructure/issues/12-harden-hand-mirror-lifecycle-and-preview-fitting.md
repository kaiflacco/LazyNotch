# 12: Harden Hand Mirror lifecycle and preview fitting

**What to build:** Preserve Hand Mirror’s camera permission, preview, controls, and open/close lifecycle while ensuring the preview and controls fit the window.

**Blocked by:** 08: Stabilize compact and expanded shell geometry.

**Status:** resolved

- [x] Camera permission, configuration, start, stop, and close states are recoverable.
- [x] The preview remains fitted and controls remain visible at supported window sizes.
- [x] Camera and window side effects are isolated from presentation state.
- [x] Permission and lifecycle transformations have deterministic automated coverage where platform APIs can be controlled.
- [x] Hand Mirror passes representative runtime and visual checks.

## Implementation evidence

- Guarded camera configure/start/stop callbacks with a lifecycle generation so rapid close/reopen cannot resurrect stale frames or state.
- Changed preview rendering to aspect-fit so camera content is not cropped; preserved the existing window shape and controls.
- Build and tests pass.
