# Agent Status Bar — Design System

**Aesthetic:** Quiet luxury / Apple Continuity. Calm, dense, precise. Tiny orbs, SF text, no clutter.

**Mental model:** **iPhone Dynamic Island.** A **horizontal** capsule parks in the **center MacBook notch / camera**. On invoke it **expands sideways** (and slightly down) into a **landscape** bar — never a tall vertical dropdown, never a top-trailing menu-bar card.

## Placement

| State | Behavior |
|-------|----------|
| Collapsed | Short **horizontal pill** in the **center notch** (~120 × 28 pt) with a row of status orbs |
| Expanded | **Wider horizontal bar** (~300–360 × 56–80 pt) grows from notch **center** — scale anchor **topCenter** |

### Implementation note (macOS reality)

`MenuBarExtra` can only live in the **trailing** status-item cluster — it cannot sit in the physical notch. True center-notch UX needs a **borderless always-on-top `NSPanel`** positioned at screen **top-center**, ideally under `safeAreaInsets.top` / the menubar strip where the camera lives.

This app’s primary path is that floating top-center `NSPanel`. A minimal MenuBarExtra remains only as a launch / Accessibility fallback — **not** the visual home.

## Size budget

| Token | Value | Use |
|-------|-------|-----|
| Collapsed pill | **~120 × 28 pt** capsule | Horizontal orb row under notch |
| Expanded island | **~340 × 68 pt** (width 300–360, height 56–80) | Landscape bar |
| Corner radius | Capsule (collapsed) / 22 pt continuous (expanded) | Island continuity |
| Inner padding | 8–10 pt horizontal, 6–8 pt vertical | Dense, quiet |
| Agent cell | ~78 × 48 pt | Orb + name + host chip |
| Layout | **HStack** of cells (or 2×2 LazyVGrid if >4) | Inside the bar — **not** a vertical list |
| Orb | 5–6 pt | Status |
| Name | SF Pro 10–11 medium | One word |
| Host / evidence | SF Pro 8–9 secondary | Tiny chip or one short line |
| Material | Near-black capsule / ultra-thin when expanded | Island continuity |

### Status colors

| Status | Hex | Motion |
|--------|-----|--------|
| running | `#30D158` | Breathe 1.6s |
| idle | `#FFD60A` | Static |
| stale | `#FF9F0A` | Static |
| offline | `#636366` | Static, muted |
| unknown | `#8E8E93` | Static |

## Motion

- **Expand:** bloom from **notch center** — width 120→340, height 28→68, `scale` anchor **top** (UnitPoint top / topCenter), spring ~0.34s, damping ~0.86. Grows **sideways first**, slight downward settle.
- **Collapse:** reverse into the center pill.
- **Running orbs:** opacity breathe only.

## Non-goals

- Tall vertical dropdown / list panels
- Top-trailing menu-bar cards
- NL blurbs, charts, neon, heavy chrome
