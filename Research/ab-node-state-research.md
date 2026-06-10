# Reading AB Node Ownership & Capture State per Flavor — Research

**Date:** 2026-06-09
**Author:** Claude (in-game verification: Richard, pending)
**Status:** Draft (Final once the in-game `/dump` action items are done)
**Confidence:** Medium-High — the core mechanism is proven by a maintained multi-flavor addon's Classic Era code path; the exact per-node ID/state tables still need in-game capture
**Flavors verified:** none in-game yet (evidence is Capping's shipped per-flavor source)

---

> **UPDATE 2026-06-09 (post DBM-PvP review — see `dbm-pvp-review-reference.md`):**
> the in-game capture is now **verification, not discovery**. Known from DBM's
> shipped Era code: AB uiMapID = **1461**; the full Era `textureIndex` decode
> table (node *and* state, fully locale-independent — supersedes the
> `areaPoiID`-identity plan in F3); capture time on Era is **64s, not 60s**;
> classic AB score widgets are **1893/1894**, with resource rates and the
> bases-to-win math for [AB-5]. Friday's `/dump` session shrinks to: confirm
> one node flip matches the decode table.

## Executive Summary

AB node states (who owns Stables/Gold Mine/Blacksmith/Lumber Mill/Farm, and
whether a base is being assaulted) are readable on **all three flavors through
one API family**: `C_AreaPoiInfo.GetAreaPOIForMap(mapID)` +
`C_AreaPoiInfo.GetAreaPOIInfo(mapID, poiID)`, refreshed on the
**`AREA_POIS_UPDATED`** event. This is not retail-only: Capping's
`Core_Vanilla.lua` (its Classic Era core) uses exactly these calls. Capture
*timers* are not exposed by the API — they are derived client-side by
timestamping the assault transition and counting down the fixed capture time
(60s in AB). This unblocks **[AB-2]** (node strip), **[AB-3]** (timers),
**[AB-4]** (enriched callouts), **[AB-5]** (advice engine).

## Research Question

What does each flavor (retail 11.x, Cata Classic 4.x, Classic Era 1.x) expose
for AB node ownership and capture state, and what common abstraction can the
advisor sit on?

## Constraints

- Locale-independent (no parsing of localized BG system chat messages)
- Must work on Classic Era first (the dev/verify flavor), degrade gracefully elsewhere
- Event-driven, not `OnUpdate` polling (per `Process/WorkingWithClaude.md` §5)

## Findings

### F1 — The modern POI API exists on Classic Era (the hard question, answered)

Capping (BigWigsMods, maintained, ships Vanilla/TBC/Wrath/Cata/Mists `.toc`s)
implements its Classic Era node tracking in `Core_Vanilla.lua` with:

- `C_AreaPoiInfo.GetAreaPOIForMap(curMapID)` — array of POI IDs for the map
- `C_AreaPoiInfo.GetAreaPOIInfo(curMapID, poiID)` — reads `name`,
  `textureIndex`, `atlasName`, `areaPoiID`
- `AREA_POIS_UPDATED` — the refresh trigger

Confidence: **High** that the mechanism works on Era (a shipped addon's
era-specific code path is near-primary evidence). The wiki pages for these
APIs only carry retail 8.0.1 annotations and don't document flavor coverage —
the addon source is the better evidence here.

### F2 — Node state is encoded in `textureIndex` (classic) / `atlasName` (modern)

Each AB base's POI changes texture as it changes hands. Capping classifies
faction by `textureIndex` membership in known sets (Alliance: 3, 8, 17, 22,
27, 32, 37, 137, …; Horde: 13, 11, 19, 24, 29, 34, 39, 139, …) and by
`atlasName` colors on modern clients. Each node has five logical states:
neutral, Alliance-assaulted, Alliance-controlled, Horde-assaulted,
Horde-controlled. **Gap:** the exact textureIndex → assaulted-vs-controlled
mapping per state was not extractable from the excerpt — captured in-game
instead (action items below). Confidence: Medium until dumped.

### F3 — Node identity: prefer `areaPoiID`, not `name`

`name` is localized ("Stables" vs "Ställe") — fine for display, wrong for
identity. `areaPoiID` is a stable numeric database ID per node+state and is
returned on Era (Capping reads it). The per-node ID sets need one in-game
capture session. Fallback identity: POI map position (nodes never move).

### F4 — Capture timers are client-derived, not API-provided

No API returns "this base flips in N seconds." Capping starts a fixed-length
timer when it observes the assault transition: AB capture time is **60s**
(classic; believed unchanged on retail remaster — verify). Implication for
**[AB-3]**: our timer accuracy depends on seeing the transition, so the
provider must run from BG entry, not from when the window opens. A node
already contested when we join shows "contested, time unknown" honestly.

### F5 — Resources/score come from UI widgets, not POIs

Capping's score estimator hangs off `UPDATE_UI_WIDGET`. That's the input
**[AB-5]** ("we're behind on resources → call the weakest enemy base") will
need; the widget IDs per flavor are a separate small capture, deferred to AB-5.

### F6 — Map ID for the POI queries

`C_Map.GetBestMapForUnit("player")` while inside AB gives the uiMapID to pass
to the POI calls (Capping does the same via its `curMapID`). Note this is the
**uiMapID**, a different namespace from the `instanceMapID` (529/2107) used by
`GetActiveBg()` — don't conflate them.

## Analysis & Recommendation

Build a small **NodeStateProvider** in the addon (lands with [AB-2]):

```lua
-- Registered while GetActiveBg() == "AB"; refreshed on AREA_POIS_UPDATED
-- nodeStates[abbr] = { owner = "ALLIANCE"|"HORDE"|nil, contested = bool, flipAt = t|nil }
```

- On `PLAYER_ENTERING_WORLD` → if `GetActiveBg() == "AB"`, register
  `AREA_POIS_UPDATED` and do an initial scan; unregister on leaving.
- Scan: `GetAreaPOIForMap(C_Map.GetBestMapForUnit("player"))` → for each POI,
  identify the node (areaPoiID set per F3) and decode state (tables per F2).
- On a → assaulted transition, set `flipAt = GetTime() + 60` (F4).
- Expose one read API (`GetNodeStates()`) for AB-2/3/4/5 — same
  one-implementation-many-surfaces rule as `GetActiveBg()`.

The decode tables (F2/F3) ship as data constants captured from the action
items below; unknown POIs are ignored, so wrong/missing entries degrade to
"node not shown," never an error.

## Risks

- The textureIndex/areaPoiID tables may differ per flavor — mitigate by
  keying decode tables per flavor if the Era dump and wiki disagree.
- A node assaulted before we observe it has an unknown flip time (F4) — show
  contested without a countdown rather than guessing.
- Era patches occasionally move APIs; re-verify on `.toc` Interface bumps
  (per `RESEARCH-PROCESS.md` freshness rule).

## Action Items — in-game capture (Richard, inside an Era AB match)

Run once standing in AB (results paste-able to Claude to turn into tables):

- [ ] `/dump C_Map.GetBestMapForUnit("player")` — the AB uiMapID
- [ ] `/dump C_AreaPoiInfo.GetAreaPOIForMap(C_Map.GetBestMapForUnit("player"))` — the live POI ID list
- [ ] For each ID: `/dump C_AreaPoiInfo.GetAreaPOIInfo(<mapID>, <poiID>)` — record `name` + `areaPoiID` + `textureIndex` per node
- [ ] Repeat the dump after a node you can see gets **assaulted** and again
      after it **flips** — that captures the per-state textureIndex values
- [ ] Note whether the POI list visibly updates (i.e. `AREA_POIS_UPDATED`
      delivering) for a node fight you watch

When done: fill the decode tables, set **Status: Final**, update
**Flavors verified**, bump the `CLAUDE.md` row.

## Sources

- https://github.com/BigWigsMods/Capping — `Core_Vanilla.lua` (Era POI usage:
  `GetAreaPOIForMap`/`GetAreaPOIInfo`/`AREA_POIS_UPDATED`, textureIndex sets),
  `Modules/ArathiBasin.lua` (zone wiring), multi-flavor `.toc`s
- https://warcraft.wiki.gg/wiki/API_C_AreaPoiInfo.GetAreaPOIForMap — return shape (retail-annotated only)
- https://warcraft.wiki.gg/wiki/AREA_POIS_UPDATED — event (stub; no flavor data)
- `Research/bg-detection-reference.md` — `GetActiveBg()` (this repo), the gate for when the provider runs
