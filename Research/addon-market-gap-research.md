# Battleground Addon Market — Per-BG Recap & Gap Analysis

**Date:** 2026-06-10
**Author:** Claude Code (web survey), for Richard's review
**Status:** Final
**Confidence:** Medium
**Flavors verified:** n/a — market research (Classic Era is the primary lens; flavor support of each competitor noted where known)

---

## Executive Summary

The Classic battleground addon market splits cleanly into four categories —
**timers/state display** (Capping, DBM-PvP, REPorter), **enemy frames**
(BattlegroundEnemies, VantageEnemyFrames, TargetEFC), **static callout
buttons** (Arathi Calls, BG Caller, BGSoundAlerts, Incoming-BG), and **leader
QoL** (Battleground Commander — not even on Era). Every one of them either
*shows data* or *sends canned text*. **No addon on any flavor advises** — none
computes "what should we do next", none ranks enemy threats into engage/avoid
guidance, and none fuses live BG state into the callout it sends. Those three
gaps are exactly AB-4/AB-5, CMD-6/CMD-7, and WSG-3 in our backlog, and the
underlying research for all of them is already done. The biggest
bang-for-buck items are the ones nobody else has: the engage/avoid threat
advisor (research complete, scoreboard-only dependency) and state-enriched
callouts (the unique fusion of what Capping knows with what Arathi Calls
does).

---

## Research Question

For each battleground (AB, WSG, AV): what do we have today, what does the
existing Classic addon market offer, what does **not** exist anywhere, and
which backlog epics buy the most differentiation per unit of effort?

## Constraints

* Primary target is **Classic Era / Anniversary realms** — addons that only
  ship for retail or Wrath/Cata Classic leave the Era field open.
* Findings come from CurseForge/WowInterface/Wago listings and addon
  descriptions (web survey), not from reading every competitor's source.
  Capping and DBM-PvP source *have* been read — see
  `dbm-pvp-review-reference.md` and `ab-node-state-research.md`.
* "Doesn't exist" claims are as good as the search coverage; a niche or
  abandoned addon could have been missed (see Risks).

---

## Findings

### F1 — Our current feature set (from `TitanBgGeneral.lua`, develop @ 3c4b688)

| Area | Shipped today |
|---|---|
| **AB** | 5-node (ST/GM/BS/LM/FM) × 6-row callout grid; player-count rows; Shift/Ctrl/Alt message variants |
| **WSG** | EFC/FC/MID/RAMP/TUN × INC/DEF/HELP/KILL/GO/CAP grid |
| **AV** | DB/IW/SH/SF/TP/IB/FW × INC/DEF/HELP/CAP/GO/RECAP grid |
| **Shared** | Locale-independent BG detection (instanceMapID); auto tab select on zone-in; auto-open/close on BG entry/exit; BG abbreviation on the Titan bar; channel priority INSTANCE_CHAT → RAID → PARTY → SAY; drag-movable window with saved position |

In market terms: today we are a (multi-BG, Titan-integrated) member of the
**static callout buttons** category.

### F2 — Timers / state display addons

| Addon | Flavors | What it does | What it doesn't |
|---|---|---|---|
| **Capping Battleground Timers** (~10.5M DL, updated Apr 2026) | All, incl. Era | AB node capture timers + final-score estimation, WSG flag respawn timers + FC map/health, AV timers | No callouts, no chat output, no advice |
| **DBM-PvP** | All, incl. Era | Cap-timer bars, warnings, win-condition resource estimate (the bases-to-win math — see `dbm-pvp-review-reference.md`) | Displays info to the player; never directs the team |
| **REPorter — Battleground Map** | Retail-focused | Slim BG map: node states, capture timers, flag respawn | Not an Era staple; passive display |
| **SSPVP3** | Old multi-flavor lineage | AB/EotS match info; WSG FC names colored by class + health when available | Passive display |

### F3 — Enemy frame addons

| Addon | Flavors | What it does | What it doesn't |
|---|---|---|---|
| **BattlegroundEnemies** | Era → retail | Enemy/ally frames, targeting counts, racial/trinket tracking; *de facto* healer spotting by eyeball | No threat **ranking**, no matchup advice, no callouts |
| **VantageEnemyFrames** | Newer alternative | Similar frame display | Same gaps |
| **TargetEFC** | Classic lineage | EFC name frame + auto-updated `/target` macro | Single-purpose |

### F4 — Callout sender addons (our current direct competitors)

