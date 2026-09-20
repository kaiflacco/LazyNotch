# Contributing to LazyNotch

Thank you for your interest in contributing! This guide covers everything you need to get started.

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Commit Convention](#commit-convention)
- [Pull Request Guidelines](#pull-request-guidelines)
- [Project Structure](#project-structure)
- [Coding Standards](#coding-standards)
- [Reporting Bugs](#reporting-bugs)
- [Feature Requests](#feature-requests)

---

## Code of Conduct

Be respectful, constructive, and inclusive. We're all here to build great software.

---

## Getting Started

### Prerequisites

- macOS 14.6 (Sonoma) or later
- Xcode 15+ with Swift 6.0 command-line tools
- A MacBook with a physical notch (for full testing)

### Setup

```bash
# 1. Fork this repository on GitHub, then clone your fork
git clone https://github.com/<your-handle>/LazyNotch.git
cd LazyNotch

# 2. Add the upstream remote
git remote add upstream https://github.com/kaiflacco/LazyNotch.git

# 3. Build and run
./build_run.sh
```

---

## Development Workflow

```bash
# Keep your fork up to date
git fetch upstream
git rebase upstream/main

# Create a feature branch from main
git checkout -b feature/my-widget        # new feature
git checkout -b fix/hover-glitch         # bug fix
git checkout -b docs/update-readme       # documentation

# Fast iteration (debug build, no stable codesigning)
swift build && swift run

# Before opening a PR — test the release build with stable codesigning
./build_run.sh
```

---

## Commit Convention

LazyNotch follows **Conventional Commits**:

```
<type>(<scope>): <short summary>

[optional body]

[optional footer(s)]
```

### Types

| Type | Use for |
|---|---|
| `feat` | New feature |
| `fix` | Bug fix |
| `refactor` | Code change that is neither a feature nor a fix |
| `perf` | Performance improvement |
| `docs` | Documentation changes |
| `style` | Formatting, missing semicolons, etc. (no logic change) |
| `test` | Adding or fixing tests |
| `chore` | Build system, CI, tooling |

### Scopes (optional but encouraged)

`shell`, `widgets`, `media`, `calendar`, `shelf`, `mirror`, `motion`, `theme`, `display`, `settings`

### Examples

```
feat(shelf): add drag-out support to StagedItemCard
fix(media): handle missing artwork URL gracefully
perf(shell): reduce cursor poll frequency when island is collapsed
docs: add architecture section to README
```

---

## Pull Request Guidelines

1. **Target `main`** — all PRs should be opened against `main`.
2. **One concern per PR** — keep PRs focused; large multi-feature PRs are hard to review.
3. **Fill out the PR template** — describe what the change does and why.
4. **Link related issues** — use `Fixes #123` or `Closes #123` in the PR description.
5. **Test on hardware** — if the change touches the notch UI, please test on a notched MacBook.
6. **No force-push to shared branches** — rebase your branch privately, then push.

---

## Project Structure

```
Sources/
├── App/            # AppDelegate — app bootstrap only
├── Core/
│   ├── Display/    # Screen geometry, notch detection
│   ├── Events/     # (Future) Input event infrastructure
│   └── Shell/      # Shell open/closed state machine
├── Features/
│   ├── Calendar/   # EventKit service
│   ├── LazyShelf/  # File tray (model, store, view)
│   ├── Media/      # MediaTrack + MediaService (Spotify & Music)
│   ├── Mirror/     # Camera capture + effect engine
│   └── Settings/   # Settings sheet + window controller
└── UI/
    ├── Components/ # Shared, reusable AppKit/SwiftUI components
    ├── Motion/     # Spring-physics constants (LazyNotchMotion)
    ├── Shell/      # NSPanel + SwiftUI shell view + window controller
    ├── Theme/      # Design-token colors (LazyNotchColors)
    └── Widgets/    # Media, Mirror, Calendar, Shelf widget views
```

---

## Coding Standards

- **Swift 6.0 strict concurrency** — all code must compile with the default isolation settings; no `@preconcurrency` workarounds without discussion.
- **`@MainActor` everywhere UI** — all UI types must be `@MainActor` isolated.
- **Background work via `Task.detached`** — never block the main thread.
- **Design tokens** — use `LazyNotchColors` and `LazyNotchMotion` constants; avoid hard-coded hex values or magic numbers in view files.
- **No third-party dependencies** — LazyNotch has zero SPM dependencies by design; keep it that way unless there's a compelling reason.
- **MARK comments** — use `// MARK: - Section Name` to structure files.

---

## Reporting Bugs

Open a [GitHub Issue](https://github.com/kaiflacco/LazyNotch/issues/new) with:

- macOS version
- MacBook model (notch size matters!)
- Steps to reproduce
- Expected vs. actual behaviour
- Console log output if relevant (`Console.app` → filter by `LazyNotch`)

---

## Feature Requests

Open a [GitHub Issue](https://github.com/kaiflacco/LazyNotch/issues/new) with the `enhancement` label. Describe:

- What problem it solves
- How it should behave
- Any reference to similar features in other apps
