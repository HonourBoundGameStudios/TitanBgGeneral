# 10v10 Team-Composition Strategy Advisor — Research

**Date:** 2026-07-04
**Author:** Away team (general-purpose agent)
**Status:** Draft
**Confidence:** Per-section (Half A API = Medium, gated on in-game `/dump`; Half B strategy theory = Medium/Low by nature)
**Flavors verified:** none in-game yet — Half A rests on other addons' source + this repo's existing verified positions; Half B is web-sourced game-knowledge. No new `/dump` performed for this doc.
**Supersedes:** nothing

---

> The TEAM-level layer that sits **above** the shipped per-enemy 1v1 advice
> (`classic-class-matchup-reference.md` → `MATCHUP` in `TitanBgGeneral.lua`).
> Where `MATCHUP` answers "should *I* fight *that* enemy", this answers
> "given BOTH full 10-man rosters, what should the *raid* do" — opener split,
> focus list, D/O balance, FC pick. Reuses the existing roster plumbing; adds a
> comp-reduction + rule layer on top. This is the market gap
> `addon-market-gap-research.md` F6 calls the empty "data-driven direction"
> quadrant (no addon on any flavor advises at comp scale).

## Executive Summary

The addon already reads **both** rosters it needs — it just never compares them
at the team level:

- **Ours (friendly 10):** the CMD-1 Battle Plan board's `GroupMembers()`
  (`TitanBgGeneral.lua:2301`) already returns `{name, class}` for the whole
  raid via `IsInRaid()`/`GetRaidRosterInfo(i)` (and party/solo fallbacks).
  Locale-independent class tokens, no new API.
- **Theirs (enemy 10):** `CaptureRoster()` (`:643`) already decodes the
  scoreboard into `{name, classToken, faction, KBs, deaths}` for every player
  of both factions. On Era `damageDone`/`healingDone` are **0** (verified
  2026-06-14, `enemy-threat-research.md`), so enemy *class counts* are solid
  but enemy *role* must be **inferred** (`ResolveRole` + `HEALER_CAPABLE`
  class prior; CLEU sharpens it for enemies seen in combat).

From those two rosters we reduce each side to a **comp signature**
(class counts, inferred healer count, role split, FC candidates), diff the two
signatures, and run a small per-BG rule table to emit a recommended plan. The
single most load-bearing input is the **healer differential** (ΔH = ourHealers
− theirHealers): every WSG/AB strategy source ties aggression vs turtle to who
can out-sustain a teamfight. FC pick (WSG) is a class-priority lookup
(Druid > Warrior-with-healer > Hunter/Mage). Focus list is: **enemy healers
first**, then FC-capable / high-threat classes — which is exactly the
ThreatProvider's existing CC-then-KILL ordering, lifted to the pre-game roster.

Proposed data model, algorithm, and a ready-to-port Lua rule sketch are in
**Recommendation**. Nothing here needs a new Blizzard API; the open questions
are all "does this *existing* call return what we think on Era" — enumerated in
**Action Items**.

## Research Question

Given BOTH 10-player rosters in a Classic-Era WSG or AB match — our raid and
the enemy team — how do we (a) read them locale-independently, (b) reduce each
to a comparable team-composition signature using **classToken + inferred role
only** (no spec on Era), and (c) turn `(ourComp, theirComp, BG)` into a
concrete recommended strategy: opener split, focus-target list, defense/offense
balance, and flag-carrier pick?

## Constraints

- **classToken + inferred role only.** No enemy spec on Era
  (`spec-detection-research.md` F2/F5). Comp math keys on the 9 class tokens
  and a behaviour-/prior-inferred role; never on localized `class`/`race`/spec.
- **Enemy dmg/heal = 0 on Era** (`enemy-threat-research.md` in-game finding,
  2026-06-14). Enemy healer *count* comes from the class prior refined by CLEU
  heal events for enemies seen in combat — NOT from the scoreboard. Our own
  side has no such limit (we can read party/raid units directly).
