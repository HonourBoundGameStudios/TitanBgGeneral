# Classic Era Class-vs-Class Matchup Matrix — Reference

**Date:** 2026-06-09
**Author:** Claude (research agent)
**Status:** Draft
**Confidence:** Medium — community-consensus game-balance knowledge, inherently soft; per-cell confidence noted below
**Flavors verified:** n/a — game-balance knowledge, not API. Sources are 1.12 vanilla / Classic (2019) era; Era 1.15.x uses the same 1.12 balance.

---

> Companion to `enemy-threat-research.md` (who is dangerous, from scoreboard
> data). This document answers the orthogonal question: **given an enemy's
> classToken, should THIS player engage or avoid them?** Output feeds the
> planned per-player ENGAGE/AVOID window.

## Executive Summary

Vanilla 1v1 PvP has a real but soft rock/paper/scissors layer. The famous,
high-confidence edges: **Mage and Warlock counter Warrior** (kiting / fear
chains), **Rogue counters cloth** (opener stunlock, especially Priest and
non-SL Warlock), **Paladin counters Rogue and Warlock but loses to Mage**
(the vanilla "dueling triangle": Reckoning Paladin > SL Warlock > Frost Mage >
Paladin), **Hunter counters everything at range but is the worst class in
melee** (dead zone), and **healer-capable classes stalemate each other**.

Roughly a third of the 36 distinct pairings are genuinely contested in the
sources — driven by spec (SL vs non-SL Warlock, feral vs resto Druid), gear,
racials (WOTF), and who opens. Since Era exposes **class only, never spec**
(established in `enemy-threat-research.md` F4), contested cells must ship as
**Neutral** and the addon should present the lists as advice, not fact.

The deliverable matrix (E/N/A per row class) and a ready-to-port `MATCHUP`
Lua table keyed by `classToken` are in **Recommendation**.

## Research Question

For each of the 9 vanilla classes, which enemy classes does the community
consensus say they counter (Engage), go even with (Neutral), or are countered
by (Avoid), at level 60, 1.12-era balance — expressible as data keyed by the
locale-independent `classToken`?

## Constraints

- **Class token only.** No enemy spec detection exists on Era
  (`enemy-threat-research.md` F4). Cells that flip on spec must take the
  conservative call (Neutral, or Avoid if the dangerous spec is common).
- **Locale independence** — keys are `WARRIOR, PALADIN, HUNTER, ROGUE,
  PRIEST, SHAMAN, MAGE, WARLOCK, DRUID`.
- **Faction split** — Era has no Horde Paladins and no Alliance Shamans.
  PALADIN appears only in a Horde player's enemy list; SHAMAN only in an
  Alliance player's. The 9x9 matrix is complete anyway (the addon indexes
  `MATCHUP[myClass][enemyClass]`; impossible pairs simply never occur, except
  PALADIN-vs-SHAMAN, which *does* occur cross-faction).
- **Advisory only** — output is text in a window/chat line; soft guidance.

## Findings

Per-cell confidence: **High** = famous hard counter, multiple independent
sources agree; **Medium** = 2+ sources agree, some dissent or strong
gear/skill dependence; **Low/Contested** = sources directly disagree or the
answer flips on spec/racial — shipped as Neutral.

### F1 — The vanilla dueling triangle: Paladin > Warlock > Mage > Paladin (Confidence: High)

Multiple sources name the same "holy trinity of duels": Reckoning Paladin
beats Soul Link Warlock (bubble breaks fear, heals outlast DoTs), SL Warlock
beats Frost Mage ("almost impossible to beat an SL lock as a mage" —
Nostalrius; "dominate Mages" — AOEAH), Frost Mage beats Paladin (kite the
plate with no gap closer or snare). [S1, S2, S5]
Dissent: Icy Veins' Classic Frost Mage section claims frost is "in an
excellent position to beat a Warlock" — minority view, applies mostly to
non-SL locks; consensus stays Warlock-favored. [S8, S9]

### F2 — Warrior: king of teamfights, countered 1v1 by kiters and fear (Confidence: High for Mage/Warlock counters)

- **Mage hard-counters Warrior** — "one of the few duels where a mediocre
  mage can beat a world-class warrior" (Nostalrius); "warriors are countered
  hard by mages" (Blizzard forum thread). [S2, S3]
