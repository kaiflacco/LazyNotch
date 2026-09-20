# LazyNotch — Architecture

## Recommended stack

- Swift 6+
- SwiftUI
- AppKit
- macOS 14.6+

SwiftUI should handle most presentation. AppKit should own window/panel lifecycle, display integration, lower-level event handling and platform edge cases.

## Process

```text
AppDelegate
├── DisplayCoordinator
├── LazyNotchWindowController
├── EventMonitor
├── SettingsStore
├── PermissionCoordinator
└── FeatureContainer
    ├── MediaService
    ├── LazyShelfService
    ├── CalendarService
    ├── CameraService
    ├── TimerService
    ├── NotesService
    ├── TodoService
    ├── ShortcutService
    ├── HUDService
    └── LiveActivityService
```

## Window

Prefer a borderless `NSPanel`/window configured for:

- no title bar
- transparent outer frame
- content-driven shell
- correct screen association
- no unnecessary focus stealing
- correct Spaces/full-screen behavior

## State

```text
closed
opening
open
closing
dragTarget
liveActivity
```

Feature state must remain separate from shell state.

## Display coordinator

Responsibilities:

- enumerate `NSScreen`
- calculate notch/safe-area geometry
- determine anchor
- support external displays
- react to display changes

Never rely only on persisted absolute screen coordinates.

## Persistence

Persist:

- widget order
- enabled widgets
- gestures
- appearance
- selected calendars
- LazyShelf contents
- shortcuts
- display preferences
- keyboard shortcuts

Use versioned migrations.

## Input priority

```text
system-critical
    ↓
drag/drop
    ↓
shell gesture
    ↓
widget gesture
    ↓
control click
```

Avoid global event interception unless necessary.

## Distribution

Production distribution should use:

- Developer ID signing
- hardened runtime
- notarization
- appropriate installer/update mechanism

Sandbox limitations must be considered before promising App Store distribution.