- **Advisory only.** Output is text (a window line or a chat callout through
  the existing `GetChatType()` path). The addon never targets, assigns, or
  automates — it advises the leader.
- **Locale independence** — a hard project rule; keys are the 9 tokens
  `WARRIOR PALADIN HUNTER ROGUE PRIEST SHAMAN MAGE WARLOCK DRUID`.
- **Faction structure** — Era has no Horde Paladins, no Alliance Shamans; a
  side's healer-capable set is `{PRIEST, DRUID}` + (`PALADIN` xor `SHAMAN`).
- **Gated on being in a BG** — same lifecycle as the shipped providers
  (register while `GetActiveBg() ~= nil`).
- **Soft output** — comp→plan is heuristic; render as advice, not fact, with a
  confidence marker (mirrors the `MATCHUP` "silence beats false precision"
  rule).

## Findings

### HALF A — Technical (WoW API, Classic Era first)

#### A1 — Our friendly 10 is already read, locale-independently (Confidence: High for the API; the code ships and runs)

`GroupMembers()` (`TitanBgGeneral.lua:2301-2317`) already produces the friendly
roster the advisor needs:

- `IsInRaid()` → loop `GetRaidRosterInfo(i)` for `i = 1..GetNumGroupMembers()`;
  its **6th return is the locale-independent class file token** (`fileName`,
  e.g. `"WARRIOR"`). This is the intended path in a BG (a BG group is a raid).
- Non-raid fallback: `UnitName("player")` + `select(2, UnitClass("player"))`,
  then `party1..N` via `UnitExists`/`UnitClass`. `UnitClass`'s 2nd return is
  the same class token — locale-independent.

So class counts for OUR side are free and reliable. The advisor should call the
same helper (or a lifted copy) — do **not** re-derive roster reading.

#### A2 — Our own ROLE is knowable far better than the enemy's; but the group role API is unreliable on Era (Confidence: Medium — flag for `/dump`)

For OUR side we can, in principle, know role three ways, best-first:

1. **`UnitGroupRolesAssigned(unit)`** → `"TANK"|"HEALER"|"DAMAGER"|"NONE"`.
   This is the LFG/role-check assignment. On **Classic Era there is no talent
   spec and no LFR role system**, so this very likely returns `"NONE"` for
   everyone (the function exists but has nothing to populate it). **Must be
   `/dump`-verified in an Era BG before relying on it** — if it returns
   `"NONE"`, drop it entirely. (Confidence Low that it is useful on Era.)
2. **Class prior** — `HEALER_CAPABLE[classToken]` (already defined at `:1784`):
   `PRIEST/DRUID/PALADIN/SHAMAN`. Gives "how many *potential* healers" — an
   over-count (a shadow priest / boomkin / feral is not a healer).
3. **Live behaviour** — for our own party/raid we *could* read talents or auras
   of friendly units (inspect is allowed on same-faction group members), but
   that is heavier than the advisor needs. Recommendation: **treat our healer
   count as the class-prior count, optionally corrected by the leader** (a
   Plan-board toggle), not by an API. Comp advice tolerates ±1 healer.

Net: OUR healer count = `HEALER_CAPABLE` count, presented as "up to N healers",
leader-adjustable. Do not block on `UnitGroupRolesAssigned`.

#### A3 — The enemy 10 is already read; class counts solid, role inferred (Confidence: High for class counts, Medium for inferred healer count)

`CaptureRoster()` (`:643`) already walks `GetNumBattlefieldScores()` /
`GetBattlefieldScore(i)` with the **verified** `SB` positions (`:592`, confirmed
in-game 2026-06-14): `classToken=10`, `faction=6` (0=Horde/1=Alliance). Enemy =
`faction ~= myFaction`. That yields **enemy class counts** at High confidence,
locale-independent, for the whole enemy team map-wide.

