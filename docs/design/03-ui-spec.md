# LazyNotch — UI Specification

## Visual identity

LazyNotch should be recognizable as a compact, premium macOS utility while maintaining an original brand identity.

The primary shell is:

- near-black
- rounded
- compact when idle
- wider/taller when expanded
- visually connected to the physical notch
- low-chrome
- content-first

## Shell states

### Closed

- Minimal black/dark surface
- blends into physical notch
- optional live activity content
- no conventional window chrome

### Hover

- subtle response to cursor proximity
- activation begins without a hard pop

### Opening

- shell geometry expands
- corners morph
- content enters progressively

### Open

- rounded dark panel
- widget content immediately readable
- navigation is visually secondary

### Detail

- same outer shell
- internal content changes
- no separate window

### Drag target

- shell expands when a file approaches
- clear drop affordance
- drop result animates into LazyShelf

## Geometry

These are implementation starting points, not measured claims about NotchNook.

```yaml
closed:
  height: notch-derived
  width: notch-derived

open:
  minWidth: 360
  preferredWidth: 440-620
  maxWidth: 55vw
  minHeight: 120
  preferredHeight: 260-420
```

Geometry must be calibrated on actual target hardware.

## Layout

```text
LazyNotchShell
├── LazyLiveRail
└── LazyNotchContent
    ├── ContextHeader
    ├── WidgetViewport
    │   ├── WidgetCard
    │   └── WidgetCard
    └── PageIndicator
```

## Typography

Use native macOS system typography.

Initial hierarchy:

- micro: 10–11 pt
- metadata: 11–12 pt
- body: 13–15 pt
- prominent values: 20–28 pt
- titles: 15–18 pt semibold

Do not bundle Apple's system fonts.

## Interaction targets

Even visually compact controls must have practical hit areas:

- compact: 28 pt
- standard: 32 pt
- primary: 36 pt

## Accessibility

Every control needs:

- VoiceOver label
- keyboard accessibility where appropriate
- reduced-motion behavior
- reduced-transparency behavior
- sufficient contrast
