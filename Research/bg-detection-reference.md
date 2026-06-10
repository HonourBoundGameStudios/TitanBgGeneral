# Battleground Detection per Flavor — Reference

**Date:** 2026-06-09
**Author:** Claude (in-game verification: Richard, pending)
**Status:** Draft (Final once the `/dump` verification steps below are done)
**Confidence:** Medium overall — High for the Classic-era IDs (489/529/30), Medium for retail AB variants (2107/2177), Low for retail WSG remaster (2106) and Korrak's (2197) until verified in-game
**Flavors verified:** none in-game yet (documented from wiki primary table + current codebase)

---

## Executive Summary

Detect the active battleground with two ancient, all-flavor APIs — no `C_PvP`,
no localized zone names:

```lua
local inInstance, instanceType = IsInInstance()
if inInstance and instanceType == "pvp" then
    local _, _, _, _, _, _, _, instanceMapID = GetInstanceInfo()
    -- look up instanceMapID in the table below
end
```

Hook it on `PLAYER_ENTERING_WORLD`. This replaces the current locale-fragile
`GetZoneText()` "contains Warsong" check and unblocks **[AWARE-2]** (auto
tab-select for WSG/AB/AV) and **[AWARE-3]** (auto-open).

## Research Question

How does the addon reliably know "we are in WSG / AB / AV" on retail 11.x,
Cataclysm Classic 4.x, and Classic Era 1.x — locale-independently, and at what
moment (event) is that information available?

## Constraints

- Must work identically on all three `.toc` flavors, or degrade gracefully
- Must be locale-independent (the addon may be used on non-English clients)
- Prefer APIs that exist on every flavor over per-flavor guards

## Findings

### F1 — Instance map IDs (the locale-independent key)

`GetInstanceInfo()`'s **8th return** (`instanceMapID`) identifies the
battleground numerically:

| BG | instanceMapID | Flavors | Confidence |
|---|---|---|---|
| Warsong Gulch (classic map) | **489** | Classic Era, Cata Classic; wiki lists it as "Classic Warsong Gulch" | High (wiki primary table) |
| Warsong Gulch (retail remaster, 8.1.5) | **2106** | Retail | **Low — not on the wiki table consulted; verify with `/dump` on retail** |
| Arathi Basin (classic map) | **529** | Classic Era, Cata Classic ("Classic Arathi Basin") | High (wiki primary table) |
| Arathi Basin (retail remaster) | **2107** | Retail | Medium (wiki primary table; not yet verified in-game) |
| Arathi Basin Comp Stomp (brawl) | **2177** | Retail | Medium (wiki primary table) |
| Alterac Valley | **30** | All three flavors | High (wiki primary table; same ID since vanilla) |
| Korrak's Revenge (anniversary AV brawl) | **2197** | Retail (event-only) | **Low — not on the wiki table consulted; verify if/when the event runs** |

Because unknown IDs simply fail the lookup, mapping *both* the classic and
remaster IDs to the same logical BG is safe on every flavor.

### F2 — `IsInInstance()` instanceType

`IsInInstance()` returns `instanceType == "pvp"` in any battleground, on all
three flavors. The codebase already relies on this in `GetChatType()`
(`TitanBgGeneral.lua:109-120`) — it is the cheap pre-filter before reading the
map ID.

### F3 — The event to hook

`PLAYER_ENTERING_WORLD` fires after every loading screen (login, `/reload`,
zoning into/out of an instance) and `GetInstanceInfo()` is valid by then. Its
two args (`isInitialLogin`, `isReloadingUi`) are both `false` on a genuine
zone transfer — battleground entry is the `false, false` case (but reacting on
all three is harmless and simpler). `ZONE_CHANGED_NEW_AREA` also fires around
zoning but is noisier (fires on sub-zone-area changes in the open world) and
adds nothing here.

### F4 — `C_PvP` is not needed

Retail offers `C_PvP.IsBattleground()`, but its availability/shape differs on
Classic flavors. Since F1+F2 cover the need with APIs that predate the flavor
split, the recommendation avoids `C_PvP` entirely — no guard required.

### F5 — The current detection is locale-fragile

Today the WSG tab is auto-selected by checking whether the zone name contains
"Warsong" — this breaks on any non-English client (e.g. "Kriegshymnenschlucht"
on deDE). The map-ID lookup replaces it.

## Evidence

- Wiki `InstanceID` table (battlegrounds section): `489` "Classic Warsong
  Gulch", `529` "Classic Arathi Basin", `2107` "Arathi Basin", `2177` "Arathi
  Basin Comp Stomp", `30` "Alterac Valley". `2106` and `2197` were **not**
  present in the table consulted — hence their Low confidence.
- `TitanBgGeneral.lua:109-120` — existing `IsInInstance()` usage proves F2 in
  this codebase on Classic Era.

## Analysis & Recommendation

Add one constant table and one helper, called from a `PLAYER_ENTERING_WORLD`
handler:

```lua
local BG_BY_MAP_ID = {
    [489]  = "WSG", [2106] = "WSG",
    [529]  = "AB",  [2107] = "AB",  [2177] = "AB",
    [30]   = "AV",  [2197] = "AV",
}

-- Returns "WSG" | "AB" | "AV" | nil
local function GetActiveBg()
    local inInstance, instanceType = IsInInstance()
    if not (inInstance and instanceType == "pvp") then return nil end
    local _, _, _, _, _, _, _, instanceMapID = GetInstanceInfo()
    return BG_BY_MAP_ID[instanceMapID]
end
```

`GetActiveBg()` becomes the single source of truth for AWARE-2 (tab select),
AWARE-3 (auto-open), AWARE-4 (Titan button text), and later the advisor epics.
Unknown battlegrounds (EotS, future maps) return `nil` and the addon behaves
exactly as it does today.

## Risks

- **2106/2197 unverified** — if wrong, retail WSG simply won't auto-detect
  (graceful, not an error). Fix is a one-line table edit after `/dump`.
- Brawl variants of AB/AV may have different node layouts than the grids
  assume (Comp Stomp is still standard AB; Korrak's is classic AV — low risk).

## Action Items — in-game verification (Richard)

Run `/dump GetInstanceInfo()` (or `/dump select(8, GetInstanceInfo())`) inside:

- [ ] WSG on **Classic Era** — expect `489`
- [ ] AB on **Classic Era** — expect `529`
- [ ] AV on **Classic Era** — expect `30`
- [ ] WSG on **retail** — confirm `2106` (the Low-confidence entry)
- [ ] AB on **retail** — confirm `2107`

When done: correct the table if needed, set **Status: Final**, update
**Flavors verified**, and bump the row in `CLAUDE.md`.

## Sources

- https://warcraft.wiki.gg/wiki/InstanceID — battleground ID table (primary for 489/529/30/2107/2177)
- https://warcraft.wiki.gg/wiki/API_GetInstanceInfo — return signature
- https://warcraft.wiki.gg/wiki/API_IsInInstance — instanceType values
- https://warcraft.wiki.gg/wiki/PLAYER_ENTERING_WORLD — event args/timing
- `TitanBgGeneral.lua:109-120` — existing `IsInInstance()` usage (this repo)
