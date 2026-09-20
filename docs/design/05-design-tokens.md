# LazyNotch — Design Tokens

These are initial clean-room implementation tokens. They must be calibrated against LazyNotch reference captures.

## Semantic colors

```yaml
surface:
  closed: "#000000"
  panel: "#0B0B0D"
  elevated: "#151518"
  elevated2: "#1D1D21"

text:
  primary: "#F5F5F7"
  secondary: "#A1A1A6"
  tertiary: "#6F6F75"
  disabled: "#55555B"

border:
  subtle: "#FFFFFF14"
  interactive: "#FFFFFF22"

state:
  success: "#30D158"
  warning: "#FFD60A"
  danger: "#FF453A"
  info: "#0A84FF"
```

## Spacing

```yaml
1: 2
2: 4
3: 6
4: 8
5: 10
6: 12
7: 16
8: 20
9: 24
10: 32
```

## Radius

```yaml
small: 8
medium: 12
large: 16
shell: 24
pill: 999
```

Shell radius should ultimately derive from display/notch geometry.

## Motion starting values

```yaml
hoverResponse: 0.12
contentFade: 0.16
pageSnap: 0.28
shellExpansion: 0.38
springResponse: 0.70
springDamping: 0.82
```

These are starting values only.

## Material

Closed:
- nearly opaque black
- minimal visible blur

Open:
- dark material
- restrained translucency
- subtle separation from desktop

Respect macOS Reduce Transparency.
