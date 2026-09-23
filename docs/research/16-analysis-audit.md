# LazyNotch — Implementation Analysis & Audit

| | |
|---|---|
| **Date** | 2026-09-22 |
| **Commit audited** | `35e5968` (main) |
| **Scope** | Full source tree (`Sources/`, 24 Swift files, 4,987 LOC), build system, CI, docs |
| **Method** | Static code audit of every source file, docs↔code parity check against `15-parity-checklist.md`, live build verification (`swift build`, debug, **13.75s — success**), evidence-grep for API usage |
| **Status legend** | ✅ shipped & verified · 🟡 partial / qualified · ❌ absent |

---

## 1. Executive Summary

LazyNotch is a **working, well-architected 0.x product** whose core loop — hover → morph → widgets → LazyShelf — is fully implemented and builds cleanly. The engineering quality of the shell layer (geometry, spring choreography, drag routing, hit-testing) is genuinely high and matches the design docs.

The audit surfaces three systemic gaps that block a 1.0 release:

1. **Accessibility is entirely absent.** Zero accessibility API usage exists in the codebase (verified by exhaustive grep): no VoiceOver labels, no keyboard focus model, no Reduced Motion / Reduced Transparency handling, and several contrast failures. Every Accessibility row in the parity checklist is ❌.
2. **There is no way to quit the app and no menu-bar presence.** `LSUIElement` accessory app with no `NSStatusItem`, no menu, no quit affordance anywhere in code.
3. **Notchless Macs get a dead shell.** The closed hit-zone degrades to `200 × 0` px, so hover can never engage on notchless hardware; only the global drag approach remains functional.

Additionally: two dead source files ship in the binary, user-visible defaults disagree with each other, and the CHANGELOG/About documents constants that no longer match the code.

**Verdict: feature-complete for the v0.1 widget set (Media, Calendar, Mirror, LazyShelf), architecturally sound, not release-ready.** Estimated remediation to a shippable 1.0 is dominated by accessibility, lifecycle/quit UX, and release engineering — not by core features.

---

## 2. As-Built Architecture

Single SPM executable target (`LazyNotch`, macOS 14+), zero external dependencies, `LSUIElement` accessory app. State is held in `ObservableObject` singletons (`MediaService.shared`, `CalendarService`, `LazyShelfStore`, `CameraManager.shared`) plus a `ShellViewModel` whose entire expansion state is a single `isExpanded: Bool`.

### File map (4,987 LOC / 24 files)

| Area | File | LOC | Role |
|---|---|---:|---|
| Shell | `UI/Shell/ShellContentView.swift` | 760 | NotchShape, morphing island, compact strip, expanded content, drop HUD, morph-reveal choreography |
| Widgets | `UI/Widgets/WidgetGrid.swift` | 674 | `HomeRow`, `MediaWidget` + `VinylArtwork` (matched-geometry album art), `CalendarWidget` |
| Shell | `UI/Shell/LazyNotchWindowController.swift` | 503 | Borderless NSPanel (`.screenSaver` level, non-activating, all-spaces/full-screen-auxiliary), 60 Hz cursor poll, hover grace timers, drag detection, sizing/positioning |
| Settings | `Features/Settings/SettingsSheet.swift` | 458 | 5-tab settings (General, Permissions, Notch, LazyShelf, About), SMAppService launch-at-login |
| LazyShelf | `Features/LazyShelf/LazyShelfView.swift` | 386 | Drop target, staging cards, drag-out, context menu, NSOpenPanel staging (300 s hold-open) |
| Mirror | `Features/Mirror/MirrorEffectEngine.swift` | 261 | Vision face detection → emoji effects (lovestruck / dizzy / money), CIContext pipeline |
| Media | `Features/Media/MediaService.swift` | 260 | Spotify/Music AppleScript bridge, 1.5 s poll + distributed notifications, artwork fetch, transport controls |
| Calendar | `Features/Calendar/CalendarService.swift` | 243 | EventKit, explicit permission flow, 60 s refresh, −4/+4 day window |
| Mirror | `Features/Mirror/CameraManager.swift` | 233 | AVCapture session on worker queue, permission states, 60 s re-check |
| Mirror | `Features/Mirror/HandMirrorView.swift` | 208 | Teardrop shape, inline camera preview, filter menu, persisted mirror toggle |
| Shell | `UI/Shell/ShellHostingView.swift` | 202 | Hit-test narrowing, file-URL drag registration, haptics, AirDrop/tray routing |
| Mirror | `Features/Mirror/MirrorWindowController.swift` | 131 | Separate panel, ESC local monitor, click-outside global monitor, camera lifecycle |
| Motion | `UI/Motion/LazyNotchMotion.swift` | 114 | Spring catalog (see §5, F-05) |
| Misc | 11 remaining files | 11–134 | AppDelegate, DisplayCoordinator, models, stores, **dead code (F-07/F-08)** |

