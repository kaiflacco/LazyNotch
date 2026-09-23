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

## Recording timing check (2026-09-23)

Reviewed all 2,618 decoded frames of `Screen Recording 2026-09-22 at 7.42.14 PM.mov`
in presentation order, using their original timestamps (variable frame rate), without
0.5s/1s sampling. Frame numbers below are one-based. Times are approximate visual
landmarks, not a claim of an exact spring fit:

- Idle opening: frame 158 (2.842s) starts expanding; frames 166–178
  (3.000–3.217s) show the blurred reveal; by frame 185 (3.350s) it is sharp.
- Media opening: frames 1378–1405 (28.888–29.380s) show growth, blur, then
  sharpening; the remaining settling continues after the content becomes legible.
- Media closing: frames 1027–1050 (22.355–22.772s) show defocus and continuous
  contraction into the compact strip.

Use a 0.50s opening spring response and a 0.37s content reveal after a 0.08s
lead-in. Closing uses a lightly bouncing 0.45s spring response, with content
fading over 0.20s and shell contraction starting after 0.06s. Spring response
is not total animation duration. Bind geometry animation to `shellExpanded`,
which actually changes shell dimensions, so delayed collapse cannot snap.

For runtime verification, record idle and media opening/closing, plus a quick
close/reopen, and inspect consecutive frames with original timestamps. A build
check alone does not establish visual parity with the recording.
