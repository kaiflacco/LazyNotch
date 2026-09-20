# LazyNotch — Implementation Plan

## Phase 0 — Reference capture

Before detailed UI implementation:

1. Run the current reference product.
2. Capture every public feature.
3. Record:
   - macOS version
   - hardware
   - display scale
   - shell geometry
   - activation threshold
   - animation timings
   - gesture thresholds
   - widget order
   - settings
4. Annotate captures.
5. Record observations without copying implementation assets/code.

Deliverable:

```text
reference/
  screenshots/
  videos/
  measurements/
  behavior-log.md
```

## Phase 1 — Shell

Build:

- display coordinator
- notch geometry
- borderless panel
- closed/open states
- hover activation
- shell animation

## Phase 2 — Widget framework

Build:

- widget protocol
- viewport
- navigation
- gestures
- lifecycle
- persistence

Use fake widgets first.

## Phase 3 — LazyShelf

Implement:

- drag activation
- drop target
- persistence
- multi-file handling
- preview
- drag-out

## Phase 4 — Media

Implement a provider abstraction first, then concrete system integrations.

## Phase 5 — Core widgets

Implement:

- Calendar
- Timer
- Mirror
- Notes
- Todos
- Shortcuts

Every feature needs loading/error/permission states.

## Phase 6 — Live + HUD

Implement live activities.

Treat system HUD replacement as a separate technical-risk track.

## Phase 7 — Settings

Expose only capabilities that are actually implemented.

## Phase 8 — Notchless + multi-monitor

Make geometry display-specific.

## Phase 9 — Visual calibration

Tune one category at a time:

1. geometry
2. spacing
3. typography
4. materials
5. animation
6. gesture thresholds

## Phase 10 — Hardening

- accessibility
- reduced motion
- permissions
- sleep/wake
- full-screen
- displays
- performance
- signing
- notarization

## Suggested project tree

```text
LazyNotch/
├── Sources/
│   ├── App/
│   ├── Core/
│   │   ├── Display/
│   │   ├── Shell/
│   │   ├── Persistence/
│   │   ├── Permissions/
│   │   └── Events/
│   ├── UI/
│   │   ├── Shell/
│   │   ├── Components/
│   │   ├── Widgets/
│   │   └── Settings/
│   └── Features/
│       ├── Media/
│       ├── LazyShelf/
│       ├── Calendar/
│       ├── Mirror/
│       ├── Timers/
│       ├── Notes/
│       ├── Todos/
│       ├── Shortcuts/
│       ├── HUD/
│       └── LiveActivities/
├── Resources/
├── Tests/
└── Docs/
```
