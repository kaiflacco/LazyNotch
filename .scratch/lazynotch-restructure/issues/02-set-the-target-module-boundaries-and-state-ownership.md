# Set the target module boundaries and state ownership

Type: grilling
Label: wayfinder:grilling
Status: resolved
Blocked by: 01

## Question

Given the inventory, which feature, core, shell, and UI boundaries should LazyNotch use while remaining one Swift executable target? Decide where state lives, which direction dependencies may flow, and what seams make the migration incremental and testable.

## Answer

- Keep one Swift executable target and use conceptual feature boundaries rather than adding package or plugin boundaries without a concrete need.
- Use one app-scoped `Runtime` composition and lifecycle boundary at bootstrap. Construct services there and pass dependencies explicitly into the shell and feature surfaces.
- A `Feature` owns its domain state and user actions. Its integrations, models, and platform details stay behind one app-facing state/command surface.
- An `Integration` owns system, process, network, permission, persistence, and other external side effects. Views do not construct or discover integrations.
- The shell view model owns presentation state such as compact/expanded mode, active tab, live activity, and display-facing values. The shell coordinates features; it does not absorb their domain state.
- Shared Core code is limited to platform primitives used by multiple features. It does not own feature state or UI policy.
- Avoid feature-to-feature singleton access and a custom global event bus. Platform notifications remain inside integrations and flow into feature state; the shell coordinates cross-feature presentation.
- Feature services expose explicit ready, denied, unavailable, and failed states so the UI can render recovery states without owning recovery logic.
- Runtime construction and lifecycle are explicit. Lightweight services may be created at launch, while observers, processes, and network work start through lifecycle methods.
- Preserve the current Codex-over-media live-activity priority when both are active.
- Keep simple settings in native local storage; introduce a feature-owned preferences surface only when validation, coordination, or nontrivial persistence requires it.
- Migrate with expand–contract: introduce injected paths beside current singleton access, migrate callers by feature, then remove singleton access after no callers remain.
- Display coordination owns screen selection and geometry; the window controller owns the panel, hover state machine, and hit testing; SwiftUI renders the resulting state.
