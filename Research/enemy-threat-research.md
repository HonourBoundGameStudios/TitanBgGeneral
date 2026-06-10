# Identifying & Ranking Dangerous Enemy Players in a BG — Research

**Date:** 2026-06-09
**Author:** Claude (research agent; in-game verification: Richard, pending)
**Status:** Draft (Final once Friday's in-game action items are done)
**Confidence:** Medium-High — the core signals are proven by shipped addons running on the user's Era client (Details, Spy) and by BattlegroundEnemies' multi-flavor source; exact Era scoreboard return positions/values not yet `/dump`-verified
**Flavors verified:** none in-game yet (evidence is shipped addon source, including two addons installed and running in the user's Era client)

---

> Builds on `dbm-pvp-review-reference.md` (crowd-sourced HP-sync architecture —
> referenced for priority-target HP, not repeated here) and
> `wsg-flag-state-research.md` (chat-pattern parsing, aura confirmation).
> This document covers a different question: **who** to call out, not where the
> flag/nodes are.

## Executive Summary

Era gives an addon **two complementary signal sources** for ranking enemy threats:

1. **The battlefield scoreboard** — `GetBattlefieldScore(i)` returns, for *every*
   player in the match (both factions, map-wide), cumulative `damageDone`,
   `healingDone`, `killingBlows`, `deaths`, and a locale-independent
   `classToken`. This alone supports the thesis: *top enemy healingDone = healer
   = CC priority; top damageDone/KBs = kill priority*. It is refreshed by
   polling `RequestBattlefieldScoreData()` and reading on
   `UPDATE_BATTLEFIELD_SCORE` — shipped addons poll at 2s (BattlegroundEnemies)
   and 10s (Details) with no apparent penalty.
2. **The combat log (CLEU)** — full event fidelity for *nearby* units only.
   Used by shipped addons to confirm healers (heal events / healer-spell IDs by
   enemy GUID), detect burst, and discover players before they appear active on
   the scoreboard. Higher cost and complexity; not needed for v1.

**Spec detection does not exist on Era** — no enemy inspect, and the scoreboard
`talentSpec` field is a later-flavor feature. Every shipped classic addon
*infers* role instead: by healing/damage ratio (BattleGroundHealers' rule
`healing > h2d × damage AND healing > floor`), by observed spell IDs
(HHTD, Spy), or by class prior (only 4 classes can heal on Era, and the
paladin/shaman faction split removes one of them per side).

**Recommendation:** a scoreboard-only `ThreatProvider` for v1 — poll every 10s
while `GetActiveBg()` is set, flag healers by class-prior + heal/damage ratio,
rank healers by `healingDone` (CC list) and the rest by `damageDone` with a
`killingBlows` tiebreak (kill list), surface as advisory chat callouts through
the existing `GetChatType()` path. CLEU refinement (recency weighting, healer
confirmation) is an optional v2.

## Research Question

What signals exist, per flavor (Classic Era 1.15.x primary; retail 11.x and
Cata Classic 4.x secondary), for an addon to identify and rank the most
dangerous enemy players in a battleground — healers (CC priority) and
high-threat DPS (kill priority) — so the leader can send callouts to chat?

## Constraints

- **Locale independence** — rank on numeric returns and `classToken` /
  spell-ID / GUID signals only. Never key logic on localized strings
  (`class`, `race`, `talentSpec` where it exists are all localized).
- **Event-driven** — no unthrottled `OnUpdate`. A `C_Timer.NewTicker` calling
  `RequestBattlefieldScoreData()` plus an `UPDATE_BATTLEFIELD_SCORE` handler is
  the whole loop.
- **Advisory only** — the addon sends chat messages; it never targets, casts,
  or touches protected functions. Ranking output is text for the leader's
  callout buttons.
- **Gated on being in a BG** — register the provider only while
  `GetActiveBg()` returns a BG (TitanBgGeneral.lua:93), unregister on leave;
  same lifecycle as the planned Node/Flag providers.
- Degrade gracefully: early-match (small numbers) and missing-API (flavor
  drift) cases must produce weaker advice, never errors.

## Findings

### F1 — Era scoreboard returns include damageDone AND healingDone, plus an extra `rank` slot (Confidence: High for the signature shape, Medium for exact Era values)

Details (installed, working on the user's Era client) unpacks
`GetBattlefieldScore(i)` with **two flavor signatures**
(`core\parser.lua:7772-7776`; `isCLASSIC` at line 53 covers Era through Mists):

```lua
-- classic lineage (Era, TBC, Wrath, Cata, Mists):
name, killingBlows, honorableKills, deaths, honorGained, faction, rank,
  race, class, classToken, damageDone, healingDone,
  bgRating, ratingChange, preMatchMMR, mmrChange, talentSpec = GetBattlefieldScore(i)

-- retail:
name, killingBlows, honorableKills, deaths, honorGained, faction,
  race, class, classToken, damageDone, healingDone, ... = GetBattlefieldScore(i)
```

The classic lineage inserts **`rank` (honor rank) at position 7**, shifting
everything after it by one — the warcraft.wiki.gg page documents only the
retail shape and omits `rank` entirely, a concrete case of the "wiki is
retail-shaped" rule. Details consumes both `damageDone` and `healingDone` on
Era (`parser.lua:7787-7849`), so **healingDone is populated on Era** — the
thesis signal exists. `bgRating`/`ratingChange`/`mmr`/`talentSpec` are
expected nil/0 on Era (rated BGs and inspectable specs don't exist there) —
verify Friday.

### F2 — Roster, enemy filter, and faction encoding are all numeric (Confidence: High)

- `GetNumBattlefieldScores()` sizes the loop (Details `parser.lua:7761`); the
  scoreboard covers **all players of both factions, map-wide** — global
  coverage no other signal has.
- `faction` return: **0 = Horde, 1 = Alliance** in BGs. Details compares it
  against `faction_id` set exactly that way from `UnitFactionGroup("player")`
  (`parser.lua:6696-6702`, used at 7800/7832) — enemy = `faction ~= mine`.
  Locale-independent.
- Cross-realm names arrive as `Name-Realm`; Details normalizes with
  `Details:Ambiguate(name)` (`parser.lua:7785`). Keep the full name as the
  table key; ambiguate only for chat display.

### F3 — Refresh is poll-driven; shipped cadences are 2s and 10s (Confidence: High)

Score data is a snapshot that only updates when requested:
`RequestBattlefieldScoreData()` → server responds → `UPDATE_BATTLEFIELD_SCORE`
fires → read. Shipped cadences:

- **Details: 10s ticker** + event read (`parser.lua:7733-7746` —
  `NewTicker(10, Details.BgScoreUpdate)` with `RegisterEvent("UPDATE_BATTLEFIELD_SCORE")`).
- **BattlegroundEnemies: 2s**, via a throttled `OnUpdate` on a request frame
  (`Main.lua` ~1909, `local UpdatePeroid = 2`).

No evidence of server-side throttling penalties at either rate. For a callout
advisor, 10s is plenty (the data is cumulative; it moves slowly).

### F4 — Enemy *spec* is not detectable on Era via API; retail and late-classic differ (Confidence: High for Era absence; Medium for retail/Cata specifics)

- **Era:** no inspect of hostile players, and BattlegroundEnemies only unpacks
  the scoreboard spec field when `HasSpeccs = not not GetSpecialization`
  (a Mists-of-Pandaria-and-later API; `Main.lua` ~104, ~2277). On Era that is
  false — the addon whose entire job is enemy display has **no API path to
  enemy spec on Era**. Its CurseForge page states the combat-log scan method
  has "no way to get a player's specialization."
- **Retail:** `C_PvP.GetScoreInfo(i)` returns a structured `PVPScoreInfo`
  including `classToken`, `damageDone`, `healingDone`, and `talentSpec`
  (localized!) — BGE's `parseBattlefieldScore` (`Main.lua` ~2259-2267).
  Healer identification is direct; no heuristic needed. (Whether modern Era
  clients also expose `C_PvP.GetScoreInfo` is a Friday `/dump` — if yes, it's
  still spec-less there.)
- **Cata Classic:** uses the classic `GetBattlefieldScore` signature (F1).
  Details' shared classic branch unpacks `talentSpec` at position 17; whether
  it populates on Cata Classic is unverified (Low) — treat Cata like Era
  (heuristic) until proven otherwise.

### F5 — Shipped addons infer healer/class from observed behavior; three proven patterns (Confidence: High — all from shipped code)

1. **Scoreboard ratio rule** — BattleGroundHealers (WotLK lineage) flags a
   healer when `healing > h2d × damage AND healing > hth` (both thresholds
   configurable). Purely numeric, flavor-agnostic, ports to Era directly.
2. **Rolling CLEU healing accumulation** — HHTD (has a `-classic` build)
   accumulates healing per GUID over the **last 60s** and flags healers past a
   threshold (default: 50% of your own max HP), with a spell-ID list of
   dedicated-healer spells to distinguish specialized healers from hybrids.
3. **Spell-ID → class/role table** — Spy (installed, Era) learns class, race,
   and minimum level from any CLEU ability via `Spy_AbilityList[spellId]`
   (`List.lua:1022-1078`, called from the CLEU handler at `Spy.lua:2184`).
   Spell IDs are locale-independent; the same table shape can mark
   healer-defining spells (e.g. only a resto druid casts certain ranks).

Plus the **Era class prior**: only PRIEST, DRUID, PALADIN, SHAMAN can heal,
and the faction split (no Horde paladins, no Alliance shamans on Era) leaves
exactly **three healer-capable classes per side**. `classToken` from the
scoreboard makes this filter free.

### F6 — CLEU on Era: full fidelity, nearby-only, hostile-filterable, but costly (Confidence: High)

Spy's shipped Era handler shows the whole pattern (`Spy.lua:2153-2231`):

- `CombatLogGetCurrentEventInfo()` exists and is the read API on Era
  (`Spy.lua:2154`).
- Hostile players filter cheaply:
  `bit.band(srcFlags, COMBATLOG_OBJECT_REACTION_HOSTILE)` + GUID prefix
  `"Player"` (`Spy.lua:2170-2172`).
- `GetPlayerInfoByGUID(guid)` returns the **locale-independent class token as
  the 2nd return** for any player GUID seen in CLEU (`Spy.lua:2173`) — class
  without a unitID.
- Heal events (`SPELL_HEAL`/`SPELL_PERIODIC_HEAL`) carry amount + overhealing,
  so per-GUID *effective* healing and per-GUID burst damage are computable.
- **Limitations:** CLEU only reports events near the player, so it is a local
  signal (the scoreboard is the global one); BGE notes combat-log discovery
  misses anyone not yet in combat and debounces roster updates by 1s
  (`Main.lua` ~1630). In a 10–40 player BG the event rate is high — the
  handler must early-out on the flags test, and this is the main cost/
  complexity argument for keeping CLEU out of v1.

### F7 — Adjacent signals, noted for completeness (Confidence: Low-Medium)

- Per-BG objective stats (flag captures, bases assaulted/defended) exist as
  extra scoreboard columns (`GetBattlefieldStatData` on classic lineage /
  `stats` in `PVPScoreInfo` on retail) — could someday flag "their best
  capper"; wiki-only evidence, unverified on Era.
- CC diminishing-returns tracking (Diminish/DRList-1.0 pattern) is CLEU-based
  and feasible, but DR categories on Era differ from later flavors and the
  payoff for a *chat advisor* is small — out of scope.
- For "priority target is LOW" callouts, the DBM-PvP crowd-sourced HP-sync
  architecture (see `dbm-pvp-review-reference.md`, PvPGeneral.lua:121-357)
  ports to enemy GUIDs — referenced, not re-established here.

## Evidence

| # | Claim | Source |
|---|---|---|
| E1 | Classic signature with `rank` at pos 7; both damage and healing unpacked | `Details\core\parser.lua:7772-7776` (isCLASSIC def :53) |
| E2 | healingDone consumed on Era (heal actor totals) | `Details\core\parser.lua:7819-7849` |
| E3 | faction 0=Horde / 1=Alliance; enemy = faction mismatch | `Details\core\parser.lua:6696-6702, 7800` + warcraft.wiki.gg `API_GetBattlefieldScore` |
| E4 | 10s poll ticker + UPDATE_BATTLEFIELD_SCORE read | `Details\core\parser.lua:7733-7746` |
| E5 | 2s poll throttle | BGE `Main.lua` ~1909 (`UpdatePeroid = 2`) |
| E6 | Retail uses `C_PvP.GetScoreInfo` (talentSpec); classic falls back to `GetBattlefieldScore`; spec gated on `GetSpecialization` existing (MoP+) | BGE `Main.lua` ~104, ~2259-2278 |
| E7 | CLEU hostile-player filter + `GetPlayerInfoByGUID` class token | `Spy\Spy.lua:2153-2231` (esp. 2170-2173) |
| E8 | Spell-ID → class/race/level inference table | `Spy\List.lua:1022-1078` (`Spy_AbilityList[spellId]`) |
| E9 | Scoreboard ratio healer rule `healing > h2d×damage AND healing > hth`; dual CLEU+scoreboard detection | github.com/KhalGH/BattleGroundHealers-WotLK README |
| E10 | 60s rolling CLEU healing threshold + dedicated-healer spell list | HHTD CurseForge description (classic builds exist, e.g. 2.4.x-classic) |
| E11 | Combat-log roster scan misses idle players; 1s debounce | BGE `Main.lua` ~1590-1648 |

(Local addon paths under `D:\Games\World of Warcraft\_classic_era_\Interface\AddOns\`.)

## Analysis

The thesis tests out. On Era the scoreboard is the **only global signal** and
it directly carries the two numbers the thesis needs, in locale-independent
form, with `classToken` to prune false healers. Its weaknesses are exactly the
ones a callout advisor can tolerate:

- **Cumulative, not current** — a healer who left or is AFK still ranks. A
  callout leader glancing at names tolerates this; v2 CLEU recency fixes it.
- **Cold start** — for the first ~2-3 minutes the numbers are too small to
  rank on. Degrade to the class prior ("their PRIEST/DRUID are the likely
  healers") until a healing floor is crossed.
- **Hybrid noise** — a shadow priest accrues damage, not healing; the ratio
  rule (E9) classifies them as a kill target, which is correct.

CLEU could replace none of this (nearby-only, no global roster) but can refine
all of it. That asymmetry is the architecture: **scoreboard = ranking source
of truth, CLEU = optional freshness/confirmation layer.** Shipping v1 without
CLEU keeps the single-file addon simple and the handler budget at ~zero.

Per-flavor: retail collapses the whole problem (talentSpec/role from
`C_PvP.GetScoreInfo` — branch on its existence, not on flavor). Cata Classic
behaves like Era until its `talentSpec` return is proven populated.

## Recommendation

Add a **ThreatProvider** (same lifecycle as the planned Node/Flag providers):

```lua
-- Registered while GetActiveBg() ~= nil (PLAYER_ENTERING_WORLD / zone change)
-- ticker: C_Timer.NewTicker(10, RequestBattlefieldScoreData)
-- event:  UPDATE_BATTLEFIELD_SCORE -> rebuild ranking

local HEALER_CAPABLE = { PRIEST=true, DRUID=true, PALADIN=true, SHAMAN=true }
local H2D, HEAL_FLOOR = 1.5, 20000   -- ratio rule (E9); floor tunable

-- per enemy row (faction ~= myFactionId):
--   isHealer = HEALER_CAPABLE[classToken]
--              and healingDone > H2D * damageDone
--              and healingDone > HEAL_FLOOR
-- ranking:
--   CC list   = healers sorted by healingDone desc      (top 2)
--   KILL list = non-healers sorted by damageDone desc,  (top 2)
--               tiebreak killingBlows desc
-- cold start (no enemy past HEAL_FLOOR yet):
--   CC list = healer-capable classes present, unranked, marked "(likely)"
```

Output is one advisory line through the existing `GetChatType()` send path,
fired only by an explicit button press (never automatic), e.g.:

> `CC: Healbot (Priest), Treeform (Druid) | KILL: Boomstick (Mage)`

Implementation notes:

- Branch on **API presence**, not flavor: `if C_PvP and C_PvP.GetScoreInfo`
  use it (retail; healer = talentSpec/role directly), else the classic
  17-return unpack from F1.
- Wrap the unpack so nil trailing returns are harmless (Era will likely return
  nil for `talentSpec` and 0/nil for ratings).
- Defer v2 (CLEU recency multiplier, healer confirmation via heal events /
  healer-spell IDs, "target is LOW" via the DBM HP-sync port) until v1's
  rankings prove insufficient in real matches.

## Risks

- **Era return positions unverified in-game** — the `rank`-at-7 shift comes
  from Details' shipped branch; if wrong, damage/healing land one slot off and
  the ranking is garbage. Friday's `/dump` is the gate before any code.
- **Enemy healingDone could lag or sandbag** (server sends cumulative
  snapshots; mid-match accuracy assumed, not proven on Era).
- **Cold start / AFK drift** mitigations are heuristic; callouts should read
  as advice, not fact (the "(likely)" marker).
- **Cata Classic `talentSpec`** unknown — treat as Era until verified; no
  failure mode either way (heuristic still works).
- **Chat spam** — bounded by design: button-press-only sends, one line.

## Action Items — in-game verification (Richard, Era BG, Friday 2026-06-12)

- [ ] Mid-match, with the scoreboard opened once, run:
      `/run local n=select("#",GetBattlefieldScore(1)) print("nret",n) for k=1,n do print(k,(select(k,GetBattlefieldScore(1)))) end`
      — confirm count, that position 7 is honor rank, positions 11/12 are
      damageDone/healingDone, and whether 17 (talentSpec) is nil on Era.
- [ ] Confirm an enemy row: find an index where position 6 (faction) differs
      from yours and check its name/class/healing look right (pick the enemy
      healer you've been fighting).
- [ ] `/dump GetNumBattlefieldScores()` — full 10v10/15v15 roster present
      mid-match without reopening the scoreboard?
- [ ] Event-without-UI check:
      `/run local f=CreateFrame("Frame") f:RegisterEvent("UPDATE_BATTLEFIELD_SCORE") f:SetScript("OnEvent",function() print("UBS",GetNumBattlefieldScores()) end) RequestBattlefieldScoreData()`
      — confirms the poll loop works with the scoreboard closed.
- [ ] `/dump C_PvP and type(C_PvP.GetScoreInfo)` on Era — if it exists,
      compare its table against the positional returns.
- [ ] Note roughly how long into the match enemy healingDone becomes a clear
      separator (calibrates `HEAL_FLOOR`).

When done: fill verified values, set **Status: Final**, update
**Flavors verified**, bump the `CLAUDE.md` research table row.

## Sources

- `D:\Games\World of Warcraft\_classic_era_\Interface\AddOns\Details\core\parser.lua` —
  classic/retail unpack :7772-7776, isCLASSIC :53, ticker :7733-7746,
  healing consumption :7819-7849, faction encoding :6696-6702, Ambiguate :7785
- `D:\Games\World of Warcraft\_classic_era_\Interface\AddOns\Spy\Spy.lua` —
  CLEU registration :1744, handler + hostile filter + GetPlayerInfoByGUID
  :2153-2231; `Spy\List.lua` — spell-ID inference :1022-1078;
  BG gating option :90-100, :1970
- https://github.com/BullseiWoWAddons/BattleGroundEnemies — `Main.lua`
  (`parseBattlefieldScore` ~2259, `HasSpeccs` ~104, request throttle ~1909,
  GUID scan ~1590-1648); CurseForge page (combat-log scan has no spec access)
- https://github.com/KhalGH/BattleGroundHealers-WotLK — dual detection;
  scoreboard ratio rule `healing > h2d×damage AND healing > hth`
- https://www.curseforge.com/wow/addons/h-h-t-d — HHTD: 60s rolling CLEU
  healing threshold + dedicated-healer spell list (classic builds available)
- https://warcraft.wiki.gg/wiki/API_GetBattlefieldScore — retail-shaped
  signature + faction encoding (omits classic `rank` return — wiki caveat)
- `Research/dbm-pvp-review-reference.md` — HP-sync architecture (referenced)
- `Research/wsg-flag-state-research.md` — provider pattern, chat parsing
- `Research/bg-detection-reference.md` / `TitanBgGeneral.lua:93` — `GetActiveBg()` gating