### Key runtime mechanisms (verified in code)

- **Geometry:** `DisplayCoordinator` derives notch metrics from `NSScreen.safeAreaInsets` + `auxiliaryTopLeftArea/RightArea`; reacts to `didChangeScreenParametersNotification` (display hot-plug handled).
- **Hover:** 60 Hz `Timer` cursor poll; enter grace 0.12 s, leave grace read from `UserDefaults.hoverGraceDuration` with a hard-coded 0.22 s fallback (see F-04).
- **Drag detection:** global `NSPasteboard(.drag).changeCount` + pressed-mouse-button heuristic (fragile by design, see F-11); drop routing distinguishes AirDrop vs tray.
- **Panel behavior:** `ignoresMouseEvents` toggled per state so the shell never blocks clicks outside its visual region; `holdOpenUntil` keeps the panel open during shelf operations.



---

## 3. Parity Audit vs `15-parity-checklist.md`

Each checklist row is graded against the code as of `35e5968`. Evidence references are file-level.

### Identity — 6/6 ✅
| Item | Status | Evidence |
|---|---|---|
| Branding / no reference-product leakage / logo / icons / About / bundle metadata | ✅ | `CFBundleIdentifier com.lazynotch.app`; About reads "LazyNotch"; originality per `14-clean-room.md` register |

### Shell — 5/8
| Item | Status | Evidence |
|---|---|---|
| Notch blends into idle shell | ✅ | `NotchShape` + `safeAreaInsets` geometry |
| Hover response / natural expansion / natural closing | ✅ | Spring choreography + grace timers in `LazyNotchWindowController` |
| No focus stealing | ✅ | Non-activating panel, `ignoresMouseEvents` toggling |
| Notchless mode | ❌ | Closed hot zone is `200 × 0` px — hover can never engage (F-03) |
| External display | 🟡 | Works when it is the primary display; no per-display anchoring |
| Multi-monitor | 🟡 | Single shell anchored to one display (F-12) |

### Navigation — 1/6
| Item | Status | Evidence |
|---|---|---|
| Swipe / Scroll / Boundary resistance | ❌ | No gesture recognizers; only 2 tabs, tab buttons only |
| Mouse | ✅ | Hover + click throughout |
| Trackpad | 🟡 | Hover works; no swipe gestures |
| Keyboard fallback | 🟡 | ESC closes Mirror/Settings panels only; nothing else (F-01) |

### LazyShelf — 6/6 (1 qualified)
Drag activation ✅ · Multi-file drop ✅ · Persistence ✅ (UserDefaults path list) · Preview 🟡 (QuickLook, **single item only**, F-10) · Drag-out ✅ · Removal ✅ (context menu + Clear Shelf)

### Widgets — 4/9
Media ✅ (no seek, F-10) · Calendar ✅ · Mirror ✅ · Live activities ✅ (compact strip with vinyl art + waveform) · HUD 🟡 (drop HUD only; no system-event HUDs) · **Timer / Notes / Todos / Shortcuts ❌** (planned in `02-feature-matrix.md`, no code)

### Visual — 7/8
Geometry ✅ · Spacing ✅ · Typography ✅ · Material 🟡 (flat black shell; `NSVisualEffectView` used only in Settings) · Control density ✅ · Animation timing ✅ · Gesture thresholds ✅ · Original assets ✅ (per clean-room doc)

### Reliability — 8/10
Permission denial ✅ · Revocation 🟡 (60 s re-check timers) · Display hot-plug ✅ · Full-screen ✅ · Space changes ✅ · Media source changes ✅ (distributed notifications) · Calendar failure ✅ · Camera failure ✅ · Shelf persistence ✅ · **Sleep/wake ❌** (no `NSWorkspace` sleep/wake observers anywhere, F-08)