- **Warlock counters Warrior** — fear chains + DoTs; the textbook fear-bait
  matchup. Caveat: Berserker Rage, fear-break racials/trinkets, and deep gear
  narrow it; one Blizzard-forum poster even claims warriors "dominate"
  warlocks — minority, gear-premade context. [S2, S3, S8]
- **Rogue vs Warrior contested** — classic consensus leans Rogue (opener
  stunlock + Evasion), but the same forum thread claims warriors dominate
  rogues; heavily gear-dependent (Medium-Low, lean Rogue). [S3, S6]
- Warrior is favored vs Shaman (Hamstring + Mortal Strike: "the second they
  charge ... pretty much game over for you as a shaman" — Wowhead Ele Shaman
  guide) and leans favored vs Priest and Druid (MS halves healing). [S7, S3]

### F3 — Hunter: strongest at range, worst in melee (Confidence: High for the duality itself; most Hunter cells contested)

The dead zone (5–8 yd, no shots, no melee) makes Hunter the most
context-dependent class in the game. At max range with Viper Sting, Hunters
beat mana users (Priest, Mage, Paladin, Warlock per one set of claims); hugged
in the dead zone they lose to competent melee. [S3, S4, S10, S11]

- Hunter vs Rogue: **directly contested** — Wowhead's Hunter guide says a
  Survival Hunter "hard counters" Rogues (pets track stealth, kiting); a
  dedicated Hunter dueling guide calls the Rogue the Hunter's *worst*
  matchup ("beating a good Rogue is harder than beating two ret Paladins").
  Neutral. [S4, S11]
- Hunter vs Warrior: contested — "Hunters have an advantage against
  Warriors" vs "Hunters lose to Warriors who can close distance". Neutral,
  range decides. [S3, S4]
- Hunter vs Warlock: consensus leans Warlock — "Hunters slowly but surely
  always die to a Warlock" (Nostalrius), though "Hunters counter ... Locks if
  they can kite" appears too. Avoid (Medium-Low). [S2, S3]
