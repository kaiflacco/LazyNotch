# LazyNotch — Component Contracts

## LazyNotchShell

Responsibilities:
- display placement
- notch geometry
- activation
- open/closed state
- drag activation
- animation
- accessibility

## LazyLiveRail

Responsibilities:
- compact live activity
- priority selection
- status/progress
- automatic dismissal

## WidgetViewport

Responsibilities:
- widget pages
- gesture navigation
- page indicator
- lifecycle

## WidgetCard

Every widget supports:

- loading
- content
- empty
- error
- accessibility
- compact/expanded presentation

## MediaWidget

```text
MediaState
  source
  title
  artist
  album
  artwork
  duration
  position
  isPlaying
  canSeek
  canSkip
  repeat
  shuffle
```

## LazyShelf

```text
ShelfItem
  id
  kind
  displayName
  sourceURL
  thumbnail
  addedAt
  persisted
```

Actions:
- add
- remove
- preview
- select
- drag out

## CalendarWidget

```text
CalendarEvent
  id
  calendarID
  title
  start
  end
  location
  isAllDay
```

## MirrorWidget

- camera lifecycle
- preview
- camera selection
- privacy state
- graceful denial

## TimerWidget

- idle
- running
- paused
- completed

## NotesWidget

- edit
- autosave
- recovery

## TodoWidget

- create
- favorite
- complete
- archive
- restore

## ShortcutWidget

- enumerate shortcuts
- execute
- running state
- failure state

## LazyHUD

Optional system-feedback overlay. Global event interception is a high-risk platform feature and must be isolated behind a service protocol.

## Settings

Use a normal native macOS Settings window.
