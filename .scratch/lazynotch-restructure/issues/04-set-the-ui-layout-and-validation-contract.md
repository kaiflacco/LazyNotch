# Set the UI layout and validation contract

Type: prototype
Label: wayfinder:prototype
Status: resolved

## Question

Using the current app behavior and available screenshots or screen recordings, define the canonical layout contract for the compact pill, expanded island, widgets, shelf, settings, mirror window, hover states, and transitions. Resolve supported sizes, alignment, spacing, cropping, truncation, and display variations with a cheap visual artifact or concrete validation matrix—not production code.

## Answer

The current codebase is the visual source of truth. Preserve its Apple-inspired dark/translucent materials, rounded geometry, typography, motion, hierarchy, and existing theme/component vocabulary. Do not redesign the UI or introduce alternate layout variants.

The UI implementation scope is corrective only: fix text alignment, spacing, clipping, truncation, overlap, hit regions, and transition geometry where defects are observed. Keep intentional dimensions, visual hierarchy, and established interaction behavior stable.

Validate the existing compact pill, expanded island, widgets, shelf, settings, mirror window, hover states, transitions, long and missing content, denied permissions, and supported display variations against the current app and its existing screenshots or recordings.
