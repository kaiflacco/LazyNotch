# LazyNotch architecture, backend, and UI/UX restructure

Label: ready-for-agent
Status: ready-for-agent

## Problem Statement

As a LazyNotch user and maintainer, I need the app to remain feature-complete while its internal structure becomes easier to understand, test, and change.

The current SwiftUI macOS app has broad responsibilities concentrated in shell and widget views, services that own system side effects directly, singleton access across layers, fixed layout dimensions, and a large set of existing working-tree changes. These conditions make UI regressions likely: content can become misaligned, cropped, overlapped, truncated, or separated by inconsistent spacing.

The repository also contains stale or deleted documentation and potentially unused files. The project needs a safe classification process before anything ambiguous is removed. The app has no separate server; its backend is the in-process service, state, persistence, permission, process, and network-integration layer.

## Solution

Restructure LazyNotch around explicit feature boundaries and a single app composition boundary while preserving supported user-facing behavior. Keep the app local-first and continue using one Swift executable target.

Move system and external side effects behind service/integration boundaries, keep presentation state at the shell boundary, and make the service layer testable through injected dependencies or pure transformations. Correct UI geometry across the compact pill, expanded island, widgets, shelf, settings, mirror window, hover states, and transitions using a shared layout contract and representative visual validation.

Inventory all source, asset, generated, and documentation files before deleting anything. Remove only proven-unused or explicitly rejected material, and repair README and index references so documentation describes the current product.

## User Stories

1. As a LazyNotch user, I want the compact pill to remain visually aligned, so that its controls and indicators feel intentional.
2. As a LazyNotch user, I want the expanded island to fit its content, so that widgets are not cropped or overlapped.
3. As a LazyNotch user, I want text to remain readable without accidental truncation, so that I can understand media, calendar, shelf, settings, and Codex information.
4. As a LazyNotch user, I want spacing to be consistent across widgets, so that the expanded island does not feel uneven or wasteful.
5. As a LazyNotch user, I want the UI to adapt to supported notch and display sizes, so that content remains usable across supported Macs and display changes.
6. As a LazyNotch user, I want hover, press, expand, collapse, and transition states to preserve alignment, so that animation does not introduce visual jumps.
7. As a LazyNotch user, I want Live Media Control to continue showing artwork, track information, and controls, so that the restructure does not remove media behavior.
8. As a LazyNotch user, I want media content to handle missing artwork or long metadata gracefully, so that the widget remains usable in edge cases.
9. As a LazyNotch user, I want Calendar Glance to continue showing the week strip and schedule information, so that I can check upcoming events quickly.
10. As a LazyNotch user, I want Calendar Glance to remain understandable when permission is denied or no events exist, so that the UI explains its state instead of appearing broken.
11. As a LazyNotch user, I want Lazy Shelf to accept, preview, stage, drag, open, and clear files, so that it remains a useful temporary file tray.
12. As a LazyNotch user, I want Lazy Shelf tiles and empty states to remain fully visible, so that staged files and actions are not clipped.
13. As a LazyNotch user, I want Lazy Shelf persistence to keep valid staged items locally, so that restarting the app does not unexpectedly lose them.
14. As a LazyNotch user, I want Hand Mirror to open and close reliably, so that I can use the camera without switching applications.
15. As a LazyNotch user, I want Hand Mirror controls and preview content to fit its window, so that camera output and controls are not cropped.
16. As a LazyNotch user, I want Settings to expose the existing preferences clearly, so that I can change behavior without navigating an unstable layout.
17. As a LazyNotch user, I want settings content to scroll or compress safely when necessary, so that controls do not disappear below the visible area.
18. As a LazyNotch user, I want Codex usage information to remain available when Codex is installed and active, so that the live activity reflects the supported integration.
19. As a LazyNotch user, I want the app to behave sensibly when Codex is unavailable or inactive, so that the shell does not show empty or misleading states.
20. As a LazyNotch user, I want permissions for Calendar and Camera to be handled without breaking the rest of the app, so that denied access produces a recoverable state.
21. As a LazyNotch user, I want the notch to stay anchored to the correct display, so that multi-display changes do not leave the window misplaced.
22. As a LazyNotch maintainer, I want feature state to have clear ownership, so that changes do not require tracing hidden singleton mutations through unrelated views.
23. As a LazyNotch maintainer, I want system APIs, external processes, and network requests isolated behind integration boundaries, so that platform changes do not spread through presentation code.
24. As a LazyNotch maintainer, I want the local in-process backend to remain local-first, so that the app does not gain unnecessary server, database, or cloud dependencies.
25. As a LazyNotch maintainer, I want service behavior to be testable with injected dependencies or deterministic transformations, so that regressions can be caught without requiring every system integration to be active.
26. As a LazyNotch maintainer, I want the app composition boundary to assemble dependencies in one place, so that runtime wiring and test wiring stay understandable.
27. As a LazyNotch maintainer, I want obsolete files and documentation identified before deletion, so that cleanup does not remove a hidden dependency or useful project knowledge.
28. As a LazyNotch maintainer, I want README and index links to describe the current repository, so that contributors are not sent to missing or stale documents.
29. As a LazyNotch maintainer, I want the existing uncommitted work preserved as input, so that planning does not erase intentional changes.
30. As a LazyNotch maintainer, I want each restructuring slice to have build, runtime, permission, persistence, and visual checks, so that architecture improvements do not silently degrade the app.
31. As a contributor, I want the final module vocabulary to be documented, so that future changes follow the same boundaries instead of recreating the current tangles.
32. As a contributor, I want ambiguous architectural choices recorded as decisions, so that future maintainers understand why the app is structured this way.
33. As a LazyNotch user, I want the compact pill to be glanceable, so that I can understand active media or coding status without opening the full island.
34. As a LazyNotch user, I want the expanded island to provide the details and controls, so that the compact pill does not become visually crowded.
35. As a LazyNotch user, I want idle hover expansion to remain optional, so that the notch does not open unexpectedly when a live activity is already visible.
36. As a LazyNotch user, I want live media and Codex activity strips to remain click-first, so that background activity never hijacks my workspace.
37. As a LazyNotch user, I want the island to stay open while my pointer is within any interactive shell content, so that moving between controls does not collapse it.
38. As a LazyNotch user, I want the island to collapse after the existing departure grace period when I leave its interactive region, so that it returns to a quiet compact state without feeling fragile.
39. As a LazyNotch user, I want Home to prioritize media, calendar, and Codex status while keeping Lazy Shelf as a separate tab, so that the information hierarchy stays predictable.
40. As a LazyNotch user, I want empty, denied, unavailable, and failed states to explain what happened and offer one recovery action when possible, so that no feature appears blank or broken.
41. As a LazyNotch user, I want long titles, artists, events, host names, and settings descriptions to remain usable, so that text fitting does not distort the layout or hide important controls.
42. As a LazyNotch user, I want transitions to feel calm, physical, and responsive, so that the app feels native to macOS while preserving its existing visual language.
43. As a LazyNotch user, I want the artwork to lead the shell morph and text to sharpen shortly after, so that transitions have a clear visual hierarchy instead of every element moving at once.
44. As a LazyNotch user, I want resting text and controls to be crisp, so that blur is understood as a transition cue rather than a permanent visual treatment.
45. As a LazyNotch user, I want rapid hover, click, expand, and collapse changes to settle on my latest intent, so that stale animation callbacks never leave a flash, snap, clipped state, or detached visual.
46. As a LazyNotch user, I want macOS Reduce Motion to produce shorter fades and direct geometry changes, so that the shell remains usable without large morphing effects.
47. As a LazyNotch maintainer, I want motion timing, blur limits, and interaction springs centralized, so that future tuning stays coherent and does not accumulate one-off animation values.

