# LazyNotch UI/UX Audit

Date: 2026-09-26

Scope: whole repository, current working tree

Method: source inspection, product/context review, test/build verification, and one non-mutating runtime screenshot

## Executive verdict

LazyNotch has a coherent product direction: the shell, compact live activity, widgets, Shelf, Hand Mirror, Settings, and Codex usage surfaces are all represented in the code, and the dark/translucent visual language is centralized enough to evolve. The current implementation also has useful state modeling and several focused tests around interaction geometry and data behavior.

The largest quality risk is not visual styling. It is interaction reachability and failure recovery. Several important surfaces are implemented as pointer gestures or icon-only controls without equivalent semantic actions, while a camera setup failure can be rendered as an apparently valid but blank preview. The next pass should prioritize accessibility and explicit error states before visual polish.

Overall assessment: promising foundation, but not yet robust enough to call production-ready across assistive technology, permission failures, multi-display use, and delayed external-service responses.

## Evidence boundary

The audit inspected the app source, tests, product context, restructuring notes, and repository guidance. Verification completed during the audit:

- `swift test`: passed, 17 tests, 0 failures.
- `swift build -c release`: passed.
- The existing built app was already running on the built-in notched M3 Pro display; it was not killed or relaunched.
- A non-mutating screenshot was captured at `/tmp/lazynotch-ui-audit-idle.png`. It showed a compact Codex-style live activity with `92%` visible in the notch area.

The screenshot did not exercise the expanded shell, Shelf, Hand Mirror, Settings, hover states, permission states, external displays, VoiceOver, keyboard-only navigation, or reduced-motion behavior. Findings based on source behavior are marked with confidence; runtime behavior that was not exercised is explicitly called out rather than inferred from the screenshot.

No product source files were changed for this audit. The report itself is the only audit artifact added.

## Coverage matrix

| Surface / journey | Static coverage | Runtime coverage | Audit result |
| --- | --- | --- | --- |
| Compact notch / live activity | Shell, media, Codex, hit-region code inspected | Compact Codex state seen once | Core semantics and state fallbacks need work |
| Expanded shell / widgets | Shell, media, calendar, mirror entry points inspected | Not exercised | Needs manual state and transition pass |
| Lazy Shelf | Store, view, drop rules, Quick Look, AirDrop inspected; related tests pass | Not exercised | Pointer/keyboard/accessibility gap; delivery status is optimistic |
| Hand Mirror | Camera lifecycle, preview, effects, window inspected | Camera/permission states not exercised | Blank-preview failure path and recovery gap |
| Settings | Window, controls, launch-at-login, permission cards inspected | Not exercised | Registration failure can leave misleading state |
| Calendar | Permission, fetch, widget rendering inspected | Not exercised | Synchronous first read and stale-fetch risk |
| Codex usage | Polling, host activation, rendering inspected | Compact state seen once | Host activation does not immediately refresh usage |
| Displays / window behavior | Display coordinator and window controller inspected | Built-in notched display only | External-display matrix still unverified |
| Accessibility / keyboard | Modifier inventory and gesture paths inspected | No VoiceOver or keyboard run | Several critical elements are not semantic controls |
| Reduced motion | Motion helpers and SwiftUI environment usage inspected | Not exercised | Source intent is good; visual behavior is unverified |

## Prioritized findings

### UIUX-001 — Idle shell expansion is not a semantic control

Severity: P1

Type: accessibility / interaction reachability

Confidence: High

`MorphingNotchIsland` expands from its idle/collapsed state through `onTapGesture` in `Sources/UI/Shell/ShellContentView.swift:325-337`. The view exposes an accessibility hint, but it is not a `Button`, has no explicit accessible label or button trait, and does not define an accessibility action.

This makes the primary shell entry point dependent on pointer activation. A VoiceOver user, and likely a keyboard-only user, does not receive an equivalent “open LazyNotch” action. Because the shell is the gateway to the main product surfaces, this is a core-task accessibility failure.

Recommended fix: preserve the current pointer hit region but give the idle shell a semantic button/action with a label such as “Open LazyNotch,” an appropriate value/state, and an explicit action that invokes the same expansion path. Verify with VoiceOver and keyboard focus on both idle and compact-live states.

### UIUX-002 — Hand Mirror setup failure can look like a valid blank preview

Severity: P1

Type: error handling / trust

Confidence: High

In `Sources/Features/Mirror/CameraManager.swift:54-68`, failure to add the camera output is logged, but configuration still proceeds to completion with success. In `CameraManager.start()` around `:207-211`, a setup error is assigned to `errorMessage` while permission remains authorized. `Sources/Features/Mirror/HandMirrorView.swift:105-124` renders the preview based on `hasPermission` and does not render `errorMessage` when permission is granted.

On a Mac with no usable camera, or when capture-output configuration fails, the user can therefore see a black/empty camera surface without an explanation or recovery action. The core mirror task is blocked, but the UI does not say why.

