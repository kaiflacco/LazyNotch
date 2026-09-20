# Changelog

All notable changes to LazyNotch will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned
- Settings persistence (UserDefaults + iCloud sync)
- Notification / Focus indicator in compact pill
- Plugin API for third-party widgets
- App Store / notarization pipeline

---

## [0.1.0] — 2026-09-21

### Added
- **Morphing notch shell** — `NotchShape` with animatable concave top-ears, rendered at ProMotion 120 Hz via a borderless `NSPanel` at `.screenSaver` level
- **Compact live-activity pill** — Album art (left wing) + live audio waveform (right wing) flanking the physical notch when music is playing; tappable to expand
- **Expanded island** — Full-width (598 × 164 pt) panel containing Media, Mirror, and Calendar widgets plus the Lazy Shelf tab
- **Media widget** — Vinyl artwork card (real album art via `AsyncImage` / Spotify artwork URL, with stylised vinyl fallback), track metadata, and playback controls (prev / play-pause / next) for Spotify and Apple Music via AppleScript
- **Calendar widget** — 7-day week strip (EventKit) with event-dot indicators, schedule glance card, and "Today" shortcut
- **Lazy Shelf** — Drag-and-drop file tray with QuickLook preview, AirDrop sharing, context menu (Open / Reveal in Finder / AirDrop / Remove), hover action buttons, and persistent-scroll horizontal list
- **Global Drop Zones** — Files dragged anywhere over the screen open the island and route to either the Tray or AirDrop zone
- **Hand Mirror** — One-click camera preview window with effect engine (`MirrorEffectEngine`) and AVFoundation capture
- **Display coordinator** — Detects notch presence, derives exact notch width from auxiliary menu-bar areas, adapts to display hotplug and resolution changes
- **Hover state machine** — 60 Hz cursor poll with enter (120 ms) and leave (220 ms) grace periods; `ignoresMouseEvents` toggling for WindowServer-level click-through
- **Stable codesign identity** — `build_run.sh` signs with `identifier "com.lazynotch.app"` so TCC grants survive every rebuild
- **Centralized spring physics** (`LazyNotchMotion`) — opening (response: 0.38, damping: 0.70), closing (0.28 / 0.84), content, hover, tab, and pill-morph springs
- **Design token palette** (`LazyNotchColors`) — notch black, surface white, text primary/secondary, accent blue, music red, dark card

### Architecture
- Swift 6.0, SPM executable target, macOS 14.6+
- Layered source tree: `App` → `Core` → `Features` → `UI`
- Full `@MainActor` isolation throughout; background work via `Task.detached`

[Unreleased]: https://github.com/kaiflacco/LazyNotch/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/kaiflacco/LazyNotch/releases/tag/v0.1.0
