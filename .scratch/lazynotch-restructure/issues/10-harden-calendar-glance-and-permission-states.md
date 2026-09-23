# 10: Harden Calendar Glance and permission states

**What to build:** Preserve Calendar Glance while making event grouping, empty states, permission denial, and the week strip stable from calendar integration through the shell UI.

**Blocked by:** 08: Stabilize compact and expanded shell geometry.

**Status:** resolved

- [x] Upcoming events and week indicators render correctly in supported states.
- [x] No events, unavailable calendars, and denied permission produce clear usable states.
- [x] Calendar side effects and event transformations are isolated from views.
- [x] Event grouping and permission-state behavior have deterministic automated coverage.
- [x] Calendar states pass representative visual and runtime checks without cropping or excess spacing.

## Implementation evidence

- Centralized event grouping/sorting and cleared stale cache data on unavailable or denied permission.
- Added a Sendable-safe EventKit store boundary for background event fetching.
- Added deterministic grouping coverage; build and tests pass.