- Hunter vs Mage: lean Hunter at 60 (Viper Sting + range > Nova/CoC; "mages
  are countered by hunters" — WoWWiki), but "pretty bad" before gear; Neutral
  (lean Engage at range). [S4, S12]
- Hunter is clearly favored vs Paladin (kite plate with no gap closer) and
  vs Priest (Viper Sting mana drain at range). (Medium) [S3, S5]

### F4 — Rogue: counters cloth openers, countered by plate (Confidence: High for both poles)

- **Rogue > Priest**: "if you catch a Priest without his shields up, the
  fight is already yours — stunlock him and kill him". High — *except* Undead
  priests (WOTF), see F6. [S13, S14]
- **Rogue > Warlock (non-SL)**: "a Rogue is a Warlock's natural enemy"
  (vanilla wiki) — but "Rogues struggle against SL Warlocks" (AOEAH). Spec
  is invisible on Era → Neutral, lean Engage. [S1, S15]
- **Paladin > Rogue**: "rogues are countered hard by paladins" — plate,
  bubble, Reckoning. High. [S1, S3]
- Rogue vs Mage: contested — Wowhead's Rogue guide leans Mage-favored
  ("once you deleted his cooldowns he's dead meat" — from the Mage side),
  most others call it "whoever opens wins". Neutral. [S6, S12]
- Rogue vs Shaman: lean Rogue ("Rogues defeat Shamans" — Blizzard forum);
  resto is "usually a draw" (Wowhead). Medium-Low. [S3, S7]
- Rogue vs Druid: contested and spec-dependent — feral bear-form riding out
  the stunlock wins per player reports (mostly later-expansion evidence);
  vanilla feral is weaker. Neutral. [S16]

### F5 — Healer-capable classes stalemate each other; Priest is the anti-caster (Confidence: Medium)

Paladin/Priest/Druid/Shaman pairings mostly end in nobody-dies stalemates →
Neutral. The exception: **Priest beats Mage** (dispel barriers/poly, Mana
Burn, fear: "mages have HARD times against shadow priests ... even disc/holy
priests can beat mages") and **Priest leans over Druid** (dispel every HoT,
Mana Burn). Shaman leans over Mage (high HP pool, Grounding Totem, Earth
Shock: "elemental shamans are super tough for mages"). [S12, S13, S7]

### F6 — WOTF and faction racials distort every fear/CC-based counter (Confidence: High)

Will of the Forsaken (Undead: break/immune Fear, Charm, Sleep on a 5s window)
flips fear-dependent cells when the enemy is Forsaken:

- Undead Priest vs Rogue: WOTF + Devouring Plague makes this the classic
  "rogue-killer" — the Rogue-favored call weakens badly Alliance-side
  (Alliance rogues fight many UD priests). [S14]
- Undead anything vs Warlock: fear chains (the Warlock's main counter
  mechanic) lose a link; "WOTF breaks fears and seduces, amazing in
  Priest/Lock matchups". [S14]
- Era cannot read enemy race from the scoreboard ranking loop cheaply
  (race return is localized; GUID→`GetPlayerInfoByGUID` gives race tokens via
  CLEU only) — so racials are a **stated caveat in the UI**, not data.

Faction structure: PALADIN rows/columns only matter for Horde users, SHAMAN
only for Alliance users, except Paladin-vs-Shaman which is a real
cross-faction cell (Neutral).

### F7 — Battleground context ≠ duel context (Confidence: Medium-High)

The matrix is duel logic; AB/WSG skirmishes modify it:

- **Warrior flips from "countered by kiters" to top-tier** with a pocket
  healer — "Warriors are juggernauts ... highest potential burst ... should
  be paired with a healer" (Icy Veins WSG guide). An ENGAGE call on an enemy
  Warrior is wrong if his healer is alive — which is exactly why the
  ThreatProvider's CC-the-healer list comes first.
- **Hunter plays at range in BGs**, so his duel-weak melee cells matter less;
  his ranged-favored cells matter more.
- **Mage value in BGs is control, not kills** (peeling for the FC beats
  winning a 1v1); Druid is the premier WSG flag carrier (shapeshift breaks
  snares/poly) — an "Avoid Druid" cell never means "don't attack the Druid
  FC". [S17]
- Consumables (Free Action Potion, Living Action Potion, trinkets,
  engineering) routinely override class counters in premades: "engineering
  makes some classes ultimate pvp gods since it covers weaknesses". [S3]

### F8 — Worst spec-ambiguity cells (class-only data must be conservative) (Confidence: High that ambiguity exists)

| Cell | Flip | Conservative call shipped |
|---|---|---|
| anyone vs DRUID | feral (fightable) vs resto (unkillable stalemate) | Neutral except famous edges (Mage-A, Warlock-E, Priest-E) |
| ROGUE/MAGE vs WARLOCK | SL lock ≈ unbeatable; non-SL lock dies | Neutral (Rogue), Avoid (Mage — even non-SL is dangerous to cloth at range) |
| anyone vs PRIEST | shadow (kill target) vs disc/holy (stalemate) | Keep duel call; healer-detection from ThreatProvider ratio rule refines it at runtime |
| melee vs HUNTER | MM/SV kiter vs undergeared | Neutral for Warrior/Rogue (range decides) |
| vs WARRIOR | arms-MS (healing cut) vs fury | Minor — calls unchanged |

Note the synergy: the **ThreatProvider's healer inference** (heal/damage
ratio, `enemy-threat-research.md` F5) is effectively runtime spec detection
for the Druid/Priest/Shaman/Paladin ambiguity — a Druid flagged `isHealer`
can be re-labeled "FC/stalemate — don't chase" regardless of this matrix.

## Evidence

All evidence is web-community material (Low-Medium tier per
RESEARCH-PROCESS source ranking — no in-game verification possible for
balance claims). Cross-checking: every E/A cell below is supported by ≥2
independent sources; cells with direct disagreement are marked N.

Access note: Wowhead guide bodies, Fandom wikis, GameFAQs, and Warcraft
Tavern blocked direct fetching (CloudFront 403); their content was obtained
through search-result extracts. The Nostalrius forum was unreachable (502)
during research; its claims come via search extracts of threads S2/S2b.
This is a known weakness — see Risks.

| # | Claim | Source |
|---|---|---|
| E1 | Dueling triangle: Reck Pala > SL Lock > Frost Mage > Pala | S1, S2, S5 |
| E2 | Mage hard-counters Warrior | S2, S3, S12 |
| E3 | Warlock counters Warrior via fear (with WOTF/gear dissent) | S2, S3, S8 |
| E4 | Paladin hard-counters Rogue | S1, S3 |
| E5 | Rogue beats Priest (opener) / beats non-SL Warlock | S13, S15, S6 |
| E6 | Hunter dead zone = worst melee class; strongest at max range | S4, S10, S11 |
| E7 | Hunter-vs-Rogue directly contested (hard counter vs worst matchup) | S4 vs S11 |
| E8 | Warrior favored vs Shaman (Hamstring + MS) | S7, S3 |
| E9 | Shaman/Priest favored vs Mage; Druid counters Mage (shapeshift) | S7, S12, S13, S3 |
| E10 | Warlock beats Hunter "slowly but surely"; toughest fight for Shaman | S2, S7 |
| E11 | WOTF flips fear-based cells (UD priest vs Rogue/Warlock) | S13, S14 |
| E12 | BG modifiers: Warrior+healer top tier, Mage = control, Druid = FC | S17 |
| E13 | Spec/engineering/consumables override class counters | S3, S2 |

