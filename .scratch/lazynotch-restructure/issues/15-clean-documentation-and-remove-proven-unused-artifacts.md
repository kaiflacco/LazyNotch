# 15: Clean documentation and remove proven-unused artifacts

**What to build:** Align project documentation with the current product and architecture, repair stale links, and remove only source, asset, generated, or documentation artifacts proven unused or explicitly rejected.

**Blocked by:** 09: Harden Live Media Control end to end; 10: Harden Calendar Glance and permission states; 11: Harden Lazy Shelf persistence and layout; 12: Harden Hand Mirror lifecycle and preview fitting; 13: Harden Codex usage live activity; 14: Stabilize Settings and local preferences.

**Status:** resolved

- [x] README and index references resolve to current documentation.
- [x] Documentation retained in the repository describes supported features and current architecture.
- [x] Every deleted artifact has evidence that it is not required by source, build, resources, supported behavior, or project knowledge.
- [x] No user-facing feature or runtime resource is removed by cleanup.
- [x] The project still builds after cleanup and the deletion inventory is recorded.

## Implementation evidence

- Rewrote README and INDEX links to existing current documentation and removed missing image references.
- Kept obsolete design/product/engineering/research documents deleted per the resolved disposition; removed only the generated untracked `.DS_Store` from the planning area.
- `git diff --check`, stale-link scans, and `swift build` pass.
