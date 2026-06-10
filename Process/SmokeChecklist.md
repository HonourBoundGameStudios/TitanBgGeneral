# Smoke Checklist — manual in-game verification

> The WoW client is the test runner. After any change, run the rows touching the
> changed surface; before any CurseForge release, run **all** rows on Classic Era
> (and ideally retail). Enable error display first: `/console scriptErrors 1`.
>
> Every new feature adds a row here before it ships. Every bug fix adds its
> reproduction step here so it can't regress silently.

## Load & lifecycle

| # | Step | Expected |
|---|---|---|
| L1 | Fresh login with addon enabled | No Lua errors; Titan bar shows the BG General button |
| L2 | `/reload` | No Lua errors; button still present |
| L3 | `/reload` with the BG General window open | No Lua errors; no duplicate window on reopen |
| L4 | Hover the Titan button | Tooltip renders with usage text |

## Main window

| # | Step | Expected |
|---|---|---|
| W1 | Left-click the Titan button | BgGeneral window opens; second click closes it |
| W2 | Drag the window by its title bar, `/reload` | Window reopens at the dragged position (SavedVariables) |
| W3 | Click the **AB** tab | 5-column AB grid shows (ST, GM, BS, LM, FM), centered; other grids hidden |
| W4 | Click the **WSG** tab | WSG grid shows, centered; other grids hidden |
| W5 | Click the **AV** tab | 7-column AV grid shows (DB, IW, SH, SF, TP, IB, FW) with icons rendering (no green squares); other grids hidden |
| W6 | Window width | Fits the 7-column AV grid; three tabs share the row evenly |
| W7 | Open the window while standing inside WSG / AB / AV | The matching tab is auto-selected (map-ID lookup, works on any client locale); outside a BG the AB default shows |
| W8 | Enter a BG with auto-open enabled (default) | Window opens itself on the right tab; leaving the BG closes it. With auto-open unchecked, the window is left alone in both directions |

## Callouts

| # | Step | Expected |
|---|---|---|
| C1 | Click an AB grid button (solo, no group) | Message sent to SAY (hardware-event click, so allowed) |
| C2 | Click a grid button while in a party | Message goes to PARTY |
| C3 | Click a grid button inside a battleground | Message goes to INSTANCE_CHAT |
| C4 | Shift/Ctrl/Alt + click a grid cell | Alternate callout variant sent |
| C5 | Click an AV grid button (e.g. INC × IB) | "INC Iceblood" sent to the right channel; tooltip shows all four variants |

## Titan integration

| # | Step | Expected |
|---|---|---|
| T1 | Right-click the Titan button | Context menu: Toggle Icon, Toggle Right Side, Hide |
| T2 | Toggle Icon / Right Side from the menu | Button redraws immediately, setting persists across `/reload` |
| T3 | Hide via the menu, re-enable from Titan's plugin list | Plugin returns without error |
| T4 | Right-click menu → "Auto-open in battlegrounds" | Renders as a checkbox (checked by default); toggling it persists across `/reload` |
| T5 | Titan bar text | Outside a BG: icon only, no text. Inside WSG/AB/AV: the BG abbreviation shows in green next to the icon |
