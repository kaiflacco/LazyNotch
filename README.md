<div align="center">

<img src="docs/design/lazynotch-banner.png" alt="LazyNotch Banner" width="600"/>

# LazyNotch

**A premium macOS notch utility that transforms your MacBook's notch into an intelligent, always-available control center.**

[![Platform](https://img.shields.io/badge/platform-macOS%2014.6%2B-black?logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange?logo=swift&logoColor=white)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen)](CONTRIBUTING.md)

</div>

---

## ✨ What is LazyNotch?

LazyNotch is a **native macOS menu bar utility** that gives your MacBook's physical notch a second life. Built entirely in **Swift + SwiftUI**, it renders directly on the GPU at up to **120 Hz ProMotion** with zero WindowServer IPC overhead, so it never stutters or lags behind your cursor.

The notch morphs between three states — **idle**, **compact live-activity pill**, and **full expanded island** — with spring physics that match the feel of iOS Dynamic Island.

---

## 🎬 Features

| Feature | Description |
|---|---|
| **🎵 Live Media Control** | Album art, track info, and playback controls for Spotify & Apple Music — shown in the compact pill when music is playing |
| **📅 Calendar Glance** | 7-day week strip with event indicators and a schedule glance card, powered by EventKit |
| **🗂 Lazy Shelf** | A temporary file tray — drag files in, stage them, then drag out into any app; supports QuickLook preview & AirDrop |
| **📷 Hand Mirror** | Instant camera preview window — one click, no app switch |
| **⚡ Global Drop Zone** | Drag any file from Finder directly onto the notch to route it to the Tray or AirDrop |
| **🌊 Organic Spring Physics** | Custom NotchShape morphing + tuned spring constants that match NotchNook / Dynamic Island feel |
| **🖥 Multi-display Aware** | Automatically anchors to the notch display; adapts instantly to resolution changes & display hotplug |
| **🔒 Permission-Stable Code Identity** | Uses a stable bundle identifier for codesigning so TCC grants (Camera, Calendar, Apple Events) survive every rebuild |

---

## 📸 Screenshots

<table>
  <tr>
    <td><img src="docs/design/screenshot-expanded.png" alt="Expanded Island" width="350"/></td>
    <td><img src="docs/design/screenshot-compact.png" alt="Compact Live Activity" width="350"/></td>
  </tr>
  <tr>
    <td align="center"><b>Expanded island</b> with media, mirror, and calendar widgets</td>
    <td align="center"><b>Compact live-activity pill</b> while music is playing</td>
  </tr>
</table>

---

## 🏗 Architecture

```
Sources/
├── main.swift                         # App entry point
├── App/
│   └── AppDelegate.swift              # Bootstraps DisplayCoordinator + WindowController
├── Core/
│   ├── Display/DisplayCoordinator.swift   # Screen geometry, notch dimensions, display observer
│   ├── Events/                            # (Input event infrastructure, future)
│   └── Shell/ShellState.swift             # Shell open/closed state machine
├── Features/
│   ├── Calendar/CalendarService.swift     # EventKit integration
│   ├── LazyShelf/                         # File tray (model, store, view)
│   ├── Media/                             # MediaTrack model + MediaService (Spotify & Music)
│   ├── Mirror/                            # CameraManager, MirrorEffectEngine, preview views
│   └── Settings/                          # Settings sheet + window controller
└── UI/
    ├── Components/VisualEffectBlurView.swift
    ├── Motion/LazyNotchMotion.swift       # Centralized spring-physics constants
    ├── Shell/                             # Window controller, hosting view, shell SwiftUI view
    ├── Theme/LazyNotchColors.swift        # Design-token color palette
    └── Widgets/WidgetGrid.swift           # Media, Mirror, Calendar, Shelf widgets
```

**Key design decisions:**
- **`NSPanel` at `.screenSaver` level** — stays above all windows and full-screen apps on every Space without accessibility permissions.
- **Cursor poll at 60 Hz** — reliable hover detection without event taps; drives enter/leave hysteresis state machine.
- **`ignoresMouseEvents` toggling** — true Window-Server-level click-through outside the active notch region.
- **Stable codesign identity** — `identifier "com.lazynotch.app"` requirement lets TCC bind grants to the bundle ID, not a hash.

---

## 🚀 Building & Running

### Prerequisites

| Tool | Version |
|---|---|
| macOS | 14.6 Sonoma or later |
| Xcode Command Line Tools | 15.x+ |
| Swift | 6.0+ |

### Quick start

```bash
git clone https://github.com/kaiflacco/LazyNotch.git
cd LazyNotch
./build_run.sh
```

`build_run.sh` will:
1. Build a **release** binary with `swift build -c release`
2. Install it into `LazyNotch.app`
3. Codesign with your Apple Development identity (or ad-hoc as fallback)
4. Restart the app

> **First run — permissions**
> macOS will prompt for **Calendar**, **Camera**, and **Apple Events (Spotify/Music)** access.
> Grant them in **System Settings → Privacy & Security**.
> Because the app uses a stable code identity, you only need to grant these once.

### Dev / iterate loop

```bash
swift build        # debug build (faster, no codesigning)
swift run          # run directly (ad-hoc signature, permissions reset per build)
```

For a faster iteration cycle when working on UI only (no TCC-sensitive features), `swift run` is fine. Use `./build_run.sh` when you need stable Camera/Calendar grants.

---

## 📖 Documentation

| Document | Purpose |
|---|---|
| [`docs/product/00-README.md`](docs/product/00-README.md) | Project overview & quick start |
| [`docs/product/01-product-spec.md`](docs/product/01-product-spec.md) | Core requirements & target audience |
| [`docs/product/02-feature-matrix.md`](docs/product/02-feature-matrix.md) | Feature breakdown & priorities |
| [`docs/design/03-ui-spec.md`](docs/design/03-ui-spec.md) | UI/UX specifications & layout |
| [`docs/design/05-design-tokens.md`](docs/design/05-design-tokens.md) | Design-system tokens |
| [`docs/design/07-animation-spec.md`](docs/design/07-animation-spec.md) | Spring physics & animation spec |
| [`docs/engineering/08-architecture.md`](docs/engineering/08-architecture.md) | Technical architecture |
| [`docs/engineering/09-permissions-platform.md`](docs/engineering/09-permissions-platform.md) | macOS permissions guide |
| [`docs/engineering/11-implementation-plan.md`](docs/engineering/11-implementation-plan.md) | Engineering execution plan |

---

## 🛣 Roadmap

- [ ] **v0.2** — Settings persistence with `UserDefaults` + iCloud sync
- [ ] **v0.3** — Notification / Focus indicator in the compact pill
- [ ] **v0.4** — Plugin API for third-party widgets
- [ ] **v1.0** — App Store submission + notarization pipeline

---

## 🤝 Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a PR.

```bash
# 1. Fork & clone
git clone https://github.com/<your-handle>/LazyNotch.git

# 2. Create a feature branch
git checkout -b feature/my-awesome-widget

# 3. Build and test
swift build

# 4. Commit with conventional commits
git commit -m "feat(widgets): add battery indicator widget"

# 5. Open a PR against main
```

---

## 📄 License

LazyNotch is released under the **MIT License**. See [LICENSE](LICENSE) for details.

---

<div align="center">
  Made with ❤️ and SwiftUI · <a href="https://github.com/kaiflacco">@kaiflacco</a>
</div>