## Analysis

The signal is real but has wide error bars. Cells split into three bands:

1. **Famous counters (≈10 cells, High)** — Mage/Warlock > Warrior,
   Paladin > Rogue/Warlock, Mage > Paladin, Warlock > Mage, Rogue > Priest,
   Hunter > Paladin/Priest-at-range, Warrior > Shaman. These survive
   skill/gear variance well enough to ship as hard E/A.
2. **Lean cells (≈12, Medium)** — agreed direction, real dissent or strong
   condition (range, spec, racial). Shipped as E/A but the UI should render
   them softer than band 1 if it ever distinguishes.
3. **Contested (≈14, Low)** — direct source disagreement or spec-flip.
   Shipped as Neutral; listing them as E or A would be false precision.

For an addon, the asymmetric cost matters: a wrong **ENGAGE** call gets the
player killed; a wrong **AVOID** call only wastes an opportunity. Hence every
contested cell resolves toward Neutral-or-Avoid, never toward Engage.

The matrix's biggest blind spot (healer vs DPS spec) is exactly what the
ThreatProvider already infers at runtime — combining `MATCHUP` with the
`isHealer` flag covers the worst ambiguity without any new API.

## Recommendation

### (a) 9x9 matrix — row = your class, cell = call on that enemy

`E` = Engage (favored) `N` = Neutral/contested `A` = Avoid (countered).
`*` = contested or spec/racial-dependent — see F8/F6. Mirror cells are N.

| vs → | WAR | PAL | HUN | ROG | PRI | SHA | MAG | LOCK | DRU |
|---|---|---|---|---|---|---|---|---|---|
| **WARRIOR** | N | N | N\* | A\* | E | E | A | A | E\* |
| **PALADIN** | N | N | A | E | N | N | A | E | N |
| **HUNTER** | N\* | E | N | N\* | E | N | N\* | A\* | N |
| **ROGUE** | E\* | A | N\* | N | E | E | N\* | N\* | N\* |
| **PRIEST** | A | N | A | A\* | N | N | E | N\* | E |
| **SHAMAN** | A | N | N | A\* | N | N | E | A | N |
| **MAGE** | E | E | N\* | N\* | A | A | N | A\* | A |
| **WARLOCK** | E | A | E\* | N\* | N\* | E | E | N | E |
| **DRUID** | A\* | N | N | N\* | A | N | E | A | N |

High-confidence cells (famous counters): WARRIOR row MAG/LOCK = A;
MAGE row WAR/PAL = E, LOCK = A; PALADIN row ROG = E, MAG = A;
ROGUE row PRI = E, PAL = A; WARLOCK row WAR/MAG = E, PAL = A;
HUNTER row PAL = E. Everything else Medium or lower.

### (b) Ready-to-port Lua