Recommended fix: model camera readiness separately from permission, fail configuration when required outputs cannot be attached, and render a clear unavailable state with the underlying reason and a recovery action. Keep permission-denied and hardware/setup-failed states distinct.

### UIUX-003 — Shelf item cards are pointer-first and lack semantic selection/focus

Severity: P1

Type: accessibility / keyboard interaction

Confidence: High

`StagedItemCard` in `Sources/Features/LazyShelf/LazyShelfView.swift:507-519` uses `onTapGesture` and `onDrag` for its primary interactions. It provides a help string and hint around `:560-561`, but no explicit accessible label, button/action, selection state, or focus treatment. The view has keyboard event handling for arrows and Space elsewhere, but the current card rendering does not expose a visible focus ring or a semantic focused/selected state.

This creates a mismatch between the presence of keyboard plumbing and the user feedback needed to operate the Shelf confidently. VoiceOver users may get an unlabeled or generic element, while keyboard users can move through items without a reliable visual indication of the active card.

Recommended fix: expose each card as a labeled actionable element with selected/focused state and custom actions for open, remove, and send where appropriate. Add a visible focus indicator tied to `focusedItemID`, and verify arrow navigation, Space, Escape, and VoiceOver rotor navigation.

### UIUX-004 — Compact media live activity has no complete accessible name/value

Severity: P2

Type: accessibility / live status

Confidence: High

The compact media activity is an outer `Button` in `Sources/UI/Shell/ShellContentView.swift:481-570`, containing artwork, waveform, and track content. The surrounding styling includes a help message around `:608`, but the compact action does not define a complete accessibility label/value for the current track or the action it performs.

The visual activity can be understandable while the assistive-technology output remains generic, especially when artwork and waveform visuals dominate the compact state. A user should be able to discover what is playing and what activating the compact activity does without relying on the pixels.

Recommended fix: expose a concise label such as “Now playing: title by artist,” a useful value for play/pause or progress where applicable, and an action hint such as “Open media controls.” Hide decorative artwork and waveform elements from the accessibility tree unless they convey information.

### UIUX-005 — Several icon-only controls rely on tooltips instead of accessible names

Severity: P2

Type: accessibility

Confidence: High

The modifier inventory found multiple icon-only controls with a `.help(...)` string but no explicit accessibility label:

- Shelf add control: `Sources/Features/LazyShelf/LazyShelfView.swift:226-235`.
- Settings close button: `Sources/Features/Settings/SettingsSheet.swift:44-55`.
- Hand Mirror filter menu and flip control: `Sources/Features/Mirror/HandMirrorView.swift:130-176`.

Tooltips are not a substitute for semantic names and are not consistently available to VoiceOver or keyboard users. These controls are small but important: add files, close Settings, choose a mirror filter, and flip the preview.

Recommended fix: add explicit labels and, for the filter menu, a value describing the current filter. Confirm the close and flip actions through VoiceOver and keyboard focus rather than only by hovering.

### UIUX-006 — Launch-at-login toggle can display success after registration fails

Severity: P2

Type: state consistency / trust

Confidence: High

`Sources/Features/Settings/SettingsSheet.swift:151-173` updates the `launchAtLogin` state immediately, then attempts `SMAppService` registration or removal. The error handler only prints the failure and does not restore the state or show an inline error.

If macOS rejects the operation, the Settings UI can continue to show the requested value even though the system did not apply it. This is especially confusing because the control looks authoritative and there is no visible indication that the setting failed.

Recommended fix: treat the system registration result as the source of truth, roll back the toggle on failure, and show a compact inline error with a retry path. Refresh the status when the Settings window becomes active so it does not rely on stale initialization state.

### UIUX-007 — Calendar’s first cache miss can synchronously block the UI

Severity: P2

Type: performance / responsiveness

Confidence: High

`CalendarService.events(for:)` performs `eventStore.events(matching:)` synchronously on the main actor in `Sources/Features/Calendar/CalendarService.swift:83-104`. `CalendarWidget.body` calls this path while rendering in `Sources/UI/Widgets/WidgetGrid.swift:488-489`.

EventKit queries can be slow or become more expensive with larger calendars. A first visit to the calendar widget, or a cache miss after a date change, can therefore stall the shell’s rendering path. The user receives no loading state while that synchronous work occurs.

Recommended fix: prefetch asynchronously, keep rendering on cached data, and expose a loading state for a cache miss. Keep the shell responsive while permission and EventKit work completes.

### UIUX-008 — Codex live activity may remain “Loading” after host activation

Severity: P2

Type: stale state / feedback delay

Confidence: High

In `Sources/Features/AI/CodexUsageService.swift:46-63`, the workspace activation observer calls `refreshHostState()` but does not call `refresh()` for usage data. The usage timer runs every five minutes. The compact renderer in `Sources/UI/Shell/ShellContentView.swift:815-842` can therefore continue showing a loading or old value until the next polling interval after Codex becomes active.

This weakens the live-activity promise: the host has just become relevant, but the surface does not immediately update its useful content.

