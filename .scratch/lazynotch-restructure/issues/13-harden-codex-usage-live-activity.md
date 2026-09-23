# 13: Harden Codex usage live activity

**What to build:** Preserve Codex usage display and live activity behavior while isolating app-server/process integration and handling missing, inactive, or unavailable Codex installations cleanly.

**Blocked by:** 08: Stabilize compact and expanded shell geometry.

**Status:** resolved

- [x] Usage data reaches compact and expanded presentation states when Codex is available and active.
- [x] Missing Codex, inactive hosts, unavailable usage data, and process failures produce usable states.
- [x] Process lifecycle, parsing, host detection, and icon lookup stay outside presentation views.
- [x] Usage parsing and state mapping have deterministic automated coverage.
- [x] Active, inactive, and unavailable Codex states pass representative visual and runtime checks.

## Implementation evidence

- Kept process parsing and host detection in `CodexUsageService`, added a deterministic parsing seam, and added explicit shutdown cleanup.
- Preserved Codex-over-media activity priority in the shell.
- Added usage-window clamping coverage; build and tests pass.
