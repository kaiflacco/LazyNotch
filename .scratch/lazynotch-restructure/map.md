# LazyNotch architecture, backend, and UI/UX restructure

Label: wayfinder:map
Status: resolved

## Destination

Produce a buildable plan for a maintainable, local-first LazyNotch architecture that preserves supported user-facing features, improves the in-process backend and integration boundaries, and fixes UI/UX layout defects such as misalignment, cropping, overlap, truncation, and excess spacing.

The map is complete when the implementation order and verification gates are clear. Planning does not perform the rewrite or delete files.

## Notes

- Native macOS Swift/SwiftUI app with one executable target.
- Preserve supported features and current user-facing behavior unless a later decision explicitly changes them.
- Treat the current uncommitted working tree as input. Do not reset or discard it.
- “Backend” means the in-process service, state, persistence, permission, process, and network-integration layer. Do not add a remote server or cloud sync in this effort.
- UI work covers the compact pill, expanded island, widgets, shelf, settings, mirror window, hover states, and transitions.
- UI acceptance requires no clipped, overlapping, accidentally truncated, or inconsistently spaced content across supported states and displays.
- Delete only files proven unused or explicitly ruled out after classification; remove stale documentation links rather than restoring obsolete docs wholesale.
- Consult `codebase-design` and `domain-modeling` during decisions. Use `prototype` for unresolved visual questions; use `tdd` and `code-review` after the map hands off to implementation planning.
- Local tracker: child tickets live under `.scratch/lazynotch-restructure/issues/`.

## Decisions so far

- [Inventory and classify the current code and docs](issues/01-inventory-and-classify-the-current-code-and-docs.md): live source and current edits are preserved; broken documentation links and missing README assets are confirmed; no safe deletion candidate is proven yet.
- [Set the target module boundaries and state ownership](issues/02-set-the-target-module-boundaries-and-state-ownership.md): keep one executable with an app-scoped Runtime, explicit feature/integration surfaces, shell-owned presentation state, and expand–contract migration away from singleton access.
- [Set the in-process backend contracts and side-effect boundaries](issues/03-set-the-in-process-backend-contracts-and-side-effect-boundaries.md): Features own state and commands; Integrations own effects, lifecycle, normalized failures, graceful degradation, and local-only persistence.
- [Set the UI layout and validation contract](issues/04-set-the-ui-layout-and-validation-contract.md): preserve the current Apple-inspired visual language and make UI work corrective-only for alignment, spacing, clipping, truncation, overlap, hit regions, and transition geometry.
- [Decide the documentation and deletion disposition](issues/05-decide-the-documentation-and-deletion-disposition.md): retain current product and workflow artifacts, keep obsolete docs deleted, repair stale links, and require direct evidence before deleting ambiguous files.
- [Choose the migration order and verification gates](issues/06-choose-the-migration-order-and-verification-gates.md): introduce composition and tests first, stabilize shell geometry before feature slices, clean docs near the end, and finish with full regression and visual checks.

## Not yet specified


## Out of scope

- A new remote backend, cloud sync, or backend database.
- A plugin API or new user-facing product capabilities.
- A full visual redesign unrelated to fixing the agreed UI/UX defects.
- Deleting files solely because they are old, large, or recently unused without evidence.