### Accessibility — 0/6
VoiceOver ❌ · keyboard focus ❌ · reduced motion ❌ · reduced transparency ❌ · contrast ❌ (secondary text at 0.42–0.6 opacity fails WCAG AA at caption sizes) · hit targets 🟡 (26 px icon buttons). **Zero accessibility API usage in the entire codebase** (verified grep, F-01).

### Release — 2/6
Dependency notices ✅ (no third-party deps) · Clean-room register ✅ (`14-clean-room.md`) · Signing 🟡 (hardened-runtime dev script only) · Notarization ❌ · Update mechanism ❌ · Privacy documentation 🟡 (Info.plist usage strings; no privacy policy)

**Aggregate: 39 ✅ / 13 🟡 / 13 ❌ across 65 graded rows.**

---

## 4. Findings Register

Severity: **P0** = blocks 1.0 · **P1** = user-visible defect · **P2** = quality/consistency · **P3** = hygiene.

| # | Sev | Finding | Evidence |
|---|---|---|---|
| F-01 | **P0** | **Accessibility absent.** No `accessibilityLabel/Element/Traits`, no Reduced Motion/Transparency handling, no keyboard focus model, icon-only buttons with no labels. VoiceOver cannot operate the shell (non-activating borderless panel + zero a11y tree). | Grep over all 24 files: 0 matches |
| F-02 | **P0** | **No quit path, no menu-bar presence.** Accessory app with no `NSStatusItem`, no main menu, no Quit anywhere. Users must `kill` the process. | Grep: 0 `NSStatusItem`; `AppDelegate`/`main.swift` |
| F-03 | **P1** | **Notchless Macs get a dead shell.** Closed hot zone computes to `200 × 0`; zero-height rect can never contain the cursor, so hover expansion is impossible. Only global drag-in works. | `LazyNotchWindowController` closed-size path |
| F-04 | **P1** | **Hover-grace default mismatch.** Settings slider defaults to **0.15 s** (`@AppStorage`), but the poll loop's fallback when the key is unset is **0.22 s**. Effective behavior differs from displayed default until the user touches the slider. | `SettingsSheet.swift` vs `LazyNotchWindowController.hoverLeaveGrace` |
| F-05 | **P2** | **CHANGELOG drift.** CHANGELOG documents open spring 0.38/0.70, close 0.28/0.84, open size 598×164; code ships symmetric 0.40/0.72 springs and 620×180. | `CHANGELOG.md` vs `LazyNotchMotion.swift`, `ShellContentView` |
| F-06 | **P2** | **Version string drift.** Settings About says "Version 1.0.0 · Production Suite"; CHANGELOG and roadmap say 0.1.0. | `SettingsSheet.swift` About tab |
| F-07 | **P3** | **Dead code: `ShellState.swift`** (4-state enum closed/opening/open/closing) is defined but never referenced — the real state machine is `ShellViewModel.isExpanded: Bool`. The documented architecture and the code disagree. | Grep: only the definition matches |
| F-08 | **P1** | **No sleep/wake handling.** No `NSWorkspace` sleep/wake observers; camera session and media polling are not suspended/resumed across lid events. | Grep: 0 matches |
| F-09 | **P2** | **Always-on 60 Hz cursor polling.** A 0.016 s `Timer` runs for the app's lifetime regardless of hover state — measurable battery/energy cost; QA target says "no wasteful polling". A `CGEventTap`/tracking-area approach would be event-driven. | `LazyNotchWindowController` poll loop |
| F-10 | **P2** | **Feature gaps inside shipped widgets:** media seek not implemented (QA checklist lists it); QuickLook previews a single item only even for multi-file shelf drops. | `MediaService.swift`, `LazyShelfStore.swift` |
| F-11 | **P2** | **Global drag detection is heuristic** (`NSPasteboard(.drag).changeCount` + pressed buttons). It already produced one false-trigger fix (commit `a36aa15`); remains fragile to non-drag pasteboard writes. | `LazyNotchWindowController` |
| F-12 | **P2** | **Single-display shell.** `primaryDisplay` picks the first notch display (or first screen); one panel only. Secondary displays get nothing. | `DisplayCoordinator.swift` |
| F-13 | **P1** | **Motion/transparency settings ignored.** Springs, `repeatForever` pulses, and the waveform animate unconditionally; no Reduced Motion / Reduced Transparency branch anywhere. (Subset of F-01, tracked separately because it also affects non-VoiceOver users.) | `ShellContentView.swift`, `LazyNotchMotion.swift` |
| F-14 | **P2** | **Release engineering absent:** no notarization, no updater (Sparkle or otherwise), signing limited to the dev `build_run.sh` hardened-runtime path. | repo root, `.github/workflows/ci.yml` |
| F-15 | **P3** | **README over-claims:** "120 Hz ProMotion, zero WindowServer IPC" — actual cursor tracking is a 60 Hz timer; render rate is display-dependent; "zero IPC" is aspirational. | `README.md` vs poll loop |
| F-16 | **P1** | **No automated tests.** No `Tests/` target; CI (`.github/workflows/ci.yml`, macos-15 / Xcode 16) builds debug+release only. Regressions in geometry/hover logic have no safety net. | `Package.swift`, `ci.yml` |

