# Tracking WSG Flag State & Carrier Identity per Flavor — Research

**Date:** 2026-06-09 (updated 2026-07-04)
**Author:** Claude (in-game verification: Richard, pending)
**Status:** Draft (Final once the two remaining in-game action items are done)
**Confidence:** High — event mechanism + enUS patterns + aura IDs + 12s respawn sourced from two shipped addons (DBM-PvP, Capping) and the Classic spell DB, and the **named-drop string is now confirmed in-game (2026-07-04, VERIF-5)**; only the **aura-API flavour** still needs an in-game yes/no
**Flavors verified:** none in-game yet (evidence is DBM-PvP + Capping shipped source, Classic wowhead spell DB)

---

> **UPDATE 2026-06-09 (post DBM-PvP review — see `dbm-pvp-review-reference.md`):**
> the enUS patterns (pickup/drop/capture/return, F2/F3) don't need hand-capture
> — DBM-PvP ships them in **9 locales** (`localization.en.lua:50-59`), so
> multi-locale support becomes a port. Caveat: DBM marks the pickup/return/drop
> patterns "Unused" (its FC system is a TODO), so they are **untested** — the
> in-game action item becomes verifying those strings fire on Era as written.
> Also confirmed: 12s flag respawn; DBM's FC-vulnerability timers are
> retail-only, reinforcing F7's doubt about Era debuffs.

> **UPDATE 2026-07-04 (research spike — VERIF-5 prep, web-sourced):** pulled the
> DBM-PvP `localization.en.lua` + `PvPGeneral.lua` and Capping's WSG module
> verbatim; confirmed the Classic flag-aura spell IDs on wowhead; and **resolved
> F7**. Net effect: the ready-to-port **enUS pattern table is now written out
> below (F8)**, `CHAT_MSG_BG_SYSTEM_{ALLIANCE,HORDE,NEUTRAL}` registration is
> confirmed on both addons, 12s respawn is double-confirmed (DBM + Capping), and
> the stacking FC debuffs are confirmed **absent on Classic Era** (patch 2.4.0
> addition). The in-game work shrinks to **two yes/no checks**: does Era emit a
> *named* drop message, and is the aura API `UnitAura` or `C_UnitAuras`.

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

### F7 — RESOLVED: flag-carrier stacking debuffs do NOT exist on Classic Era

Focused Assault (spell **46392**) / Brutal Assault (**46393**) — the stacking
FC "vulnerability" debuffs — were **added in patch 2.4.0 (TBC)** and were
intentionally left out of Classic (Wowpedia; Blizzard forum confirmation). They
map to DBM-PvP's retail-only `Vulnerable1/2` announce strings ("The flag
carriers have become vulnerable to attack!"). **Consequence for [WSG-4]:** the
"Focused Assault stacks countdown" premise is invalid on Era — WSG-4 must pivot
to the **12s respawn timer** (F6, double-confirmed) + match-time widgets for
endgame calls. Two caveats: (a) a short **"Recently Dropped Flag"** debuff
(prevents immediate re-pickup by the dropper) *does* exist in Classic but is not
the stacking FC debuff and is irrelevant to timers; (b) non-standard realms
(Season of Discovery / private servers) may have added an FC debuff — verify per
realm before relying on its absence. Confidence: High (for retail Era).

### F8 — Ready-to-port enUS pattern table (the [VERIF-5]/WSG-2 data)

Verbatim from DBM-PvP `localization.en.lua` (keys named) + Capping, with the
named-drop inferred symmetric (the sole unverified row). The captured group in a
"Flag" message is **which flag** (its owning faction); the carrier/scorer is the
**enemy** of that faction. Aura confirmation: the **Alliance flag** = Silverwing
Flag **23335**, the **Horde flag** = Warsong Flag **23333** (F4, confirmed on
Classic wowhead).

