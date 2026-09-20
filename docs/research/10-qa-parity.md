# LazyNotch — QA & Visual Parity

## Hardware matrix

Test at minimum:

- 14-inch MacBook Pro with notch
- 16-inch MacBook Pro with notch
- current MacBook Air with notch where applicable
- notchless Mac
- external 4K display
- multiple displays

Test the supported macOS versions beginning with macOS 14.6.

## Golden captures

Capture:

- idle
- hover
- 25% opening
- 50% opening
- fully open
- widget pages
- media
- empty LazyShelf
- populated LazyShelf
- calendar
- timer
- live activity
- settings

Use overlay/difference comparisons.

## Interaction checklist

### Shell

- activation zone
- opening delay
- closing delay
- no focus stealing
- correct physical-notch blending

### Navigation

- swipe
- scroll
- mouse
- trackpad
- boundary resistance
- keyboard fallback

### LazyShelf

- drag activation
- multi-file drop
- persistence
- preview
- drag-out
- remove

### Media

- detection
- artwork
- controls
- seek
- source changes
- unavailable source

### Platform

- display attach/detach
- sleep/wake
- full-screen
- Space changes
- permission denial
- permission revocation
- reduced motion
- VoiceOver

## Performance targets

Starting goals:

- negligible idle activity;
- no wasteful polling;
- smooth 60 fps animation on supported hardware;
- no shell-animation hitching;
- stable memory;
- camera/media resources released when unused.

Measure with Instruments rather than assuming.

## Bug record

Every parity issue should document:

1. reference behavior
2. LazyNotch behavior
3. reproduction
4. screenshot/video
5. root cause
6. expected fix
7. regression test
