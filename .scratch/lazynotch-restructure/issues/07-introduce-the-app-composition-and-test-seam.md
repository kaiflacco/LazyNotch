# 07: Introduce the app composition and test seam

**What to build:** Keep LazyNotch’s existing launch and shell behavior while assembling runtime services at the app boundary and making a representative shell behavior testable with controlled dependencies.

**Blocked by:** 06: Choose the migration order and verification gates.

**Status:** resolved

- [x] The app launches and compact/expanded shell behavior remains unchanged.
- [x] Runtime services are assembled through one explicit composition boundary.
- [x] A representative shell behavior can run with controlled service state.
- [x] A deterministic test covers the representative state transition or fallback.
- [x] Existing legacy access paths remain available until their migrations complete.

## Implementation evidence

- Added `LazyNotchRuntime` as the app-scoped composition and lifecycle boundary.
- Added shell transition tests in `Tests/LazyNotchTests/ShellViewModelTests.swift`.
- `swift test` and `swift build` pass.