```lua
-- Matched against CHAT_MSG_BG_SYSTEM_ALLIANCE / _HORDE / _NEUTRAL (all three).
-- flag = "Alliance"|"Horde" (which flag); who = carrier or scorer name.
local WSG_ENUS = {
    pickup   = "The (%w+) [Ff]lag was picked up by (.+)!",       -- CONFIRMED Era (DBM ExprFlagPickUp)
    returned = "The (%w+) [Ff]lag was returned to its base by (.+)!",-- CONFIRMED Era (DBM ExprFlagReturn)
    captured = "(.+) captured the (%w+) [Ff]lag!",              -- DBM ExprFlagCaptured (named scorer)
    -- CONFIRMED in-game (2026-07-04, VERIF-5): Era emits the NAMED drop; the
    -- generic form below never fired. Use [Ff]lag — see the casing note.
    dropped  = "The (%w+) [Ff]lag was dropped by (.+)!",        -- CONFIRMED Era
    -- Nameless fallbacks (state without identity — keep as backstop, but Era
    -- didn't emit droppedGeneric in the VERIF-5 sample):
    capturedFaction = "The (%w+) ha%w+ captured the flag!",      -- "The Alliance has captured the flag!"
    droppedGeneric  = "The flag has been dropped!",              -- DBM FlagDropped (Unused; not seen on Era)
    reset           = "The flag has been reset!",                -- DBM FlagReset  (Unused)
    respawned       = "The flags are now placed at their bases.",-- CONFIRMED Era post-capture respawn line
}
-- ⚠ CASING (VERIF-5): Era mixes case by faction — "The Alliance **F**lag was
-- dropped…" but "The Horde **f**lag was dropped…". Match [Ff]lag on EVERY row,
-- not just some. Names arrive realm-qualified + UTF-8 ("Cheèch-Mankrik"); (.+)
-- captures them intact.
-- flag name → the carrier's confirming aura (locale-independent, F4)
local FLAG_AURA = { Alliance = 23335 --[[Silverwing]], Horde = 23333 --[[Warsong]] }
```

State-machine mapping (from your faction's POV): "The **Alliance** Flag was
picked up by X" ⇒ *your* flag (if Alliance) is now on enemy **X** — the EFC to
call; confirm with Silverwing (23335) on a unitID. Symmetric for Horde/Warsong.
Patterns are unanchored `:match` (DBM's proven approach) — the BG system event
delivers the whole line, so no `^...$` needed, but anchoring is harmless if
preferred.

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

## Action Items — remaining in-game checks (Richard, an Era WSG match)

One yes/no item is left; the pattern table (F8) is otherwise sourced + now
in-game confirmed. Best done via the recorder ([VERIF-5]) rather than by hand —
arm it in WSG and it logs the verbatim `CHAT_MSG_BG_SYSTEM_*` lines, so no
screenshotting.

- [x] **Named-drop confirmation** — RESOLVED 2026-07-04 (VERIF-5, 43-message Era
      WSG sample). Era emits the NAMED drop: `"The Horde flag was dropped by
      Flatticus!"` — the generic `"The flag has been dropped!"` never appeared.
      Faction casing splits ("Alliance Flag" / "Horde flag"), names are
      realm-qualified + UTF-8. The FlagState `[Ff]lag` patterns handle all of it.
      Also seen: `"The flags are now placed at their bases."` (post-capture
      respawn) — added as the `respawned` row.
- [ ] **Aura API flavour:** on a targeted/mouseover FC, confirm `C_UnitAuras`
      vs `UnitAura` on current Era:
      `/dump C_UnitAuras and C_UnitAuras.GetAuraDataByIndex and "C_UnitAuras" or "UnitAura"`
      then verify the F8 IDs appear: `/run for i=1,40 do local n,_,_,_,_,_,_,_,_,id=UnitAura("target",i); if n and (id==23333 or id==23335) then print(n,id) end end`

Already resolved (no in-game needed): enUS patterns (F8), 12s respawn (F6),
event registration (F1), aura IDs (F4), Era debuff absence (F7).

When done: mark the F8 `dropped` row confirmed, set **Status: Final**, update
**Flavors verified**, bump the `CLAUDE.md` row.

## Sources

- https://github.com/DeadlyBossMods/DBM-PvP — `DBM-PvP/localization.en.lua`
  (verbatim `ExprFlagPickUp/Return/Captured`, `FlagCaptured`, `FlagDropped`/`Taken`/
  `Reset` marked Unused, `Vulnerable1/2`) + `PvPGeneral.lua` (registers
  `CHAT_MSG_BG_SYSTEM_ALLIANCE/HORDE/NEUTRAL`, `NewTimer(12,"TimerFlag")`) — the F8 table
- https://github.com/BigWigsMods/Capping — `Modules/WarsongGulchTwinPeaks.lua`
  (chat-trigger detection, 12s respawn double-confirm, widget time-remaining,
  retail/classic conditionals; notably: no carrier tracking)
- https://www.wowhead.com/classic/spell=23333/warsong-flag — Warsong Flag (Horde's flag) aura, confirmed Classic (F4)
- https://www.wowhead.com/classic/spell=23335/silverwing-flag — Silverwing Flag (Alliance's flag) aura, confirmed Classic (F4)
- https://wowpedia.fandom.com/wiki/Focused_Assault + https://www.wowhead.com/spell=46392/focused-assault — FC vulnerability debuff added patch 2.4.0, excluded from Classic (F7)
- https://warcraft.wiki.gg/wiki/API_GetBattlefieldFlagPosition — flag position API (F5)
- `Research/bg-detection-reference.md` — `GetActiveBg()` gating (this repo)
- `Research/ab-node-state-research.md` — the provider pattern this mirrors (this repo)