Enemy **role** cannot come from the scoreboard on Era (dmg/heal = 0). It comes
from, in order:
- **Class prior** (`HEALER_CAPABLE`) → "likely healers" count — always
  available, an over-count.
- **CLEU refinement** for enemies seen in combat — `ResolveRole` (`:1826`)
  already returns `HEAL`(confirmed) / `CASTER` / `MELEE` / `heal?`(prior) from
  the `Recorder` aggregate (`healOthers`, `magic/physDamage`). The Nemesis DB
  (`:480`) even recalls a role across matches for repeat opponents.

So the enemy healer count is a **class-prior ceiling, tightened downward** as
CLEU confirms/denies specific players. Early game it is the prior; mid-game it
sharpens. This is acceptable for comp advice (which cares about the *count*,
not which exact player).

#### A4 — Both signatures reduce to the same shape; the diff is trivial (Confidence: High — pure arithmetic on A1/A3)

Given a roster list of `{classToken, role?}`, reduce to a **comp signature**:
`counts[classToken]`, `healers` (int), `meleeDPS`/`rangedDPS`/`casterDPS`
(role split), `fcCandidates` (ordered class list present). Both sides use the
identical reducer; only the *source* of `role` differs (ours = prior/leader,
theirs = prior+CLEU). The team-level diff (ΔH, ΔmeleeCount, FC-class presence)
is then plain subtraction — no API, no locale, no per-flavor branch.

### HALF B — Game-knowledge (comp → plan, web-sourced; Medium/Low by nature)

#### B1 — Offense/Defense separation is THE structuring principle in WSG (Confidence: Medium)

