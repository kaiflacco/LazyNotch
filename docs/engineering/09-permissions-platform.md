# LazyNotch — Permissions & Platform

## Principle

LazyNotch should request permissions when the user activates a feature that needs them.

## Calendar

Use EventKit for calendar access.

Request access only when Calendar functionality is used.

## Camera

Use AVFoundation.

Request camera access when Mirror is activated.

## Notifications

Use UserNotifications for relevant live activity/notification behavior.

## Accessibility

May be required for global input/HUD-related functionality. Explain the purpose before requesting access.

## Automation

Some media or Shortcuts integrations may require Apple Events/automation permissions depending on implementation.

## Screen Recording

Do not request Screen Recording unless an implemented feature genuinely requires it.

## Private APIs

Some public parity research may mention private/system-level techniques. LazyNotch should prefer public APIs.

If a private technique is unavoidable for a specific feature:

- isolate it;
- document OS compatibility;
- provide fallback behavior;
- test every major macOS release.

## Display geometry

Use public display APIs where possible. Never assume a single notch size.

## Multi-monitor

Each display needs:

- anchor geometry
- notch/no-notch classification
- active-space awareness
- shell state

## Full-screen

Test:

- native full-screen apps
- borderless full-screen
- Spaces
- Stage Manager
- external displays
- display sleep/wake

## Privacy

Process media/calendar/shelf data locally whenever possible.

Document exactly what LazyNotch stores and why.