| Addon | Flavors | What it does | What it doesn't |
|---|---|---|---|
| **Arathi Calls** | Classic | Quick "INC <base>" alert buttons for the 5 AB bases | AB-only; static text; no live state |
| **BG Caller: Arathi Basin** | Classic | Click objective → pick message → send to BG chat | AB-only; static text |
| **BGCallouts** (WowInterface) | Old | Button-grid callouts | Static text |
| **Incoming-BG** | Wrath-era | Mouse-driven "help at X" calls | Static text |
| **BGSoundAlerts** | Old | Spoken sound cues + a communication list for orders | Static text; audio gimmick |

None embeds game state in the message. None covers WSG and AV with the same
quality as AB. None integrates a data layer at all.

### F5 — Leader / command tools

| Addon | Flavors | What it does | What it doesn't |
|---|---|---|---|
| **Battleground Commander** (~106K DL) | Retail + Wrath/Cata Classic — **no Era** | Queue QoL, auto raid-mark the leader, auto-assign assists, ready checks, raid-warning history frame | Logistics QoL only — no tactical direction, no role/node assignments, not on Era |
| **BGH — Battle Ground Helper** | Retail only | Floating HUD: who defends each base, incomings, FCs | Passive HUD; retail only |
| **BGAssist** (Turtle WoW) | Custom client | Timers, flag tracking, player counting | Different client entirely — evidence of demand, not competition |

### F6 — What does not exist anywhere (any flavor)

1. **An advice engine** — nothing computes "you hold 2 bases and are behind;
   attack the weakest enemy base" (our AB-5). The closest thing, DBM-PvP's
   bases-to-win estimate, displays a number and stops.
2. **A per-player engage/avoid advisor** — nothing combines threat ranking
   (damage/healing from the scoreboard) with class matchups into "kill this
   one, run from that one" (our CMD-7). Enemy-frame addons show *who exists*,
   not *who matters to you*.
3. **State-enriched callouts** — nothing sends "INC ST — 4+, flips in 0:22"
   (our AB-4) or "EFC <name> LOW — kill at tunnel" (our WSG-3). The data
   layer (Capping/DBM) and the callout layer (Arathi Calls et al.) have
   never been fused in one addon.
4. **CC-priority callouts** — nothing names enemy healers as CC/kill targets
   in team chat from scoreboard data (our CMD-6).
5. **Era-native leader command & control** — role/node assignment boards and
   opening-split presets (our CMD-1/2) exist nowhere on Era; Battleground
   Commander is the nearest neighbour and is neither on Era nor tactical.

### F7 — What is already well-served (don't compete head-on)

* **Raw timers and node-state display** — Capping (10.5M downloads) and
  DBM-PvP own this. Our AB-2/AB-3 should be built as *plumbing for the
  advisor and enriched callouts*, not pitched as the headline feature.
* **WSG FC name + health display** — Capping, SSPVP3, and TargetEFC all do
  it. Our WSG-2 panel is table stakes; the differentiation is WSG-3
  (FC-aware **callouts**).
* **Enemy unit frames** — BattlegroundEnemies is mature. CMD-7 must be a
  small advisory list, not another frame addon.

## Evidence

* CurseForge listing pages and descriptions for Capping, SSPVP3, Arathi
  Calls, BG Caller: Arathi Basin, Incoming-BG, BattlegroundEnemies,
  VantageEnemyFrames, Battleground Commander, BGH (URLs in Sources;
  retrieved 2026-06-10).
* Battleground Commander's own GitHub/CurseForge feature list: queue tools,
  auto-marker, auto-assist, ready checks — confirms the "logistics, not
  tactics" reading; flavor support listed as Dragonflight/WotLK Classic.
* Targeted searches for "battleground strategy advisor", "tells you what to
  do", "win condition bases needed" surfaced **no addon** in the advisor
  category on any flavor.
* DBM-PvP and Capping internals: first-party source reading documented in
  `dbm-pvp-review-reference.md` and `ab-node-state-research.md`.

## Analysis

Plotting the market on two axes — *has live data* vs *talks to the team* —
every existing addon sits on an axis endpoint. Capping/DBM/REPorter/BGE have
data and stay silent; Arathi Calls/BG Caller/BGSoundAlerts talk and are
blind. The entire upper-right quadrant (**data-driven direction**) is empty
on every flavor, and that quadrant is precisely the project vision.

Effort vs differentiation for the open backlog epics:

| Backlog item | Differentiation | Effort | Notes |
|---|---|---|---|
| **CMD-6/7** threat list + engage/avoid | **Unique on all flavors** | Low-medium | Research done (`enemy-threat-research.md`, `classic-class-matchup-reference.md`); scoreboard ticker + a small list window; no node-state dependency; valuable even when *not* leading |
| **AB-4/5** enriched callouts + advice engine | **Unique on all flavors** | Medium | Needs AB-2/3 plumbing first; decode-table `/dump` session pending |
| **WSG-3** FC-aware callouts | Unique (the callout half) | Medium | WSG-2 panel itself is parity with Capping; pattern capture pending |
| **AB-2/3** node strip + cap timers | Parity with Capping | Medium | Necessary plumbing, not a selling point — keep the UI minimal |
| **CMD-1/2** role board / opening splits | Unique on Era | High (UI-heavy) | Value concentrated in premade leading; defer behind the advisor items |
| **AV-2** AV-specific callouts | Low | Low | AV is a zerg; Capping/DBM already serve it; keep minimal |

## Recommendation

1. **Lead with the advisor identity.** Position the addon as "the addon that
   tells you what to call", not another timer or callout pad — that category
   has zero competitors on any flavor.
2. **Highest bang-for-buck next: CMD-6/7** (threat list → engage/avoid
   window). Both research docs are fresh, the only dependency is Friday's
   Era scoreboard `/dump` verify, it needs no node-state plumbing, and it
   helps every player every match — not just leaders.
3. **Then AB-2 → AB-5 as one arc**, framing AB-2/3 explicitly as plumbing
   (minimal strip UI) so the effort lands on AB-4/5 where the
   differentiation is.
4. **WSG-2 stays lean** (parity feature); spend the WSG effort on WSG-3.
5. **Defer CMD-1/2 and AV-2** — real but narrower value, higher UI cost.

This reorders nothing destructively — it suggests pulling CMD-6/7 forward,
ahead of (or interleaved with) Epic 2. Decision is the user's; the backlog
order is otherwise sound.

## Risks

* **Coverage risk** — the survey is listing-based; an obscure or abandoned
  addon with advisor features could exist. Mitigation: claims are framed as
  "not found", and the category leaders' feature lists were checked
  individually.
* **Fast-follow risk** — Capping or DBM-PvP could add callout output more
  easily than callout addons could add data. Our moat is the advice layer
  (rules + matchup data), which is design work, not API plumbing.
* **Era API risk** — the differentiating features still hang on the pending
  in-game verifies (scoreboard shape, AB decode tables, WSG patterns).
  Already tracked as action items in the respective research docs.

## Action Items

* [x] User review of this recap (2026-06-10) — recommendation accepted
* [x] CMD-6/7 pulled ahead of AB-2 — now Epic 1.5 in `Process/Backlog.md`
* [ ] Friday's `/dump` session remains the gate for both CMD-6/7 (scoreboard)
      and AB-2/3 (POI decode tables) — unchanged
* [x] Status flipped to Final; CLAUDE.md table row added

## Sources

* Capping Battleground Timers — https://www.curseforge.com/wow/addons/capping-bg-timers
* SSPVP3 — https://www.curseforge.com/wow/addons/sspvp3
* BattlegroundEnemies — https://www.curseforge.com/wow/addons/battlegroundenemies
* VantageEnemyFrames — https://www.curseforge.com/wow/addons/vantageenemyframes
* Arathi Calls — https://www.curseforge.com/wow/addons/arathi-calls
* BG Caller: Arathi Basin — https://www.curseforge.com/wow/addons/bg-caller-arathi-basin
* BGCallouts — https://www.wowinterface.com/downloads/info23501-BGCallouts.html
* BGSoundAlerts — https://www.wowinterface.com/downloads/info7278-BGSoundAlerts.html
* Incoming-BG — https://www.curseforge.com/wow/addons/inccallout
* Battleground Commander — https://www.curseforge.com/wow/addons/battleground-commander / https://github.com/linaori/wow-battleground-commander
* BGH — Battle Ground Helper — https://www.curseforge.com/wow/addons/bgh-battle-ground-helper
* REPorter — Battleground Map — https://addons.wago.io/addons/reporter-battleground-map
* TargetEFC — https://addonswow.com/targetefc
* BGAssist (Turtle WoW) — https://turtle-wow.fandom.com/wiki/BGAssist
* Internal: `dbm-pvp-review-reference.md`, `ab-node-state-research.md`, `enemy-threat-research.md`, `classic-class-matchup-reference.md`, `Process/Backlog.md`
