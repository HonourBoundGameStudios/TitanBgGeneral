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
| W3 | Click the **AB** tab | 5-column AB grid shows (ST, GM, BS, LM, FM); WSG grid hidden |
| W4 | Click the **WSG** tab | WSG grid shows; AB grid hidden |

## Callouts

| # | Step | Expected |
|---|---|---|
| C1 | Click an AB grid button (solo, no group) | Message sent to SAY (hardware-event click, so allowed) |
| C2 | Click a grid button while in a party | Message goes to PARTY |
| C3 | Click a grid button inside a battleground | Message goes to INSTANCE_CHAT |
| C4 | Shift/Ctrl/Alt + click a grid cell | Alternate callout variant sent |

## Titan integration

| # | Step | Expected |
|---|---|---|
| T1 | Right-click the Titan button | Context menu: Toggle Icon, Toggle Right Side, Hide |
| T2 | Toggle Icon / Right Side from the menu | Button redraws immediately, setting persists across `/reload` |
| T3 | Hide via the menu, re-enable from Titan's plugin list | Plugin returns without error |
