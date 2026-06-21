# Detecting Enemy Spec / Role on Classic Era (for the BG Threat panel)

**Date:** 2026-06-20
**Author:** Richard Lalancette (Night Duty spike)
**Status:** Draft
**Confidence:** Medium
**Flavors verified:** none in-game yet — sourced from other addons' code + wiki; Era spell IDs need one `/dump`/recorder session (Action Items)

---

## Executive Summary

The way "arena addons pull off spec detection" does **not** transfer to battlegrounds, and especially not to Classic Era:

1. **Group/raid libraries** (`LibSpecialization`, `LibGroupInSpecT`) only learn specs that players **broadcast over addon comms** or that you can **`NotifyInspect`** — i.e. your own group/raid. Enemies broadcast nothing and can't be inspected. **Useless for enemy intel.**
2. **`ARENA_PREP_OPPONENT_SPECIALIZATIONS`** — the Blizzard event sArena/Gladdy actually use — is an **arena-only** API, and **arenas don't exist on Classic Era** (vanilla 1.15.x). **Not available to us at all.**
3. That leaves the only enemy-applicable method: **reading the combat log** (`COMBAT_LOG_EVENT_UNFILTERED`), which is exactly what we already do for damage/healing. Classic Era re-exposed `spellId` in CLEU as of **patch 1.15.0 (2023-11-14)**, so spell-signature detection is viable.

But vanilla has a structural wall: **most shaman spells are baseline** (any spec can cast Lightning Bolt, Chain Heal, Earth Shock). Only **deep-talent abilities** prove a spec (Stormstrike ⇒ Enhancement). Players don't cast those every fight, so spell-signature spec detection is **sparse and high-latency**.

**Recommendation:** don't chase exact spec. Track **role** by *behaviour* (what Warcraft Logs itself does), with spell signatures as a high-confidence override when we happen to see one:

