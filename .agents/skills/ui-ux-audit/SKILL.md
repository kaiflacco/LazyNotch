---
name: ui-ux-audit
description: Audit an entire application codebase as a senior UI/UX reviewer and QA analyst, finding user-facing bugs, accessibility gaps, interaction failures, and visual inconsistencies with evidence and priorities.
---

# UI/UX Audit

Audit the product as a user-facing system, not just a collection of views. Combine senior product design judgment with software-quality investigation. The default outcome is a report and prioritized findings; do not change product code unless the user explicitly asks for fixes.

The audit must respect the product's existing language and intent. Read `CONTEXT.md`, relevant ADRs, and project instructions before judging terminology, layout contracts, or established visual choices. For LazyNotch, use terms such as `Shell`, `compact pill`, `expanded island`, `live activity`, `Feature`, `Lazy Shelf`, and `Layout contract` exactly as defined there.

## Deliverable

Finish with all of these:

- a short product-level verdict: what is working, what threatens trust or task completion, and the three highest-leverage improvements;
- a coverage map showing every user-facing surface and the states or journeys inspected;
- prioritized findings with evidence, user impact, severity, confidence, and a concrete recommendation;
- explicit coverage gaps where runtime access, a device, permission, fixture, or user decision was unavailable;
- a durable Markdown report at `.scratch/ui-ux-audit/REPORT.md`. If that report already exists, preserve it and write to a timestamped sibling such as `.scratch/ui-ux-audit-2026-09-26-1430/REPORT.md`.

Do not create implementation tickets unless the user asks for them. Do not fix findings during the audit; keep the report useful as a review artifact and let implementation follow the project's normal flow.

## 1. Establish the evidence boundary

Start by stating what kind of audit is possible in the current environment:

- **Runtime evidence**: flows actually exercised in the built app, with the command, environment, and observed result.
- **Code evidence**: deterministic behavior inferred from source, tests, configuration, or call paths.
- **Heuristic evidence**: a design, accessibility, or interaction concern that needs human or runtime confirmation.

Never present a heuristic as a confirmed bug. Label confidence as `High`, `Medium`, or `Low`. A visual judgment based only on source code is code-inferred, not runtime-verified.

## 2. Build a whole-codebase inventory

Before critiquing the first screen, map the product:

1. Read `AGENTS.md`, `CONTEXT.md`, `README.md`, `Package.swift` or the equivalent project manifest, relevant ADRs, and the configured build/test commands.
2. Enumerate source and resource files with `rg --files`. Classify application entry points, windows, screens, views, feature state, integrations, persistence, tests, and design tokens.
3. Locate UI and interaction surfaces by searching for the framework's view declarations and interaction boundaries: buttons, menus, toggles, pickers, gestures, keyboard handling, sheets, popovers, alerts, drag and drop, focus, accessibility modifiers, notifications, timers, and window controllers.
4. Trace each visible surface back to the state and integration that drive it. Note where the same concept has more than one source of truth.
5. Build a coverage matrix before forming conclusions. Include every feature, window, modal, compact/expanded state, settings area, empty state, permission state, loading state, error state, and external-system handoff that the code exposes.

For this macOS app, explicitly inspect the AppKit/SwiftUI seams, notch and non-notch displays, screen changes, Spaces and full-screen behavior, window activation, outside-click dismissal, camera and calendar permission paths, pasteboard and Finder drag/drop, and launch/persistence behavior.

## 3. Walk the user journeys

Derive journeys from the code and product language, then inspect them end to end. Do not limit the audit to isolated screenshots. Include the applicable journeys below and add product-specific ones discovered during inventory:

- launch, idle compact pill, hover, click, expand, tab navigation, and collapse;
- live activity appearing, changing, competing with another activity, becoming unavailable, and disappearing;
- Lazy Shelf: add, select, multi-select, preview, open, drag out, receive a Finder drop, unavailable source, and persistence across launch;
- Hand Mirror: request permission, show camera, change effect, resize or reposition, dismiss, and recover from camera failure;
- Calendar or other integrations: loading, denied permission, empty data, stale data, and service failure;
- Settings: open, switch sections, change every control, failure to save or register, dismiss with Escape/outside click, and relaunch persistence;
- keyboard-only and VoiceOver-oriented navigation for every important task;
- reduced motion, increased text size, high-contrast settings, different display sizes, and no-notch hardware when the platform supports them.

For each journey record the user's goal, starting state, action sequence, visible feedback, final state, and recovery path. Mark steps that are inferred rather than observed.

## 4. Audit the experience in seven passes

### Product clarity and hierarchy

- Is the user's current location and available next action obvious in every state?
- Does terminology match the product glossary and the user's mental model?
- Is the primary action visually and behaviorally distinct from secondary actions?
- Does compact UI reveal enough context to earn expansion, and does expanded UI preserve the relationship to the compact state?
- Does each visible element earn its space, especially in transient or constrained surfaces?

### Layout and visual craft

- Check geometry, alignment, clipping, safe areas, anchoring, hit regions, and text fitting at realistic sizes.
- Check hierarchy through type size, weight, contrast, spacing, and grouping. Apply a squint test: the primary content and action should remain legible as structure.
- Check that spacing follows a coherent scale, surfaces use a deliberate elevation strategy, and color communicates meaning rather than decoration.
- Check light/dark or translucent materials, semantic colors, contrast, color-blind distinguishability, and readability over changing content.
- Check window resizing, display scale, varying screen frames, notch dimensions, long labels, localization-like text expansion, and missing assets.

### Interaction and affordances

