# LazyNotch — Product & Engineering Specification

**Status:** Research baseline  
**Product:** LazyNotch  
**Reference product studied:** NotchNook  
**Research date:** 2026-09-20  
**Target platform:** macOS 14.6+

## Product definition

LazyNotch is an independent macOS utility that uses the area around the MacBook camera notch as a compact, expandable command surface for widgets, live activities, media, files, and quick utilities.

LazyNotch is a **rebrand and independent implementation**, not an official NotchNook product.

The goal is to reproduce the reference product's observable interaction patterns and utility model as closely as practical while using LazyNotch's own implementation, assets, branding, and product language.

## Reference baseline

The current official NotchNook product page publicly describes:

- v1.6.2
- macOS 14.6+
- widgets
- live actions
- files shelf
- scrolling/swiping
- notchless-screen support
- multiple monitors
- extensive customization

Source: https://lo.cafe/notchnook

## Clean-room principle

Use the reference product to understand observable behavior, not to copy:

- source code
- proprietary assets
- branding
- logo
- binary resources
- unpublished implementation details

All LazyNotch code and visual assets should be independently created.

## Parity definition

Parity is evaluated in this order:

1. Interaction outcome
2. Information hierarchy
3. Spatial behavior
4. State model
5. Animation character
6. Gesture/control affordances
7. Visual density
8. Typography/material treatment
9. Original LazyNotch branding/assets

"Pixel identical" is not assumed because hardware, macOS versions, display scaling, fonts, and system materials vary.

## Documentation map

- `01-product-spec.md` — product contract
- `02-feature-matrix.md` — feature parity matrix
- `03-ui-spec.md` — visual/UI specification
- `04-ux-flows.md` — interaction flows
- `05-design-tokens.md` — design system
- `06-components.md` — component contracts
- `07-animation-spec.md` — motion specification
- `08-architecture.md` — macOS architecture
- `09-permissions-platform.md` — platform requirements
- `10-qa-parity.md` — QA/parity plan
- `11-implementation-plan.md` — implementation roadmap
- `12-research-sources.md` — research register
- `13-branding.md` — LazyNotch identity
- `14-clean-room.md` — clean-room/IP guardrails
- `15-parity-checklist.md` — final checklist
