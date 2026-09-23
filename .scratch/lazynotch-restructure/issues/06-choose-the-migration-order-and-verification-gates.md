# Choose the migration order and verification gates

Type: grilling
Label: wayfinder:grilling
Status: resolved
Blocked by: 02, 03, 04, 05

## Question

Choose the order for the architecture, in-process backend, UI/UX, and documentation cleanup work. Define the verification gates for each slice: build, tests, runtime behavior, permissions, persistence, supported displays, and screenshot-based visual checks. The result should be ready to hand off to `/to-spec`.

## Answer

### Migration order

1. [Introduce the app composition and test seam](07-introduce-the-app-composition-and-test-seam.md)
2. [Stabilize compact and expanded shell geometry](08-stabilize-compact-and-expanded-shell-geometry.md)
3. [Harden Live Media Control end to end](09-harden-live-media-control-end-to-end.md)
4. [Harden Calendar Glance and permission states](10-harden-calendar-glance-and-permission-states.md)
5. [Harden Lazy Shelf persistence and layout](11-harden-lazy-shelf-persistence-and-layout.md)
6. [Harden Hand Mirror lifecycle and preview fitting](12-harden-hand-mirror-lifecycle-and-preview-fitting.md)
7. [Harden Codex usage live activity](13-harden-codex-usage-live-activity.md)
8. [Stabilize Settings and local preferences](14-stabilize-settings-and-local-preferences.md)
9. [Clean documentation and remove proven-unused artifacts](15-clean-documentation-and-remove-proven-unused-artifacts.md)
10. [Run full regression and release handoff](16-run-full-regression-and-release-handoff.md)

### Verification gates

- Before and after each slice, use the existing supported build and run workflow.
- Add or run deterministic tests for changed state transitions, mappings, persistence, parsing, or fallback behavior.
- Run focused runtime smoke checks for the affected feature and confirm launch, permissions, persistence, bundle identity, and supported behavior remain intact.
- For UI slices, validate compact and expanded states, long and missing content, empty/active/denied/unavailable states, supported display variations, alignment, clipping, overlap, truncation, spacing, hit regions, and transitions.
- Use screenshots or equivalent visual checks against the current Apple-inspired UI language; visual review is corrective-only and must not introduce a redesign.
- Perform documentation cleanup only after all feature slices pass, record evidence for every deletion, then run the full regression and release handoff.
