# LazyNotch — UX Flows

## First launch

1. Launch as a background/menu-bar utility.
2. Detect displays.
3. Detect notch/safe-area geometry.
4. Initialize closed shell.
5. Explain permissions only when needed.
6. Provide short onboarding:
   - approach notch
   - open LazyNotch
   - navigate widgets
   - customize

## Hover activation

1. Cursor enters activation zone.
2. Apply hover threshold.
3. Start shell expansion.
4. Resolve current page.
5. Present content.
6. Keep pointer interaction stable during animation.

If the pointer exits during opening, close gracefully rather than snapping.

## Swipe navigation

1. Gesture starts inside shell.
2. Detect dominant axis.
3. Translate content with gesture.
4. Apply boundary resistance.
5. Release.
6. Snap to nearest page.

## LazyShelf file flow

1. User drags file toward top edge.
2. LazyNotch begins opening.
3. Drop state appears.
4. User releases.
5. Item enters LazyShelf.
6. Shelf persists item according to configured policy.
7. User can preview, remove, or drag item out.

## Media

1. Detect current media source.
2. Display artwork/title/artist.
3. Show playback state.
4. Support play/pause and navigation.
5. Support scrubbing when available.
6. Reconcile UI against source state.

## Calendar

1. Load authorized calendars.
2. Display current/upcoming events.
3. Navigate dates with gesture.
4. Tap event for details/open action.

## Timer

States:

```text
idle → running → paused → running → completed
```

Completed timers may become LazyLive activity indicators.

## Live activity

1. System event occurs.
2. Create activity.
3. Render compactly.
4. Update status/progress.
5. Expand only when needed.
6. Dismiss when complete.

## Permission denial

When a feature is denied:

- explain which feature needs access;
- keep unrelated features working;
- provide a Settings path;
- never repeatedly prompt without user action.