- Every interactive element needs an understandable affordance and a complete state model: default, hover, pressed, focused, disabled, loading, success, empty, and error where applicable.
- Verify hit targets, pointer behavior, keyboard equivalents, focus order, Escape/cancel, undo or recovery, and outside-click behavior.
- Check drag/drop insertion, selection, reordering, preview/open actions, destructive actions, and whether the visual target matches the actual hit target.
- Look for controls that only work through hover, hidden actions with no discoverability, gestures with no alternative, and state changes with no feedback.

### Accessibility

- Use native semantic controls whenever possible. Verify labels, values, hints, traits, focusability, keyboard reachability, and VoiceOver reading order.
- Do not rely on color, motion, hover, or icon shape alone to convey state or action.
- Check text and control contrast, focus visibility, readable disabled states, text scaling, reduced motion, and dynamic content announcements.
- For macOS specifically, check menu/keyboard access, toolbar and window semantics, full keyboard navigation, and whether custom AppKit surfaces expose useful accessibility information.

### State, resilience, and trust

- Find every async, permission, persistence, file, camera, calendar, media, or external-process path and inspect loading, unavailable, stale, denied, partial, empty, and failure states.
- Check whether errors explain what happened, whether the user can recover, and whether the UI falsely implies success.
- Check state ownership and lifecycle: stale views after dismissal, updates arriving after teardown, notifications or timers that outlive windows, contradictory flags, race-prone transitions, and persistence that does not match the UI promise.
- Treat data loss, silent failure, accidental destructive actions, inaccessible core work, and misleading system status as high priority.

### Native platform correctness

For SwiftUI/AppKit macOS code, inspect the platform-specific failure modes that are easy to miss in a visual review:

- `@State`, `@Binding`, `@ObservedObject`, `@StateObject`, `@Observable`, and environment data match ownership and invalidation boundaries;
- `ForEach` identity is stable, collection rows are structurally valid, and view identity does not reset user-visible state unexpectedly;
- version-specific APIs are availability-gated with sensible fallbacks;
- display scale and geometry are read near the view that consumes them rather than from a stale global screen assumption;
- window levels, collection behavior, activation, focus, key/main-window status, and dismissal are intentional;
- AppKit event monitors, notification observers, timers, Combine subscriptions, and camera/media resources are removed or stopped at the right lifecycle boundary;
- custom drawing, animation, `TimelineView`, and live camera/media updates do not create visible stutter, excess battery use, or interaction starvation;
- privacy prompts and permission-denied paths are user-comprehensible and recoverable.

### Consistency and system coherence

- Compare the same concept across features: close, back, settings, selection, unavailable content, errors, status, and primary actions should not change meaning or placement without reason.
- Compare the code's tokens, reusable components, motion constants, window geometry, and accessibility treatment. Repeated magic values or near-duplicate controls are signals to inspect, not automatic refactor requests.
- Preserve intentional differences when the product language or task context explains them.

## 5. Turn evidence into findings

Report only findings that can help someone act. Every finding must use this shape:

```markdown
### UIUX-001 — Short, user-centered title

- **Type:** Bug | Accessibility | UX friction | Visual craft | Risk / hypothesis
- **Severity:** P0 | P1 | P2 | P3
- **Confidence:** High | Medium | Low
- **Surface / journey:** The exact screen, state, and task
- **Evidence:** `Sources/Path/File.swift:123` and/or the exact runtime step and result
- **Trigger:** The smallest action or condition that exposes it
- **Actual:** What the user sees or what the code deterministically does
- **Expected:** The behavior that best supports the user's goal and product language
- **Impact:** Who is blocked, misled, slowed down, or excluded
- **Recommendation:** The smallest coherent product or code change that addresses the cause
- **Verification:** A test, runtime check, screenshot, accessibility check, or acceptance condition
```

Use line-numbered source references (`nl -ba`, editor locations, or test output). Cite the source of truth, not only a downstream symptom. Group duplicate symptoms under one root finding. Include a positive observation when it explains why the current design works or should be preserved.

Severity rubric:

- `P0`: crash, data loss, security/privacy harm, or the product's core task is impossible;
- `P1`: a common core journey is blocked, inaccessible, misleading, or cannot recover;
- `P2`: meaningful friction, inconsistent state, broken edge case, or repeated accessibility/visual issue;
- `P3`: polish, minor inconsistency, low-frequency edge case, or improvement with limited task impact.

Confidence rubric:

- `High`: reproduced at runtime, covered by a failing test, or proven by a deterministic code path;
- `Medium`: strong source evidence but runtime confirmation is unavailable;
- `Low`: plausible heuristic or visual concern that needs a device, user, or design decision to confirm.

Do not call an aesthetic preference a bug. Do not recommend a redesign merely because another pattern is more fashionable. Tie every recommendation to a user goal, an observed failure, a platform convention, or the product's established `Layout contract`.

## 6. Verify and write the report

Run the project's smallest relevant verification commands after discovery: tests, type/build checks, lint, and a runnable app build when available. Prefer existing scripts and commands from the repository. If launching the app is safe and possible, exercise the highest-risk journeys and capture the environment and result. Use screenshot or accessibility tooling when available; otherwise state the limitation.

Before writing the report, perform a contradiction pass:

- every finding has evidence and a confidence level;
- every surface in the inventory is either covered or listed as a gap;
- confirmed bugs are separated from hypotheses and design opportunities;
- recommendations address causes and preserve supported behavior;
- severity reflects user impact, not how easy the fix looks;
- no unrelated source files were modified.

Write the report with this structure:

```markdown
# UI/UX Audit — <project>

## Executive verdict

## Evidence boundary and verification

## Coverage matrix

## Prioritized findings

## Strengths to preserve

## Coverage gaps and open questions

## Recommended next sequence
```

In the final response, link the report, summarize the top findings, state what was verified, and say whether product code was left unchanged.