Every WSG guide frames the raid as two assigned teams: an **offense** stack
(healers + flag runner + CC/control — "move across the field as an unstoppable
force, grab the flag and return") and a **defense** group ("almost all pure
DPS, burst or CC — sole job is to stop the enemy cap / kill their FC"). Healers
concentrate on offense with the FC; defense is disruption (slow/interrupt/stun)
[S1, S3, S6]. This is the skeleton the comp fills.

#### B2 — Healer differential drives aggressive-cap vs turtle (Confidence: Medium)

"Protecting your healers while eliminating enemy healers creates opportunities
to wipe enemy teams and gives your team the initiative to capture" [S1]. The
team that can out-sustain the mid teamfight gets flag initiative. Reading the
sources into a rule:

- **ΔH ≥ +2 (we out-heal them):** press — stack offense, run the flag, win the
  attrition fight. Turtling wastes a sustain edge.
- **ΔH ≤ −2 (they out-heal us):** turtle — heavy FC-defense, deny their cap,
  farm their GY / win on a single lucky pickup; do not feed the mid fight.
- **|ΔH| ≤ 1 (even):** standard split, decide on the FC-class edge (B3) and
  who lands the first kill.

#### B3 — FC pick is a class-priority ladder; comp changes escort size (Confidence: Medium-High for the ladder, Medium for thresholds)

Consensus FC ladder [S1, S3, S7 / `classic-class-matchup-reference.md` F7]:

1. **Druid** — best FC (shapeshift breaks snares/roots/poly, travel-form
   speed, bear survivability). If we have a Druid, it is the FC.
2. **Warrior + pocket healer** — "one of the most dangerous combos in Classic";
   a Warrior FC is top-tier *only if a healer escorts him* (Berserker Rage
   breaks fear). No healer → don't pick the Warrior FC.
3. **Mage / Hunter** — mobility/kiting FCs when no Druid; weaker under focus.
4. Fallback: any class, minimal — but flag more defense to compensate.

Escort size scales **inversely** with FC survivability and **with** enemy melee
pressure: a Druid FC needs 1 healer + 1 peel; a Warrior FC needs ≥1 dedicated
healer or the pick is wrong; heavy enemy melee (rogues/warriors) → add a peeler.

#### B4 — AB is a 3-node hold with minimal backline defenders; comp sets node allocation (Confidence: Medium)

AB consensus [S2, S8, S9, `dbm-pvp-review-reference.md`]: **hold the 3 nodes
nearest your GY**, put **minimal defenders (often 1) on the safe/backline
nodes**, and **mass the rest at the contested front node** (usually
Blacksmith — central, fastest to reinforce either flank). The "5-5-5" three-
group frame is the coordination unit. Comp drives the allocation:

- More **ranged/casters** → better *defenders* (they hold a node and peel
  incoming from range) and better front-node control (AoE/CC on the cap point).
- More **melee/mobility** → better *roamers / re-cappers* (fast rotation
  between the backline node and the front).
- **Healer count** sets how many bodies the *front* fight can sustain: high
  ΔH → over-commit the front and take a 4th node; low ΔH → collapse to 3 and
  defend, win on resource rate (the DBM bases-to-win math).

#### B5 — Focus-target priority: enemy healers first, then FC-capable / high threat (Confidence: Medium-High)

Universal across sources and already the addon's ThreatProvider ordering:
**CC/kill enemy healers first** (removing sustain is the force-multiplier),
then the **enemy FC / FC-capable classes** (Druid, mobile Warrior) and
high-burst DPS. This is the pre-game, roster-level version of what
`GetEnemyIntel()` already computes live (CC list then KILL list). The comp
layer's contribution: name the *classes to watch* before combat data exists
(e.g. "enemy has 3 priests + 1 druid — focus priests, skull the druid FC").

#### B6 — Comp archetypes worth naming (Confidence: Low — synthesis, not a single source)

Reducing the ΔH + role-split diff to a handful of leader-facing archetypes:

| Their comp shape | Plan headline |
|---|---|
| Healer-heavy (≥3 healers) | Turtle / kill-their-healers; expect a long game |
| Melee-heavy, few healers | Aggressive cap; peel their melee off our FC; they fold when focused |
| Caster/ranged-heavy | Close distance, LoS their casters, they're squishy in melee |
| Balanced (mirror) | Standard split; win on execution + first pick |

## Evidence

| # | Claim | Source |
|---|---|---|
| E1 | Friendly raid roster + class token via `IsInRaid`/`GetRaidRosterInfo(i)` (6th ret = class file) | `TitanBgGeneral.lua:2301-2317` (shipped) |
| E2 | Enemy roster + classToken(10)/faction(6) via scoreboard; positions verified Era 2026-06-14 | `TitanBgGeneral.lua:592-596, 643-668`; `enemy-threat-research.md` in-game findings |
| E3 | Enemy dmg/heal = 0 on Era → role must be inferred, not read | `enemy-threat-research.md` (VERIF-2/3, 2026-06-14) |
| E4 | No enemy spec on Era; role = behaviour/prior inference | `spec-detection-research.md` F2/F5/F6 |
| E5 | `HEALER_CAPABLE` = PRIEST/DRUID/PALADIN/SHAMAN; faction split removes one/side | `TitanBgGeneral.lua:1784`; `enemy-threat-research.md` F5 |
| E6 | `ResolveRole` already yields HEAL/CASTER/MELEE/heal? from CLEU aggregate | `TitanBgGeneral.lua:1826-1850` |
| E7 | WSG = offense stack (healers+FC+CC) vs defense (DPS/CC to stop the cap) | S1, S3, S6 |
| E8 | Protecting own healers + killing enemy healers = flag initiative | S1 |
| E9 | Druid best FC; Warrior FC top-tier only with a pocket healer | S1, S3, S7; `classic-class-matchup-reference.md` F7 |
| E10 | AB = hold nearest 3 nodes, 1 on backline, mass the front (BS); 5-5-5 frame | S2, S8, S9; `dbm-pvp-review-reference.md` |
| E11 | Focus enemy healers first, then FC/high-threat | S1, S3; `enemy-threat-research.md` Recommendation |
| E12 | `UnitGroupRolesAssigned` exists but LFG roles unlikely populated on Era | Wiki + reasoning — **unverified, Action Item** |

## Analysis

The feature is unusually cheap because **both rosters are already in memory** —
the shipped code reads the friendly group (CMD-1) and the enemy scoreboard
(CMD-8) independently; nobody has ever *diffed* them. The whole feature is a
reducer (`roster → signature`) plus a rule table (`ourSig, theirSig, bg → plan`).
No new Blizzard API, no new event, no new frame required for a v1 (the output
can ride the existing Plan board or a chat callout).

The error bars live entirely in two places, and they are asymmetric:

1. **Enemy healer count (Half A).** The class prior over-counts (shadow priest,
   boomkin, feral all read as "healer-capable"). This biases the advice toward
   *caution* (turtle), which is the safe direction — the same asymmetric-cost
   logic the `MATCHUP` doc uses (a wrong "turtle" wastes tempo; a wrong "press"
   loses the game). CLEU tightens the count downward as the match unfolds, so
   the advice *improves* over the first few minutes exactly when it matters
   less (opener is already committed).
2. **Comp→plan mapping (Half B).** This is soft game-knowledge (Medium/Low).
   The healer-differential rule (B2) and the FC ladder (B3) are the two highest-
   consensus, highest-leverage heuristics — ship those with confidence; ship the
   node-allocation and archetype layers (B4/B6) as softer "suggested" text.

Crucially, this layer **composes** with what already ships: the comp advisor
sets the *plan* (press/turtle, FC, split), and the live `MATCHUP` +
`GetEnemyIntel` handle *execution* (who each player engages, who to CC now). The
comp layer is the missing top of that stack, and per `addon-market-gap-research.md`
F6 nothing on any flavor occupies it.

## Recommendation

### 1. Data model — the comp signature

```lua
-- Reduce EITHER roster (list of {classToken, role?}) to one signature.
-- Ours: role from HEALER_CAPABLE prior (+ optional leader correction).
-- Theirs: role from prior, tightened by CLEU/ResolveRole where seen.
-- role in {"HEALER","MELEE","RANGED","CASTER","DPS"}; nil => infer from class.
local RANGED_CLASSES = { HUNTER = true }                       -- physical ranged
local CASTER_CLASSES = { MAGE = true, WARLOCK = true, PRIEST = true } -- + shadow/boomkin ambiguous
local MELEE_CLASSES  = { WARRIOR = true, ROGUE = true }        -- PALADIN/SHAMAN/DRUID hybrid
-- FC ladder: lower index = better carrier (see B3)
local FC_LADDER = { "DRUID", "WARRIOR", "HUNTER", "MAGE" }

local function CompSignature(roster)              -- roster = { {classToken=, role=}, ... }
    local sig = { counts = {}, healers = 0, melee = 0, ranged = 0, caster = 0,
                  size = 0, fc = {}, confirmedHealers = 0 }
    for _, p in ipairs(roster) do
        local c = p.classToken
        if c then
            sig.counts[c] = (sig.counts[c] or 0) + 1
            sig.size = sig.size + 1
            local role = p.role
            if role == "HEALER" or (role == nil and HEALER_CAPABLE[c]) then
                sig.healers = sig.healers + 1
                if role == "HEALER" then sig.confirmedHealers = sig.confirmedHealers + 1 end
            elseif role == "CASTER" or CASTER_CLASSES[c] then sig.caster = sig.caster + 1
            elseif role == "RANGED" or RANGED_CLASSES[c] then sig.ranged = sig.ranged + 1
            else sig.melee = sig.melee + 1 end
        end
    end
    for _, fcClass in ipairs(FC_LADDER) do
        if (sig.counts[fcClass] or 0) > 0 then sig.fc[#sig.fc + 1] = fcClass end
    end
    return sig
end
```

`sig.healers` is the class-prior ceiling; `confirmedHealers` is the CLEU-tight
floor. Advice keys on `healers` (conservative) and notes when
`confirmedHealers` disagrees. Building the two rosters reuses **A1** (ours) and
**A3** (theirs) verbatim — no new reading code.

### 2. Algorithm — (ourSig, theirSig, bg) → plan

```
dH        = ourSig.healers - theirSig.healers          -- healer differential
ourFC     = ourSig.fc[1]                                -- best carrier we have
theirFC   = theirSig.fc[1]
haveHealer= ourSig.healers > 0

-- (a) POSTURE  (B2) — the master switch
if     dH >=  2 then posture = "PRESS"    -- out-sustain: stack offense, run flag / take 4th node
elseif dH <= -2 then posture = "TURTLE"   -- out-healed: defend, deny cap, win on resource/single pick
else                 posture = "STANDARD" -- even: normal split, win on execution

-- (b) FOCUS LIST  (B5) — classes to watch, healers first
focus = [ enemy healer-capable classes present, ordered by count desc ]
        ++ [ theirFC if FC-capable ]         -- "skull their druid"
     -- live GetEnemyIntel() refines to named players once CLEU has data

-- (c) FC PICK (WSG)  (B3)
if bg == "WSG":
    if ourFC == "DRUID" then fc = "Druid", escort = 1 healer + 1 peel
    elseif ourFC == "WARRIOR" and haveHealer then fc = "Warrior + healer", escort = 1 dedicated healer
    elseif ourFC in {"HUNTER","MAGE"} then fc = ourFC (kite), escort = +1 defense
    else fc = "any", escort = "extra defense"
    -- no healer at all → downgrade posture one step toward TURTLE

-- (d) D/O SPLIT
if bg == "WSG":      -- of 10
    base = { PRESS = {O=7,D=3}, STANDARD = {O=6,D=4}, TURTLE = {O=3,D=7} }[posture]
    if theirSig.melee >= 5 then D += 1  (peel-heavy enemy → more FC defense)
elif bg == "AB":     -- of 15 (AB is 15v15) — node allocation, not raw O/D
    hold = 3 nearest nodes; backline nodes get 1 defender each;
    front node (BS) gets the mass; PRESS => contest a 4th node, TURTLE => collapse to 3 + defend;
    prefer casters/ranged as node defenders, melee/mobility as roamers/re-cappers  (B4)
```

Decision thresholds (all tunable constants): healer diff **±2** flips
press/turtle; enemy melee **≥5** adds a WSG defender; **no friendly healer**
forces a posture step toward turtle and blocks the Warrior-FC pick. These are
starting values for the leader to calibrate — the doc's confidence in the
*direction* is higher than in the exact integers.

### 3. Shippable Lua-ready rule tables (keyed by classToken / posture)

```lua
-- Per-BG posture → D/O and headline. WSG counts of 10; AB expressed as node policy.
local COMP_PLAN = {
    WSG = {
        PRESS    = { off = 7, def = 3, line = "Press: stack offense, run the flag, out-heal them mid." },
        STANDARD = { off = 6, def = 4, line = "Standard split: win the first pick, then push." },
        TURTLE   = { off = 3, def = 7, line = "Turtle: defend the FC, deny their cap, farm their GY." },
    },
    AB = {
        PRESS    = { hold = 3, contest = 1, backline = 1, line = "Hold 3, contest a 4th, mass Blacksmith." },
        STANDARD = { hold = 3, contest = 0, backline = 1, line = "Hold nearest 3, 1 on backline, mass BS." },
        TURTLE   = { hold = 3, contest = 0, backline = 2, line = "Collapse to 3, defend, win on resource rate." },
    },
}

-- FC ladder → carrier plan (WSG). requiresHealer gate is load-bearing (B3).
local FC_PLAN = {
    DRUID   = { conf = "High",   escort = "1 healer + 1 peel", requiresHealer = false, note = "Shapeshift breaks snares/poly." },
    WARRIOR = { conf = "Medium", escort = "1 DEDICATED healer", requiresHealer = true,  note = "Top-tier ONLY with a pocket healer." },
    HUNTER  = { conf = "Medium", escort = "+1 defense",          requiresHealer = false, note = "Kite carrier; weak under focus." },
    MAGE    = { conf = "Medium", escort = "+1 defense",          requiresHealer = false, note = "Blink/Nova carrier; squishy." },
}

-- Enemy comp archetype → leader headline (B6). Evaluated on theirSig.
-- conf Low — synthesis; render as a suggestion, never a fact.
local ENEMY_ARCHETYPE = {
    HEALER_HEAVY  = { test = "healers >= 3",          line = "Healer-heavy: kill their healers, expect a long game." },
    MELEE_HEAVY   = { test = "melee >= 5 & healers<2", line = "Melee-heavy, thin healing: aggressive cap, peel them off our FC." },
    CASTER_HEAVY  = { test = "caster+ranged >= 5",     line = "Ranged-heavy: close distance & LoS their casters — they're squishy." },
    BALANCED      = { test = "otherwise",              line = "Balanced: standard split, win the first pick." },
}
```

Per-rule confidence: `COMP_PLAN` postures = **Medium** (B2/B4);
`FC_PLAN` ladder & `requiresHealer` gate = **Medium-High** (B3);
`ENEMY_ARCHETYPE` = **Low** (B6 synthesis — ship as softest text or behind a
toggle). The numeric split constants are **starting guesses**, explicitly
leader-tunable.

### Integration notes

- **Reuse, don't rebuild:** call the existing `GroupMembers()` for ours and
  `CaptureRoster()`'s output (or `GetEnemyIntel()`) for theirs; feed both
  through `CompSignature`. `ResolveRole` already supplies enemy `role`.
- **Surface** on the CMD-1 Plan board (a "Suggested plan" line + posture) and/or
  as a one-shot chat callout through `GetChatType()` — button-press only, never
  automatic (the existing chat-spam discipline).
- **Compose, don't duplicate:** this sets the plan; the live `MATCHUP` /
  `GetEnemyIntel` handle per-target execution. Show one caveat line:
  *"Comp guidance — healer counts are estimated (class-based), tightens as the
  fight develops."*
- **Cold-start honesty:** before CLEU data, enemy healers = class prior
  (over-count) → advice leans cautious by design.

## Risks

- **Enemy healer count is a prior, not a fact** — over-counts shadow/boomkin/
  feral as healers; biases toward turtle (safe direction). CLEU tightens it but
  only for enemies seen in combat and only after a few minutes — i.e. *after*
  the opener is already committed. Mitigation: the `(likely)` marker + the
  caveat line; lean on `confirmedHealers` when it disagrees.
- **`UnitGroupRolesAssigned` probably useless on Era** — if it returns `"NONE"`
  (very likely, no LFG roles in vanilla), OUR healer count also falls back to
  the class prior. Not a failure, just less precision. **Gated on `/dump`.**
- **Comp→plan is soft (Medium/Low)** — sources are guides/wikis/theorycraft, no
  objective data. The healer-diff and FC-ladder heuristics are the robust core;
  node-allocation and archetype layers are softer and should render as
  suggestions. Skill/gear/premade-coordination dominate real outcomes.
- **AB is 15v15, WSG is 10v10** — the "10-player" framing in the task is exact
  for WSG only; the AB signature size is 15 and the plan is node-allocation, not
  a raw O/D count. The rule tables above already branch on `bg` for this.
- **Faction hybrids blur the role split** — Paladin/Shaman/Druid land in the
  "melee else" bucket by default; that under-counts casters/healers on those
  classes. Acceptable for a count-level heuristic; documented.
- **Retail/Cata untested** — everything here is Era-first. On retail the enemy
  scoreboard *does* carry role/spec (`C_PvP.GetScoreInfo`), which would make the
  enemy signature exact — a strict improvement, but out of scope and unverified.

## Action Items — in-game `/dump` to raise Half A to High

- [ ] **`UnitGroupRolesAssigned`** — in an Era BG raid, run
      `/run for i=1,GetNumGroupMembers() do print((GetRaidRosterInfo(i)), UnitGroupRolesAssigned("raid"..i)) end`
      — confirm whether it returns anything but `"NONE"`. If all `"NONE"`, drop
      it from the model (rely on the class prior). **This is the one gate.**
- [ ] **Confirm `GetRaidRosterInfo` 6th return = class token in an Era BG**
      (`"WARRIOR"` etc., not localized) — near-certain from shipped use, but
      verify once alongside the above.
- [ ] **Enemy healer-count sanity check** — mid-match, compare the class-prior
      enemy healer count (`HEALER_CAPABLE` over `CaptureRoster()`) against how
      many `ResolveRole` has flagged `HEAL` — calibrate how badly the prior
      over-counts (drives whether the archetype thresholds need tuning).
- [ ] **AB roster size** — `/dump GetNumBattlefieldScores()` in a live AB
      confirms 15/side, validating the WSG(10) vs AB(15) branch.
- [ ] Leader sanity-check the posture thresholds (±2 healer diff, ≥5 melee) and
      the D/O split integers against real premade experience (mirrors the
      `MATCHUP` "Richard sanity-checks" item).

> **Note (repo convention):** per this repo, `CLAUDE.md` is **gitignored**
> (`git check-ignore CLAUDE.md` → ignored). The RESEARCH-PROCESS step "add a row
> to the CLAUDE.md Research table" therefore lands as a **local-only** change —
> it will not be committed/pushed with the rest. Flagging so the table row isn't
> assumed to travel with the doc. The doc file itself IS tracked and commits
> normally.

## Sources

- S1 — Icy Veins, *Warsong Gulch PvP Battleground Guide (Classic)* —
  https://www.icy-veins.com/wow-classic/warsong-gulch-pvp-battleground-guide
  (offense/defense separation; protect-your-healers = flag initiative; FC combos)
- S2 — Icy Veins, *Arathi Basin PvP Battleground Guide (Classic)* —
  https://www.icy-veins.com/wow-classic/arathi-basin-pvp-battleground-guide
- S3 — Ten Ton Hammer, *Warsong Gulch Tactics Guide* —
  https://www.tentonhammer.com/guides/warsong-gulch-tactics-guide
  (offense = healers+runner+CC; defense = pure DPS/CC to stop the cap)
- S6 — Wowpedia, *Warsong Gulch strategy* —
  https://wowpedia.fandom.com/wiki/Warsong_Gulch_strategy
- S7 — XPOff, *Jwl's Guide To Flag Carrying* —
  https://xpoff.com/threads/jwls-guide-to-flag-carrying-everything-you-need-to-know.91697/
- S8 — WoWWiki archive, *Arathi Basin strategy* (5-5-5, 4-4-4-3, node hold math) —
  https://wowwiki-archive.fandom.com/wiki/Arathi_Basin_strategy
- S9 — Wowhead, *Arathi Basin Battleground Strategy (Classic)* —
  https://www.wowhead.com/classic/guide/arathi-basin-battleground-strategy-wow-classic
- Internal: `Research/classic-class-matchup-reference.md` (1v1 layer, FC/BG
  modifiers F7), `Research/enemy-threat-research.md` (enemy roster read;
  dmg/heal 0 on Era; CC-then-KILL ordering), `Research/spec-detection-research.md`
  (no enemy spec on Era; behaviour-first role), `Research/addon-market-gap-research.md`
  (comp-scale advice is the empty market quadrant, F6),
  `Research/dbm-pvp-review-reference.md` (AB resource/bases-to-win math),
  `TitanBgGeneral.lua` (`GroupMembers` :2301, `CaptureRoster` :643, `SB` :592,
  `HEALER_CAPABLE` :1784, `MATCHUP`/`EngageAdvice` :1792, `ResolveRole` :1826,
  `GetEnemyIntel` :1857, `Nemesis` :480)
```
