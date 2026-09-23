# LazyNotch

LazyNotch is a native macOS utility that uses the MacBook notch as a compact, expandable surface for quick access to media, calendar, files, mirror, settings, and coding activity.

## Product language

**Shell**:
The user-facing notch surface that presents compact and expanded states and coordinates feature presentation.
_Avoid_: backend, container

**Compact pill**:
The small shell state used for the notch and live activity indicators.
_Avoid_: collapsed window

**Expanded island**:
The larger shell state that exposes feature widgets and actions.
_Avoid_: full-screen panel

**Live activity**:
A temporary compact presentation of an active media session or coding session.
_Avoid_: notification, alert

**Feature**:
A user-facing LazyNotch capability with its own state, actions, and presentation, such as Live Media Control, Calendar Glance, Lazy Shelf, Hand Mirror, Codex usage, or Settings.
_Avoid_: module, widget

**Lazy Shelf**:
The temporary local file tray where files can be staged, previewed, opened, dragged, or sent with AirDrop.
_Avoid_: Tray, file manager

**Hand Mirror**:
The camera-preview feature for viewing and adjusting the user’s camera feed without switching applications.
_Avoid_: camera utility

**Codex usage**:
The coding-session activity that presents remaining usage and the active coding host when available.
_Avoid_: AI backend, quota service

## Architecture language

**Runtime**:
The app-scoped composition and lifecycle boundary that assembles features and integrations for the running application.
_Avoid_: service locator, global container

**Integration**:
A boundary around a system framework, external process, network request, permission, or other effect outside feature state.
_Avoid_: backend, helper

**In-process backend**:
The local service and integration layer that owns feature state, persistence, permissions, and external effects without a remote server.
_Avoid_: API server, cloud backend

**Local-first**:
A product property in which LazyNotch’s supported behavior and data remain usable locally without cloud sync, accounts, or a remote database.
_Avoid_: offline mode

**Layout contract**:
The agreed visual rules for shell geometry, alignment, spacing, text fitting, image sizing, hit regions, and state transitions.
_Avoid_: design system, pixel polish

**LazyNotch visual language**:
The existing Apple-inspired visual language expressed by the current app: dark/translucent materials, rounded geometry, typography, motion, hierarchy, and established component vocabulary.
_Avoid_: redesign, replacement theme

**Supported**:
Behavior intentionally preserved and covered by an acceptance or verification check.
_Avoid_: currently present

**Unused**:
An artifact with no required source, build, resource, supported-feature, or documentation role, or one explicitly ruled out by a project decision.
_Avoid_: old, dead (unless the evidence is explicit)
