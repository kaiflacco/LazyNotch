# LazyNotch — Animation Specification

## Core principle

The animation should communicate:

**physical notch → LazyNotch → expanded utility surface**

It should not look like a conventional popover appearing from nowhere.

## Opening

1. Activation begins.
2. Shell expands.
3. Corners morph.
4. Content enters.
5. Controls become interactive near the end.

Avoid abrupt geometry jumps.

## Closing

Reverse the opening motion with slightly faster timing.

Content should collapse before the shell reaches its final closed geometry.

## Widget swipe

The user's gesture should directly manipulate the content.

Use:
- translation
- velocity-aware snap
- boundary resistance

Avoid replacing gesture navigation with a pure crossfade.

## LazyShelf drag

As a file approaches:

1. shell begins opening;
2. drop target becomes visible;
3. target gains emphasis;
4. item settles into shelf after release.

## Live activity

Use compact entrance/update/exit animations. Do not continuously pulse unless the state genuinely requires attention.

## Reduced motion

When enabled:

- remove spring overshoot;
- shorten transitions;
- use fade/position transitions;
- preserve state feedback.
