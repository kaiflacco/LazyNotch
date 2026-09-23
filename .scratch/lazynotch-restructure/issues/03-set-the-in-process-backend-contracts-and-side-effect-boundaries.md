# Set the in-process backend contracts and side-effect boundaries

Type: grilling
Label: wayfinder:grilling
Status: resolved
Blocked by: 02

## Question

Define the contracts for LazyNotch’s in-process services and integrations: media, calendar, camera, Codex app-server communication, shelf persistence, permissions, display coordination, and window control. Decide ownership of side effects, concurrency, errors, lifecycle, and local data without introducing a remote backend.

## Answer

- Each Feature owns its user-facing state and commands. Each Integration wraps one external effect, such as MediaRemote, EventKit, AVFoundation, Codex process I/O, filesystem persistence, or display APIs.
- Integrations report normalized feature-facing states: ready, denied, unavailable, or failed. Views render those states and do not own platform error handling or recovery policy.
- Feature state and UI updates stay on the main actor. Platform, network, and process work runs off the main actor and returns through explicit state updates.
- Runtime lifecycle is explicit. Integrations start and stop through lifecycle methods, and observers, tasks, and processes are cancelled when their owning feature shuts down.
- Failed artwork, metadata, usage requests, and external calls degrade to the last valid state or a clear fallback. They must not crash the app or distort shell layout.
- Calendar and Camera denial is stable and non-repeating: the feature exposes denied state, keeps unrelated features functional, and provides a path to the relevant macOS settings.
- Persistence remains local and narrow: existing preferences and valid Lazy Shelf paths only. No remote data, account state, cloud sync, or new database is introduced.
- External integrations are substituted only where deterministic tests need them; do not add interfaces for types that have no meaningful alternate implementation.