## Implementation Decisions

- Keep LazyNotch as one Swift executable target on the existing supported macOS baseline. Do not introduce extra packages, a plugin API, or a generic dependency-injection framework without a concrete need.
- Use app bootstrap as the primary composition boundary. Construct runtime services there and pass the required dependencies into the shell/window layer rather than allowing deeply nested views to construct or discover services.
- Keep presentation state at the shell boundary. The shell view model owns presentation state such as compact/expanded mode, active tab, live activity, and display-facing values; feature services own feature state and operations.
- Organize the code around deep feature boundaries for media, calendar, shelf, mirror, settings, Codex usage, display coordination, and shell presentation. Dependencies should flow toward stable interfaces rather than through unrelated views.
- Treat the in-process backend as the service and integration layer. It includes local persistence, permission handling, system frameworks, external processes, media/network requests, display coordination, and window control.
- Keep system and external side effects behind explicit service or adapter contracts. The UI should consume state and user actions, not own platform lifecycle, process management, permission requests, persistence, or network parsing.
- Use the highest seam available for each behavior. Prefer pure transformations and deterministic state transitions; introduce an injected interface only where an operating-system, process, network, or clock dependency prevents deterministic testing.
- Keep local persistence local. Do not add a remote server, cloud sync, backend database, or account system in this effort.
- Preserve current feature behavior, permission identity, bundle identity, display anchoring, and build/run workflow unless a later implementation ticket explicitly changes one of them.
- Establish one shared UI layout contract for shell dimensions, content insets, spacing, alignment, text fitting, image sizing, and state-specific geometry. Reuse existing motion and theme concepts where they are correct instead of creating parallel systems.
- Treat the current codebase as the visual source of truth. Preserve its Apple-inspired dark/translucent materials, rounded geometry, typography, motion, hierarchy, and component vocabulary; UI work is corrective-only and must not become a redesign.
- Keep motion calm and physical: the shell may use one restrained expansion overshoot, closing should settle quietly, blur is limited to content while it travels, resting text and controls stay crisp, artwork leads the morph, and the latest interaction wins during rapid state changes. Respect macOS Reduce Motion.
- Preserve the current interaction hierarchy: the compact pill is glanceable, the expanded island carries detail and controls, idle hover expansion remains optional, and active media/Codex strips remain click-first.
- Keep the existing Home hierarchy of media, calendar, and Codex status, with Lazy Shelf as a separate tab and Mirror/Settings as utility actions in the top bar.
- Keep the existing pointer engagement model: the shell stays open while the pointer is inside any interactive shell content, collapses after the configured departure grace period outside it, and remains held open during shelf file-drop operations.
- Use concise fallback copy with one recovery action where possible for empty, denied, unavailable, and failed states. Compact surfaces may tail-truncate with full text exposed through help or accessibility; expanded settings and content surfaces may wrap or scroll.
- Treat the current Apple-inspired motion as a corrective refinement, not a redesign: tune existing springs and blur choreography, keep resting content crisp, sequence artwork before text, respect Reduce Motion, and guard delayed transitions so the latest state wins.
- Replace brittle fixed geometry only where it causes the agreed defects. Use available geometry and content constraints to prevent clipping, overlap, accidental truncation, and excess spacing while keeping intentional visual dimensions stable.
- Validate the compact pill, expanded island, home widgets, media states, Codex states, shelf empty and staged states, settings, mirror window, hover states, transitions, long content, missing content, denied permissions, and supported display variations.
- Inventory source files, assets, generated outputs, documentation, and current deletions before cleanup. A file is deletable only when it has no required reference, build/resource role, supported feature role, or documentation role, or when an explicit decision rules it out.
- Remove stale README and index links and retain only documentation that describes the current product or records a durable decision. Do not restore obsolete documentation wholesale.
- Do not reset or discard the current working tree. Existing modifications are part of the input and must be classified rather than assumed to be accidental.
- Convert this spec into implementation tickets only after the relevant architecture, backend, UI validation, documentation, and migration decisions are resolved.