### Dead code (secondary)
`MirrorPreviewView.swift` (134 LOC, incl. `CameraPreviewNSView`) is never referenced — `HandMirrorView` embeds its own inline preview. Remove or wire in.



---

## 5. Remediation Roadmap

### P0 — Ship-blockers (est. 2–3 days)
1. **Menu-bar icon + lifecycle menu** (F-02): `NSStatusItem` with Open Settings / Toggle Live Activity / Quit. Also gives a non-hover entry point.
2. **Accessibility pass** (F-01, F-13): labels on all interactive controls; expose shell state to the a11y tree; honor `accessibilityReduceMotion` (swap springs for fades, kill pulses/waveform) and `accessibilityReduceTransparency`; raise secondary-text opacity or bump weights to meet AA.

### P1 — User-visible defects (est. 1–2 days)
3. **Notchless fallback geometry** (F-03): synthesize a ≥1 px-tall hover band and a faux-notch closed frame when `safeAreaInsets.top == 0`.
4. **Unify hover-grace defaults** (F-04): single source of truth constant; register it in `UserDefaults.register(defaults:)`.
5. **Sleep/wake observers** (F-08): suspend/resume camera session + media polling on `willSleepNotification` / `didWakeNotification`.
6. **Test target + CI test step** (F-16): at minimum unit-test `DisplayCoordinator` geometry math and `ShellViewModel` transitions — the two highest-risk pure-logic areas.

### P2 — Consistency & robustness (est. 1–2 days)
7. Fix CHANGELOG/About drift (F-05, F-06) and README claims (F-15).
8. Event-driven cursor tracking or adaptive poll rate (F-09); harden drag heuristic with a verification grace window (F-11).
9. Media seek control; multi-item QuickLook (F-10).
10. Multi-display shells (F-12); release pipeline: Developer ID signing, notarization, Sparkle (F-14).

### P3 — Hygiene (< 1 hour)
11. Delete `ShellState.swift` and `MirrorPreviewView.swift` (or wire them into the architecture docs and code respectively).

---

## 6. Verification Appendix

- **Build:** `swift build -c debug` — **success, 13.75 s** on macOS (arm64), Swift 6 toolchain. Reproduces CI's debug leg; CI additionally builds `-c release` on `macos-15` / Xcode 16.
- **Evidence greps (scoped to `Sources/`, `.build` excluded):**
  - `ShellState` → definition only, zero usages → F-07 confirmed.
  - `MirrorPreviewView|CameraPreviewNSView` → zero usages outside its own file → dead code confirmed.
  - `accessibilityLabel|accessibilityElement|accessibilityTraits|accessibilityReduceMotion|accessibilityReduceTransparency|NSStatusItem|NSWorkspace.shared.(sleep|didWake)` → **0 matches across all 24 files** → F-01, F-02, F-08, F-13 confirmed.
- **Line counts:** `find Sources -name '*.swift' | wc -l` → 4,987 total; largest file 760 LOC.
- **Limitations:** single-machine build (no multi-display or notchless hardware exercised); no runtime/Instruments profiling performed; asset originality taken from the clean-room register, not re-audited.