```lua
-- Classic Era (1.12 balance) class-vs-class advice, keyed by classToken.
-- E(ngage) = favored = listed in .favored; A(void) = countered = .avoid;
-- everything absent = Neutral/contested (no call).
-- Soft data: duel logic; see classic-class-matchup-reference.md for BG
-- modifiers (pocket healers, WOTF, consumables) and contested cells.
local MATCHUP = {
    WARRIOR = {
        favored = { "PRIEST", "SHAMAN", "DRUID" },   -- MS halves heals; Hamstring locks Shaman down
        avoid   = { "MAGE", "WARLOCK", "ROGUE" },    -- kited (Mage), fear-chained (Lock), stunlocked (Rogue, contested)
    },
    PALADIN = {                                      -- Alliance-only; appears for Horde users
        favored = { "ROGUE", "WARLOCK" },            -- plate+bubble+Reckoning beats Rogue; bubble breaks fear, outlasts Lock
        avoid   = { "MAGE", "HUNTER" },              -- no gap closer or snare: kited to death
    },
    HUNTER = {
        favored = { "PALADIN", "PRIEST" },           -- kite plate; Viper Sting drains the healer at range
        avoid   = { "WARLOCK" },                     -- DoTs+fear outlast pet and kiting (contested but lean Lock)
        -- WARRIOR/ROGUE/MAGE contested: you win at range, lose in the dead zone
    },
    ROGUE = {
        favored = { "PRIEST", "WARRIOR", "SHAMAN" }, -- opener stunlock kills cloth; Evasion beats Warrior (gear-dep.); Shaman can't escape
        avoid   = { "PALADIN" },                     -- plate, stuns eaten by bubble/Reckoning
        -- WARLOCK contested (SL=unbeatable, non-SL=free); UD Priest (WOTF) flips PRIEST cell
    },
    PRIEST = {
        favored = { "MAGE", "DRUID" },               -- dispel barriers/poly/HoTs + Mana Burn + fear
        avoid   = { "WARRIOR", "ROGUE", "HUNTER" },  -- MS cuts heals; opener stunlock; Viper Sting at range
        -- WARLOCK contested (WOTF Undead priest hard-counters; otherwise Lock-favored)
    },
    SHAMAN = {                                       -- Horde-only; appears for Alliance users
        favored = { "MAGE" },                        -- big HP pool, Grounding Totem, Earth Shock interrupts
        avoid   = { "WARRIOR", "WARLOCK", "ROGUE" }, -- Hamstring+MS; fear+Coil+Felhunter; stunlock (contested: resto draws)
    },
    MAGE = {
        favored = { "WARRIOR", "PALADIN" },          -- the textbook kite victims: no snare-break, no ranged threat
        avoid   = { "WARLOCK", "PRIEST", "SHAMAN", "DRUID" }, -- SL lock outlasts; dispel+Mana Burn; Grounding+HP; shapeshift breaks poly/nova
    },
    WARLOCK = {
        favored = { "WARRIOR", "MAGE", "SHAMAN", "DRUID", "HUNTER" }, -- fear chains + DoTs outlast all of them
        avoid   = { "PALADIN" },                     -- bubble breaks fear, heals outlast DoTs (Reckoning triangle)
        -- ROGUE/PRIEST contested (your SL spec / their WOTF decide it)
    },
    DRUID = {
        favored = { "MAGE" },                        -- shapeshift breaks Polymorph/Nova/Frostbite; roots+heals win
        avoid   = { "WARRIOR", "PRIEST", "WARLOCK" }, -- MS cuts heals; dispels every HoT + Mana Burn; fear is undispellable for you
        -- ROGUE contested (bear-form ride-out vs perfect stunlock)
    },
}
```

Integration notes:

- Index as `MATCHUP[playerClassToken]` where
  `local _, playerClassToken = UnitClass("player")` — locale-independent.
- Render contested/neutral as silence (no entry in either list) — false
  precision is worse than no advice.
- When the ThreatProvider flags an enemy `isHealer`, override this matrix
  with the healer call ("CC, don't chase") regardless of cell.
- Surface one static caveat line in the window tooltip: *"1v1 logic — back
  off if their healer is up; WOTF breaks fear-based picks."*

## Risks

- **Source quality ceiling** — all claims are forum/guide consensus
  (Low-Medium evidence tier); no objective matchup statistics exist for
  vanilla. Two key sources (Wowhead dueling guide bodies, Nostalrius threads)
  could only be read through search extracts because the sites blocked
  direct fetching — extracts may lose nuance.
- **Skill and gear variance dominates** — "vanilla is fairly balanced at
  1v1; top players of any class beat mediocre players of other classes"
  (Nostalrius). The matrix predicts equal-skill, comparable-gear fights only.
- **Era ≠ 2005** — 1.15.x Era uses 1.12 numbers, but the playerbase is
  min-maxed (everyone has the right spec, consumables, engineering), which
  systematically strengthens band-1 counters (SL locks, Reck pallies are
  *more* common now) and weakens "bad player" outs.
- **Duel logic in a teamfight** — every cell assumes 1v1; the single biggest
  real-world override is the enemy pocket healer (F7), which this data
  cannot see — only the ThreatProvider can.
- **Racial distortion is invisible to the data layer** — WOTF cells (F6)
  ship wrong for Undead enemies; mitigated by the caveat line only.

## Action Items

