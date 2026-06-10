# DBM-PvP Source Review — Reference

**Date:** 2026-06-09
**Author:** Claude (reviewing the user's installed copy)
**Status:** Final
**Confidence:** High for data DBM-PvP actively uses on Era (it ships and works on the user's client); Medium for code paths it marks "Unused"
**Flavors verified:** Classic Era indirectly (the reviewed copy runs in the user's Era client); retail/Cata paths read from its conditionals

---

Reviewed: `D:\Games\World of Warcraft\_classic_era_\Interface\AddOns\DBM-PvP`
(rev `20260207030126`, multi-flavor: Vanilla/TBC/Wrath/Cata/Mists/Mainline `.toc`s).
This catalogues only what our existing research did **not** already establish.
It upgrades `ab-node-state-research.md` and `wsg-flag-state-research.md` —
both updated to point here.

## AB — the decode data we were waiting for (was Friday's capture goal)

### uiMapIDs to pass to the POI calls (`Battlegrounds/Arathi.lua:16-27`)

| Zone (instanceMapID) | uiMapID for POI queries |
|---|---|
| Classic AB (529) | **1461** |
| Retail AB (2107) | 93 |
| AB Winter brawl (1681) | 837 |
| AB Comp Stomp (2177) | 1383 |

No `GetBestMapForUnit` needed — but it remains a sane fallback.

### The Era `textureIndex` decode table (`PvPGeneral.lua:545-616`)

On classic flavors `textureIndex` encodes **both the node and its state** —
fully locale-independent identity, better than the `areaPoiID` plan:

| Node | A-contested | A-controlled | H-contested | H-controlled |
|---|---|---|---|---|
| Gold Mine | 17 | 18 | 19 | 20 |
| Lumber Mill | 22 | 23 | 24 | 25 |
| Blacksmith | 27 | 28 | 29 | 30 |
| Farm | 32 | 33 | 34 | 35 |
| Stables | 37 | 38 | 39 | 40 |
| (AV Graveyard) | 3 | 14 | 13 | 12 |
| (AV Tower) | 8 | 10 | 11 | 9 |

(The classic GY/Tower rows use the `isClassic or isBCC` values; retail offsets
most ranges by +1 and DBM instead matches `atlasName:find("leftIcon")` =
Alliance capping / `"rightIcon"` = Horde capping on atlas-based clients.)

### Corrections to our assumptions

- **Capture time on Era is 64s, not 60s** (`capTimer = NewTimer(isRetail and 60 or 64)`, `PvPGeneral.lua:617`). AV caps: classic 304s, retail 243s (`overrideTimers`, lines 531-538).
- Retail exposes **`C_AreaPoiInfo.GetAreaPOITimeLeft(areaPOIID)`** (minutes) — real remaining time instead of a derived timer; classic falls back to the constants.
- DBM keys node state by **localized `name`** as an opaque table key (works fine for change detection); our display mapping should still use `textureIndex` per the table above.

### Score / resources (the [AB-5] inputs, answered early)

- **Classic AB score widgets: 1893 (Alliance) / 1894 (Horde)** — parse
  `"<score>/<max>"` from `C_UIWidgetManager.GetIconAndTextWidgetVisualizationInfo(id).text` (`PvPGeneral.lua:681-686`).
- Retail standard predictor: widget **1671** via `GetDoubleStatusBarWidgetVisualizationInfo` (leftBar=Alliance).
- **Classic AB resource rates** (per second, indexed by bases held 0..5):
  `{~0, 10/12, 10/9, 10/6, 10/3, 30}` (`PvPGeneral.lua:451-454`).
- **The "bases to win" algorithm** (`updateInfoFrame`, lines 474-492): for each
  possible base count, time-to-max = `(maxScore - score) / ratePerSec[bases+1]`;
  the advice is the minimum bases where our time beats theirs. This is the
  proven core of the [AB-5] advice engine — port the math, not the UI.

## WSG — pattern strings (shrinks Friday's WSG capture)

`localization.en.lua:50-59` ships the patterns we planned to capture by hand —
and DBM has **9 locale files** with translations, so multi-locale support is a
port instead of a community ask:

```lua
FlagCaptured     = "The .+ ha%w+ captured the flag!"            -- in active use (timer trigger)
ExprFlagPickUp   = "The (%w+) Flag was picked up by (.+)!"      -- marked "Unused"
ExprFlagCaptured = "(.+) captured the (%w+) Flag!"
ExprFlagReturn   = "The (%w+) Flag was returned to its base by (.+)!" -- "Unused"
FlagDropped      = "The flag has been dropped!"                 -- "Unused"
FlagTaken        = "(.+) has taken the flag!"                   -- "Unused"
```

Caveats: the `Expr*`/drop patterns are marked "Unused"/`TODO: Implement the
flag carrying system` — i.e. **untested by DBM**; verify the exact strings fire
on Era before trusting (one WSG match, watch chat). Flag respawn after capture:
**12s** (`flagTimer`, `PvPGeneral.lua:364`), matching Capping. DBM's
flag-carrier *vulnerability* timers are `isRetail`-gated (`PvPGeneral.lua:367-371`)
— reinforcing our doubt that Era WSG has the stacking debuffs ([WSG-4] question).

## General techniques worth stealing

- **Init timing hardening** (`PvPGeneral.lua:112-118` and every BG mod): zone
  detection runs on `LOADING_SCREEN_DISABLED`/`PLAYER_ENTERING_WORLD` but
  **delayed via `Schedule(1, Init)` and re-checked at 3s** — area/POI info
  isn't reliable in the same frame. If Friday shows our auto-open/tab-select
  misbehaving on first load, this is the fix.
- **BG start timing** (for [CMD-2] opening-split caller): the `START_TIMER`
  event (type 1) gives exact seconds; Era system messages have their own
  phrasing (`"2 minutes until the battle...begins."` etc.) and arrive **~1.5s
  early on Era** (comment at `PvPGeneral.lua:424`). A pre-gate "post the plan"
  moment is reliably detectable.
- **Crowd-sourced health sync** (`PvPGeneral.lua:121-357`) — classic-only
  architecture for tracking HP of units you can't always see: scan
  `target`/`raidNtarget`/`nameplateN` → broadcast `cid:hp` addon messages on
  INSTANCE_CHAT (prefix `DBM-PvP`, also *listens to Capping's prefix* for
  cross-addon data), name-hash-staggered send delays as poor-man's leader
  election, and a monotonic-update filter (accept decreases, >10% jumps, or
  resets to 100). DBM uses it for AV bosses (CID-keyed); the architecture
  ports to **enemy FC health by GUID** for [WSG-2]/[CMD-6].
- `GetBattlefieldInstanceRunTime()` (ms) — BG-relative clock for win timers.
- AV extras for the AV advisor someday: boss-pull detection via
  `CHAT_MSG_MONSTER_YELL` against known yell strings; AV boss CIDs
  11946-49/13256/13419 (`Battlegrounds/Alterac.lua`).

## Action Items

- [x] Update `ab-node-state-research.md` (uiMapID, decode table, 64s, widgets) — done with this review
- [x] Update `wsg-flag-state-research.md` (patterns available; Era-verify caveat) — done with this review
- [ ] Friday is now **verification, not discovery**: confirm one AB node flip
      matches the decode table, and confirm the WSG pickup/drop/return strings
      fire as written (the "Unused"-pattern caveat)

## Sources

- `DBM-PvP\PvPGeneral.lua` (rev 20260207030126) — decode tables :545-616, cap
  timers :617, widgets :675-686, rates :445-454, bases-to-win :474-492, health
  sync :121-357, init timing :112-118
- `DBM-PvP\Battlegrounds\Arathi.lua` — uiMapID table; `Warsong.lua` — flag subscribe; `Alterac.lua` — AV subscribe + boss tracking
- `DBM-PvP\localization.en.lua` — WSG patterns :50-59, Era start-message variants :36-45