## Testing Decisions

- Tests should assert externally observable behavior and stable state transformations, not SwiftUI view structure, private helper names, or the exact number of view modifiers.
- Use the app composition boundary as the primary test seam. Test runtime wiring with fakes or controlled adapters where platform dependencies would otherwise make behavior nondeterministic.
- Test service transformations for media metadata, Codex usage parsing, calendar event grouping, shelf persistence and filtering, permission-state presentation, display selection, and shell state transitions.
- Test failure and empty states, including unavailable integrations, denied Calendar or Camera permissions, missing Codex installation, missing artwork, missing events, missing files, and failed external requests.
- Add the smallest test target and supporting seams needed for deterministic service behavior. Do not add a snapshot-testing framework or a broad testing abstraction without evidence that the native tools are insufficient.
- Validate UI externally with a screenshot and runtime matrix covering compact and expanded shell states, all supported widgets, empty and populated shelf states, settings, mirror, active and inactive live activities, long text, missing data, and representative supported display sizes.
- Check that UI validation finds no clipping, overlap, accidental truncation, unexpected whitespace, misaligned controls, broken hit regions, or transition jumps.
- Validate motion externally across hover, press, live-activity morph, expansion, collapse, tab changes, rapid toggles, and reduced-motion settings; resting content must be crisp and no stale transition state may remain visible.
- Run build verification after each implementation slice, then perform runtime smoke checks for launch, expansion/collapse, hover, permissions, media updates, calendar updates, shelf operations, mirror lifecycle, Codex activity, display changes, and settings persistence.
- There is no established test target or testing prior art in the current package, so the first implementation ticket must establish the minimum deterministic test seam before broad refactoring.

## Out of Scope

- Adding a remote backend, cloud sync, backend database, account system, or server API.
- Adding a plugin API or new user-facing product features.
- A full visual redesign unrelated to fixing alignment, cropping, overlap, truncation, spacing, responsiveness, or interaction defects.
- Changing supported feature behavior, permission identity, or build/run requirements without an explicit decision.
- Deleting ambiguous code or documentation based only on age, file size, recent inactivity, or personal preference.
- Restoring the deleted design, product, engineering, or research documents wholesale.
- Testing SwiftUI implementation details or introducing a large test framework for its own sake.

## Further Notes

- The wayfinder map for this effort is `.scratch/lazynotch-restructure/map.md`; its decisions are resolved and define the implementation sequence for the ready-for-agent tickets.
- The working tree already contains substantial user changes, including source edits and documentation deletions. Preserve them and classify them during implementation planning.
- The implementation tickets already capture the migration order and blockers. Implement one ticket at a time with the smallest deterministic test seam, the agreed runtime and visual gates, and a final standards/spec review.