Recommended fix: trigger a debounced usage refresh on supported-host activation, cancel overlapping refreshes, and distinguish loading, unavailable, and stale data in the UI. Keep the existing polling timer as a backstop rather than the only update path.

### UIUX-009 — Calendar permission changes can leave stale event dots

Severity: P2

Type: stale data / permission state

Confidence: Medium

`CalendarService.fetchUpcomingEvents()` writes its background result back into `weekEvents` in `Sources/Features/Calendar/CalendarService.swift:226-253`. The service also has a clear-unavailable path around `:257-260`, but the in-flight fetch has no generation check or cancellation guard. `CalendarWidget` reads `weekEvents` for day indicators around `Sources/UI/Widgets/WidgetGrid.swift:434-435`.

If permission is revoked or the service is cleared while a fetch is in flight, an older completion can repopulate event data after the UI has entered a no-access state. The result is a calendar that says access is unavailable while still showing event dots from stale data.

Recommended fix: cancel or invalidate in-flight fetches when permission/state changes, and make the widget’s day indicators conditional on the current permission/availability state.

### UIUX-010 — Shelf thumbnails use the main display scale for every display

Severity: P3

Type: visual quality / multi-display

Confidence: High

`ShelfThumbnail` in `Sources/Features/LazyShelf/LazyShelfView.swift:661-669` uses `NSScreen.main?.backingScaleFactor ?? 2` when generating thumbnails. The Shelf can be presented relative to the app’s active display, so this can request the wrong bitmap scale on a mixed-DPI multi-display setup.

The likely result is softer or inconsistently sized thumbnails when the user moves between the built-in Retina display and an external display. This is not a core workflow blocker, but it undermines the product’s visual polish on a supported macOS setup.

Recommended fix: derive the scale from the window/display hosting the Shelf, or from SwiftUI’s display-scale environment, and verify on mixed Retina/non-Retina displays.

### UIUX-011 — AirDrop success feedback is optimistic rather than delivery-confirmed

Severity: P2

Type: status truthfulness / external workflow

Confidence: Medium

`LazyShelfStore.sendViaAirDrop()` in `Sources/Features/LazyShelf/LazyShelfStore.swift:225-240` marks the item as successful shortly after launching the sharing service, based on whether the service can perform with the items. It does not observe a completed transfer or a user cancellation.

The Shelf can therefore show a success state when the share sheet opened but the user did not complete the transfer. This makes the status read as “sent” when it is really “share flow opened.”

Recommended fix: name the intermediate state accurately (“Sharing…” or “Share sheet opened”), use completion/cancellation information when available, and reserve “Sent” for a confirmed completion. If the platform API cannot confirm delivery, avoid claiming it can.

## Strengths worth preserving

- The dark/translucent visual language is centralized through `LazyNotchColors`, motion helpers, and shared shell/widget components.
- Reduced-motion handling is present in the shell, media, and animated content paths. This is a good foundation for a full motion audit.
- Shelf behavior is deliberately non-destructive: it stages file references and does not claim ownership of or delete the source files.
- The code has explicit fallbacks for missing media metadata, missing calendar access, missing Codex host data, and empty Shelf states.
- The existing tests cover meaningful interaction rules such as hit regions, external drag acceptance, Shelf ordering, media fallback, calendar grouping, and Codex percentage clamping.
- The current window/display work has clear intent around the physical notch, pass-through behavior, and the distinction between compact and expanded shell geometry.

## Gaps that need hands-on validation

These are not all confirmed defects; they are the highest-value runtime checks left after static inspection:

1. VoiceOver and keyboard-only operation for opening the shell, navigating Shelf cards, operating media controls, closing Settings, and using Hand Mirror controls.
2. Compact-to-expanded transitions, hover zones, pointer pass-through, and focus behavior on the built-in notch.
3. Camera permission: not determined, denied, authorized, no camera, and capture-output setup failure.
4. Calendar permission: not determined, denied, revoked while open, empty calendar, and slow/large event store.
5. Codex host activation, process termination, unavailable executable, stale usage, and refresh timing.
6. Shelf flows: long filenames, missing paths, denied paths, large thumbnails, external drag, Quick Look, AirDrop cancellation, and clearing the Shelf.
7. Built-in Retina plus external Retina/non-Retina displays, display changes while the app is open, and a no-notch display.
8. Reduce Motion enabled, increased text size/accessibility settings, dark/light appearance, and high-contrast settings.

## Recommended sequence

1. Make the shell, Shelf cards, compact media state, and icon-only controls semantic and keyboard/VoiceOver reachable.
2. Make camera readiness explicit and add visible recovery actions for permission and capture setup failures.
3. Remove synchronous Calendar work from view rendering and invalidate stale asynchronous results.
4. Refresh Codex usage immediately on relevant host activation and make loading/unavailable/stale states explicit.
5. Correct multi-display thumbnail scale and make external-service status language truthful.
6. Run a focused runtime matrix on the built-in notch and at least one external display, then capture screenshots for idle, compact live, expanded, empty, permission-denied, and failure states.