- [ ] **Richard sanity-checks the matrix** against his own Era BG experience —
      especially the contested cells (Warrior-vs-Rogue, Hunter-vs-anything,
      Rogue-vs-Warlock, Shaman-vs-Rogue) and the Avoid lists for his own class.
- [ ] Decide UI treatment of Neutral (hide vs grey "even") and whether
      band-1 vs band-2 confidence is rendered differently.
- [ ] Wire the healer-override: `isHealer` from the ThreatProvider trumps
      `MATCHUP` (re-label "CC / don't chase").
- [ ] Optional v2: CLEU race detection (`GetPlayerInfoByGUID` race token) to
      suppress fear-based ENGAGE picks against Undead enemies.
- [ ] Add this file to the `CLAUDE.md` research table on acceptance.

## Sources

- S1 — AOEAH, *WoW Classic PvP Tier List (1v1 Duels, BGs, Open World)* —
  https://www.aoeah.com/news/3662--wow-classic-pvp-tier-list--best-pvp-classes-for-1v1-duels-bgs-open-world
- S2 — Nostalrius forum, *What are the hard counters to every class?* (1.12-era player consensus) —
  https://forum.nostalrius.org/viewtopic.php?f=46&t=20250 (site unreachable during research; claims via search extracts)
- S2b — Nostalrius forum, *Best classes for 1v1 and wpvp* —
  https://forum.nostalrius.org/viewtopic.php?f=46&t=37955
- S3 — Blizzard US forums, *PvP counters in World of Warcraft Classic* —
  https://us.forums.blizzard.com/en/wow/t/pvp-counters-in-world-of-warcraft-classic/176528
- S4 — Wowhead, *Classic Hunter PvP Dueling Guide* —
  https://www.wowhead.com/classic/guide/hunter-dps-pvp-dueling-classic-wow
- S5 — Wowhead, *Classic Retribution Paladin PvP Dueling Guide* —
  https://www.wowhead.com/classic/guide/paladin-dps-pvp-dueling-classic-wow
- S6 — Wowhead, *Classic Rogue PvP Dueling Guide* —
  https://www.wowhead.com/classic/guide/rogue-dps-pvp-dueling-classic-wow
- S7 — Wowhead, *Classic Elemental / Enhancement Shaman PvP Dueling Guides* —
  https://www.wowhead.com/classic/guide/elemental-shaman-dps-pvp-dueling-classic-wow ,
  https://www.wowhead.com/classic/guide/enhancement-shaman-dps-pvp-dueling-classic-wow
- S8 — Icy Veins, *Classic Warlock PvP Guide* (fetched directly) —
  https://www.icy-veins.com/wow-classic/classic-warlock-pvp-guide
- S9 — Wowhead, *Classic Mage PvP Dueling Guide* —
  https://www.wowhead.com/classic/guide/mage-dps-pvp-dueling-classic-wow
- S10 — Vanilla WoW Wiki (Fandom), *Dead zone* —
  https://vanilla-wow-archive.fandom.com/wiki/Dead_zone
- S11 — OwnedCore, *[Guide] Serious Hunter Duel Guide* —
  https://www.ownedcore.com/forums/world-of-warcraft/world-of-warcraft-guides/124927-guide-serious-hunter-duel-guide.html
- S12 — WoWWiki archive (Fandom), *Mage PvP guide* —
  https://wowwiki-archive.fandom.com/wiki/Mage_PvP_guide
- S13 — Vanilla WoW Wiki (Fandom), *Priest PvP guide* —
  https://vanilla-wow-archive.fandom.com/wiki/Priest_PvP_guide
- S14 — Icy Veins, *Classic Priest PvP Guide* (WOTF / Devouring Plague racial notes) —
  https://www.icy-veins.com/wow-classic/classic-priest-pvp-guide
- S15 — Vanilla WoW Wiki (Fandom), *Warlock PvP guide* —
  https://vanilla-wow-archive.fandom.com/wiki/Warlock_PvP_guide
- S16 — MMO-Champion, *Feral druid vs Rogue* (player reports; later-expansion bias noted) —
  https://www.mmo-champion.com/threads/694360-Feral-druid-vs-Rogue
- S17 — Icy Veins, *Warsong Gulch PvP Battleground Guide* (BG class roles) —
  https://www.icy-veins.com/wow-classic/warsong-gulch-pvp-battleground-guide
- Related internal: `Research/enemy-threat-research.md` (spec undetectable on
  Era; healer-inference ratio rule), `Research/RESEARCH-PROCESS.md`