- **Healer** = heals **allies** more than they damage enemies. (Drop the current `heals > 0` test — that's the Ña bug.)
- **Caster DPS** vs **Melee DPS** = magical-school spell damage vs physical/auto-attack damage.
- **Spec override** (optional, high confidence) = a small table of unmistakable talented/role spells (Stormstrike, Healing Wave on an ally, etc.).

This fixes "Elemental shaman Ña tagged as healer" directly and generalises to warriors/warlocks self-healing.

---

## Research Question

How do addons determine an **enemy** player's spec or combat role without the retail spec API, and what is actually usable in a **Classic Era battleground** to stop the Threat panel mis-classifying casters (e.g. Elemental shamans) as healers?

---

## Constraints

- **Enemy players**: no inspect, no addon comms, opposing faction.
- **Classic Era (1.15.x)**: no arena API, no `GetSpecialization`, no talent-tree inspection of enemies. Vanilla talent trees, vanilla spell set.
- We already run a CLEU aggregator (`Recorder` → `threat[name]` = damage/healing/heals/classToken). Any solution should extend it, not add a parallel system.
- Locale-independence is a project rule — prefer numeric `spellId`/`school` over localized names where possible.

---

## Findings

### F1 — Group spec libraries don't see enemies
`LibSpecialization` (BigWigsMods) transmits **your** talent string/role to other addon users over comms; `LibGroupInSpecT` caches **group** specs via inspect + comms ("there is no way to detect when another player respecs" without it). Both are group-scoped. An enemy in a BG is neither in your group nor running your addon. **(Medium–High)**

### F2 — Arena addons use an arena-only Blizzard event
sArena's "spec detection" is `ARENA_PREP_OPPONENT_SPECIALIZATIONS` (fired by Blizzard during arena prep), **not** combat-log analysis. Its CLEU handling is for DR/interrupts/auras, not spec. This event is arena-scoped and **absent on Era** (no arenas in vanilla). **(High)**

### F3 — Combat-log spell→class/spec is the only enemy-applicable method
The community technique (Paranoia, WeakAuras "detect enemy player") is: watch `COMBAT_LOG_EVENT_UNFILTERED` for hostile-flagged sources and map the **spell** to class/spec. Class deduction is reliable (we already get `classToken` from `GetPlayerInfoByGUID`); **spec** deduction requires a hand-rolled spell→spec table — "spec detection must be hand rolled… knowledge of what specs exist for each class and how each should be detected." **(Medium–High)**

### F4 — `spellId` is available in Era CLEU (since 1.15.0)
`CombatLogGetCurrentEventInfo()` provides `spellId` again in Classic Era as of patch **1.15.0 (2023-11-14)** (and BCC since 2.5.1). So we can match by ID, not just localized name. **Caveat:** in vanilla, **each spell rank is a distinct `spellId`** (Frostbolt R6 ≠ R14) — a signature table must list all ranks or match by name via `GetSpellInfo(spellId)`. **(Medium)**

### F5 — Vanilla baseline-vs-talent problem
Most shaman damage/heal spells are **baseline** (trainable by any spec): Lightning Bolt, Chain Lightning, Earth/Flame/Frost Shock, Healing Wave, Lesser Healing Wave, Chain Heal. Casting one does **not** prove a spec. Only **deep-talent** abilities are unambiguous: **Stormstrike** (Enhancement 31-pt), **Elemental Mastery** (Elemental 31-pt), **Nature's Swiftness** (Resto 31-pt). These are cast rarely, so signature detection is **sparse**. **(Medium-High, vanilla knowledge)**

### F6 — Warcraft Logs uses behaviour, not spells, for role
Kihra (WCL) on Classic spec detection: *"Determine healing by just seeing if they heal more during a fight than dps… Don't try to differentiate types of DPS within a class. Just lump them all together."* This is the pragmatic standard: **role by output ratio**, not per-spell spec. Directly validates the fix. **(High — it's the WCL author)**

---

## Evidence

- `LibSpecialization` README — transmits self talent/role over comms; fields specID, role (TANK/HEALER/DAMAGER), position (MELEE/RANGED). (BigWigsMods/LibSpecialization)
- `LibGroupInSpecT` overview — group-scoped, comms+inspect; "no way to detect when another player respecs." (WowAce)
- sArena source — `combatEvents` = SPELL_CAST_SUCCESS/AURA_*/INTERRUPT/DISPEL (DR/interrupt tracking); spec via `ARENA_PREP_OPPONENT_SPECIALIZATIONS`. (Sammers21/sArena_Updated2)
- WoWInterface/WeakAuras threads — `spellId` reinstated in Classic Era 1.15.0 (2023-11-14); class deducible from spellId mapping. (warcraft.wiki COMBAT_LOG_EVENT; WeakAuras2 #4763)
- combatlogforums "Classic WoW Spec Detection" — WCL's heal>dps role heuristic; hybrids/forms blur spec; no per-DPS-spec differentiation. (Kihra)
- Paranoia (wowinterface) — guesses nearby hostile class/level from observed abilities via combat log.

---

## Analysis

For **this** addon's need — a BG threat panel that must not call a DPS a healer — exact spec is overkill and, on Era, largely unobtainable in real time. The right altitude is **role**:

1. **Healer (CC priority).** Our current `confirmedHealer = heals > 0` is wrong: auto-attacks aside, *any* SPELL_HEAL source trips it — warriors (bandage/healthstone/potion), warlocks (Drain Life/Death Coil/healthstone), and Elemental shamans (self Healing Wave). The fix is the WCL heuristic, sharpened for instantaneous PvP: **healing cast on *allies* (destGUID ≠ sourceGUID) must exceed damage dealt.** Self-heals (the warrior/lock/ele noise) are excluded by the ally check; a real healer's output is dominated by ally healing. Ña (16.5k dmg / 2.6k heal, much of it self) → **not** a healer. ✔

2. **Caster vs melee DPS.** Once not-a-healer, split by damage school: magical schools (Nature/Fire/Frost/Shadow/Arcane/Holy) via `SPELL_DAMAGE`/`SPELL_PERIODIC_DAMAGE` vs Physical via `SWING_DAMAGE` + physical `SPELL_DAMAGE`. Predominantly-magical ⇒ **caster** (Elemental shaman, mage, warlock, shadow priest, balance druid); predominantly-physical ⇒ **melee/hunter**. This is the "AS heck Elemental" signal the user asked for — and it's robust because it uses *volume*, not a single rare talent cast.

3. **High-confidence spec override (optional).** A tiny `SIGNATURE_SPELL` table keyed by spellId→{class, spec/role} for unmistakable casts: Stormstrike⇒Enh-melee, Chain Heal/Greater Healing Wave on an ally⇒healer, Mind Flay⇒Shadow-caster, etc. When seen, lock the role at high confidence. Sparse but free precision on top of (1)+(2).

**Why not pure spell-signature (the arena way):** F2/F5 — the arena API doesn't exist on Era, and baseline-spell ambiguity means signatures are sparse and slow. Behaviour-first is faster, denser, and self-correcting.

---

## Recommendation

Extend the existing `Recorder` CLEU aggregate; do **not** add a parallel system. Per-enemy record gains:

```
damage         -- all damage (have)
healing        -- all effective healing (have)
healOthers     -- effective healing where destGUID ~= sourceGUID   (NEW)
magicDamage    -- effective damage from magical-school spells       (NEW)
physDamage     -- SWING + physical-school spell damage              (NEW)
sigRole        -- role locked by a SIGNATURE_SPELL cast, or nil     (NEW, optional)
```

Role resolution (used by `GetEnemyIntel` for the `Role` column + Announce):

1. `sigRole` if set (high confidence).
2. **Healer** if `healOthers > 0` and `healOthers >= damage`.
3. **Caster** if `magicDamage > physDamage` (and damage seen).
4. **Melee** if `physDamage >= magicDamage` (and damage seen).
5. Else **class-prior** (`HEALER_CAPABLE` ⇒ "heal?" guess; otherwise DPS) until evidence arrives.

Display: `HEAL✓` (confirmed) / `heal?` (prior) / `CASTER` / `MELEE` / `DPS`. Announce: keep KILL = top damage, CC = confirmed/likely healers (now correctly excluding casters).

This is a single, dense, locale-independent (school + GUID, no names) extension of code we already run.

---

## Risks

- **R1 (low):** a healer caught mid-wand/Shock could momentarily read damage>healOthers and show DPS; self-corrects as they heal. Acceptable — over-calling a healer is worse than briefly under-calling.
- **R2 (low):** `healOthers` needs `destGUID` (CLEU arg 8) — already in the payload; just unused today.
- **R3 (medium):** signature `spellId`s differ per rank and are unverified on Era → the override table needs a capture pass; ship behaviour-first (steps 2–5) without it.
- **R4 (low):** hybrid/transitional builds (Shockadin, feral-resto druid) blur role — inherent to Era, documented by WCL; behaviour ratio degrades gracefully.

---

## Action Items

- [ ] **Implement steps 1–2 + healer fix now** (behaviour-only, no new APIs): add `healOthers`, `magicDamage`, `physDamage` to the CLEU handler; replace `heals>0` with the ally-heal-dominance test; add CASTER/MELEE to the role tag. Unblocks the CMD-8 sub-bug. *(no in-game gate — pure CLEU arithmetic)*
- [ ] **Capture signature spellIds** via the recorder (log `spellId`+`spellName` for enemy SPELL_CAST_SUCCESS in a BG) to build the optional `SIGNATURE_SPELL` table — folds into VERIF-5.
- [ ] **Verify** `destGUID`-based `healOthers` and school flags in a live BG (`/dump CombatLogGetCurrentEventInfo()` shapes) before raising this to High.

---

## Sources

- [LibSpecialization (BigWigsMods)](https://github.com/BigWigsMods/LibSpecialization)
- [LibGroupInSpecT (WowAce)](https://www.wowace.com/projects/libgroupinspect)
- [sArena_Updated2 source](https://github.com/Sammers21/sArena_Updated2_by_sammers/blob/master/sArena.lua)
- [COMBAT_LOG_EVENT — Warcraft Wiki](https://warcraft.wiki.gg/wiki/COMBAT_LOG_EVENT)
- [WeakAuras2 #4763 — Classic spellId in CLEU](https://github.com/WeakAuras/WeakAuras2/issues/4763)
- [Classic WoW Spec Detection — Warcraft Logs forums (Kihra)](https://forums.combatlogforums.com/t/classic-wow-spec-detection/8369)
- [WeakAuras: Detect Enemy Player in the Combat Log — MMO-Champion](https://www.mmo-champion.com/threads/2161016-WeakAuras-Detect-Enemy-Player-in-the-Combat-Log)
- [Paranoia Enemy Player Alert — WoWInterface](https://www.wowinterface.com/downloads/info8660-ParanoiaEnemyPlayerAlert.html)
