# Tracking WSG Flag State & Carrier Identity per Flavor — Research

**Date:** 2026-06-09
**Author:** Claude (in-game verification: Richard, pending)
**Status:** Draft (Final once the in-game action items are done)
**Confidence:** Medium — the event mechanism is proven by Capping's shipped code; the FC-name patterns and aura IDs need in-game capture on Era
**Flavors verified:** none in-game yet (evidence is Capping's shipped source)

---

> **UPDATE 2026-06-09 (post DBM-PvP review — see `dbm-pvp-review-reference.md`):**
> the enUS patterns (pickup/drop/capture/return, F2/F3) don't need hand-capture
> — DBM-PvP ships them in **9 locales** (`localization.en.lua:50-59`), so
> multi-locale support becomes a port. Caveat: DBM marks the pickup/return/drop
> patterns "Unused" (its FC system is a TODO), so they are **untested** — the
> in-game action item becomes verifying those strings fire on Era as written.
> Also confirmed: 12s flag respawn; DBM's FC-vulnerability timers are
> retail-only, reinforcing F7's doubt about Era debuffs.

## Executive Summary

WSG flag tracking has **two separable difficulty tiers**:

1. **Flag events** (picked up / dropped / captured / returned) — solved the way
   Capping does it: `CHAT_MSG_BG_SYSTEM_ALLIANCE/HORDE` (+`_NEUTRAL`) messages
   matched against trigger patterns. Works on every flavor; the catch is the
   messages are **localized**, so patterns ship per locale (enUS first,
   graceful degrade elsewhere).
2. **Carrier identity (the FC's name)** — *not provided by any clean API*.
   Capping doesn't do names at all. The pickup chat message contains the name
   ("...was picked up by Kruelhand"), so the same parser yields it. A
   locale-independent *confirmation* exists via the carrier's flag aura
   (Warsong Flag / Silverwing Flag) — but only when you have a unitID
   (target/mouseover/nameplate), so it supplements, never replaces, chat parsing.

This unblocks **[WSG-2]** (FC status panel) and **[WSG-3]** (FC-aware
callouts). **[WSG-4]** (debuff-stack timers) has an extra open question noted
below.

## Research Question

How do flag pickup/drop/capture/return surface on retail 11.x, Cata Classic
4.x, and Classic Era 1.x, and how does an addon learn the flag carrier's name
for callouts like "EFC Kruelhand LOW at their tunnel"?

## Constraints

- Classic Era first; degrade gracefully on other flavors and non-enUS locales
- Event-driven; the provider must run from BG entry (same lesson as AB —
  state observed late is state unknown)
- Never block on what an API can't give: if the name is unknown, callouts say
  "EFC" instead of a name

## Findings

### F1 — Flag events arrive as BG system chat messages (all flavors)

Capping's `WarsongGulchTwinPeaks.lua` (one module serving retail + classic
cores) registers `CHAT_MSG_BG_SYSTEM_HORDE` and `CHAT_MSG_BG_SYSTEM_ALLIANCE`
and matches message text against localized trigger patterns (its
`L.capturedTheTrigger`) to detect captures. Pickup/drop/return arrive the same
way (also on `CHAT_MSG_BG_SYSTEM_NEUTRAL` for returns). Confidence: High for
the mechanism (shipped multi-flavor addon).

### F2 — The messages are localized; patterns are data, not API

The system messages are not reconstructable from client GlobalStrings in a
flavor-stable way — addons ship per-locale pattern tables. Plan: enUS
patterns first (captured verbatim in-game — action item), with the pattern
table structured so other locales are one data PR away. On an unknown locale
the provider still sees *widget/score-level* state but not names: the feature
degrades, never errors.

### F3 — FC names come from the pickup message

The enUS pickup message includes the player name ("The Horde flag was picked
up by %s!" shape). Parsing it yields carrier names for both flags —
maintained in a tiny state machine: each flag is `at_base` /
`carried(by name)` / `dropped`, transitioning on pickup/drop/capture/return
events. This is exactly the input WSG-2/3 need.

### F4 — Aura check: locale-independent FC confirmation (needs a unitID)

The carrier visibly bears the flag aura — classic spell IDs **23333 (Warsong
Flag — Horde's flag)** and **23335 (Silverwing Flag — Alliance's flag)**
(Medium confidence; verify on Era). Given a unitID (target, mouseover,
nameplate), scanning auras for those IDs answers "is this unit the FC?"
without any locale dependency — useful for a future "KILL my target" callout
and as a name-source fallback when the pickup message was missed. Note the
aura API itself is in flux (`UnitAura` vs `C_UnitAuras`) — wrap it behind one
helper and verify which exists on current Era (action item).

### F5 — Flag map positions exist as a separate old API (not needed for v1)

`GetNumBattlefieldFlagPositions()` / `GetBattlefieldFlagPosition(i)` return
carried-flag map coordinates (and a faction token) on classic-lineage clients
— position, not identity. Could later enrich callouts ("EFC mid-map") but is
not required for WSG-2/3. Verify availability on Era only if/when wanted.

### F6 — Respawn/time data (for completeness)

Capping starts a fixed **12s** flag-respawn timer after a capture, and reads
match time-remaining from UI widgets (retail widget via
`C_UIWidgetManager.GetIconAndTextWidgetVisualizationInfo`, classic via
`UPDATE_UI_WIDGET`). Relevant to WSG-4's endgame timing, not to WSG-2/3.

### F7 — Open question for [WSG-4]: do flag-carrier stacking debuffs exist on Era?

Focused Assault / Brutal Assault (the stacking FC debuffs, retail spell IDs
46392/46393) were a later-expansion addition; whether current Classic Era WSG
applies them at all needs in-game confirmation before WSG-4 is designed.
Confidence: Low.

## Analysis & Recommendation

Build a **FlagStateProvider** (lands with [WSG-2]), symmetric with AB's
NodeStateProvider:

```lua
-- Registered while GetActiveBg() == "WSG"; driven by CHAT_MSG_BG_SYSTEM_*
-- flags.ALLIANCE / flags.HORDE = { state = "at_base"|"carried"|"dropped",
--                                  carrier = name|nil, since = t }
```

- Gate registration on `GetActiveBg() == "WSG"` from `PLAYER_ENTERING_WORLD`
  (provider runs from gate-open, so no missed transitions).
- enUS pattern table first; patterns are data so locales extend it.
- Expose one read API (`GetFlagStates()`) for WSG-2/3 — the
  one-implementation-many-surfaces rule again.
- Aura-check helper (F4) ships separately when a callout needs it.

## Risks

- Missed chat events (player joined late, message throttling) leave a stale
  carrier — mitigate with the F4 aura check on target/mouseover and by
  resetting state on flag return/capture messages.
- Non-enUS clients get flag-state-only behavior until pattern tables are
  contributed (documented degrade, not a bug).
- Era patch drift on aura APIs (F4) — wrapper + re-verify on `.toc` bumps.

## Action Items — in-game capture (Richard, an Era WSG match)

- [ ] Screenshot the **exact** system messages for: flag picked up, flag
      dropped, flag captured, flag returned (both factions if convenient) —
      these become the enUS pattern table verbatim
- [ ] Target (or mouseover) a flag carrier and run:
      `/dump C_UnitAuras and C_UnitAuras.GetAuraDataByIndex and "C_UnitAuras ok" or "no C_UnitAuras"`
      and `/run for i=1,40 do local n,_,_,_,_,_,_,_,_,id=UnitAura("target",i); if n then print(i,n,id) end end`
      — confirms which aura API exists and captures the real flag aura spell IDs
- [ ] (For WSG-4, low priority) note whether a long-held flag shows a stacking
      debuff on the carrier

When done: fill the pattern table + aura IDs, set **Status: Final**, update
**Flavors verified**, bump the `CLAUDE.md` row.

## Sources

- https://github.com/BigWigsMods/Capping — `Modules/WarsongGulchTwinPeaks.lua`
  (chat-trigger detection, 12s respawn, widget time-remaining, retail/classic
  conditionals; notably: no carrier tracking)
- https://warcraft.wiki.gg/wiki/API_GetBattlefieldFlagPosition — flag position API (F5)
- `Research/bg-detection-reference.md` — `GetActiveBg()` gating (this repo)
- `Research/ab-node-state-research.md` — the provider pattern this mirrors (this repo)
