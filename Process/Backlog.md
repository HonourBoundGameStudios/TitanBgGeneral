# TitanBgGeneral — Backlog

> Source of truth for what gets built and in what order. Rules (from
> `Process/WorkingWithClaude.md`): only work the next unchecked item, one item =
> one commit, mark `[x]` the moment it's committed — not before. Items that
> depend on unverified WoW APIs get a research spike first.

**The vision:** the best Battleground General addon that ever existed — the
tool a leader opens to **advise and direct players in Warsong Gulch and Arathi
Basin**: fast callouts today, situational awareness and smart direction next.

> **Completed items** live in `Process/Archive.md` (last sweep **2026-07-04** —
> the whole AB/WSG/AV callout+advisor stack, the threat/intel/nemesis engine, the
> recorder, and the CMD/REL command tools). The 2026-07-04 batch shipped
> **committed but in-game-GREEN-pending**; its verification checklist is
> `Process/bg-trip-2026-07-04.md`. A failed verification returns as a new `[BUG]`.

---

## Bugs

- _(none open)_

## Epic 1.6 — Auto-Verification Recorder (2026-06-13)

The passive in-client recorder that closes research gates from real matches
(events → `TitanBgGeneralSaved.Analytics` → `/bganalytics` report). Scaffold +
zone/scoreboard/AB-POI capture + dev panel all shipped (see `Archive.md`); these
two remain.

- [ ] **[VERIF-5] WSG event capture** — on `CHAT_MSG_BG_SYSTEM_*` in WSG: `Analytics.Record` raw message + timestamp; on targeting a flag carrier: aura scan (`UnitAura` loop, capture name + spellID); confirms DBM's "Unused"-pattern caveat; unblocks WSG-2/3/4. **Capture into SavedVariables** (not `LoggingChat`): the chat log carries the same `/reload`-only flush requirement and is unstructured — one channel (recorder → SV → `/reload`) covers everything. See `project-addon-claude-comms-protocol` memory. _(Also the home for CMD-8's deferred school/`healOthers` live-shape check + the optional `SIGNATURE_SPELL` override.)_
    - **Status (2026-07-04):** message-capture half **in-game GREEN** — 43-message Era WSG sample; **named-drop research question RESOLVED** (Era names the dropper; `[Ff]lag` casing split confirmed; see `Research/wsg-flag-state-research.md`). Aura-scan half shipped + deployed but **not yet exercised** (couldn't target a carrier before match end); one remaining check: target an EFC/FFC in a WSG → `/reload` to log the `C_UnitAuras` vs `UnitAura` API + spellID. Dev-panel **WSG** LED added (eyeball pending — no screenshot yet).
- [ ] **[VERIF-6] Details! enrichment** — **PROMOTED from optional**: with Era scoreboard damage/healing always 0 (VERIF-3 finding), `Details:GetCurrentCombat()` is the *only* damage/healing source on Era. If `Details` global present, read per-player `actor.total` in the ThreatProvider tick; degrade gracefully (class-prior only) if Details! absent.
    - **Status (2026-07-04):** shipped + deployed, **committed GREEN-pending**. Added `DetailsProvider` (feature-guarded + `pcall`'d; API verified against the installed Details source: `GetCurrentCombat()` → `GetContainer(1|2)` → `ListActors()` → `actor.nome`/`.total`) and blended its totals into `GetEnemyIntel` (the single funnel for the intel table + `/bgthreat` + announce) via `max(CLEU, Details)`. **In-game GREEN check owed:** in a BG with Details! loaded, an enemy you never personally hit should now show real Dmg/Heal (was 0 pre-build); Details-tracked healers get a confirmed HEAL role. Degrade path (Details absent → CLEU/class-prior) is guaranteed by guards but unexercised. Screenshot of the Intel table = evidence + table UI eyeball.

## Epic 3.5 — AV Panel (un-parked 2026-06-09)

User call: AV gets a panel too, alongside the WSG/AB advisor focus. The grid tab
shipped (AV-1 → `Archive.md`); the callout tuning remains.

- [ ] **[AV-2] AV-specific callouts** — tune locations/actions for AV's flow (towers, GYs, bosses) once AV-1 is played with

## Epic 5 — Release Quality

REL-1 (options panel) + REL-2 (sound cues) shipped this session (→ `Archive.md`,
pending in-game GREEN). These close out the epic.

- [ ] **[REL-3] Multi-flavor verification pass** — full smoke checklist on retail and Cata Classic, flavor guards where APIs diverge
- [ ] **[REL-4] CurseForge release** — changelog, `.toc` version bump, packaging via `.pkgmeta`

## Epic 7 — Team-Comp Strategy Advisor (2026-07-04)

The team-composition layer ABOVE the shipped 1v1 `MATCHUP`: diff both rosters,
recommend a raid-level plan. Research: `Research/team-comp-strategy-research.md`.
**Design decided with the Admiral 2026-07-04** — surface on the `/bgplan` Battle
Plan board; evaluate at match start then live-refine; v1 ships the robust core
only (soft archetype/node layer held for v2).

- [ ] **[TEAM-1] Comp-signature engine (pure logic)** — `CompSignature(roster)` reducer (class counts, healer count via `HEALER_CAPABLE` prior + `confirmedHealers` from `ResolveRole`, melee/ranged/caster split, FC ladder) fed by the *existing* readers (`GroupMembers` ours, `CaptureRoster`/`GetEnemyIntel` theirs — do NOT re-derive roster reading). `ComputeTeamPlan(ourSig, theirSig, bg)` → `{posture, fc, focus, split}` from `COMP_PLAN`/`FC_PLAN` tables: ΔH master switch (±2), FC ladder + `requiresHealer` gate, focus = enemy healers then FC. Debug surface `/bgcomp` prints the plan (RED→GREEN without UI). **In-game gate first:** `/dump UnitGroupRolesAssigned` in an Era BG raid — if all `"NONE"`, our healer count = class prior (expected). Branch **AB=15v15** vs WSG=10.
    - **Status (2026-07-04):** engine shipped + deployed; `GroupMembers` lifted to file scope (now shared, single-source with the Plan board). **Pure-logic core GREEN-verified dry** — 28/28 assertions via a standalone `lua` harness (posture switch, FC ladder + healer gate, no-healer nudge, confirmed-vs-prior healer counting, focus ordering, melee bump, AB branch). **Owed in-game (glue):** `/bgcomp` in a live WSG/AB prints a sensible plan; + the `UnitGroupRolesAssigned` `/dump` gate (expected `"NONE"` → class prior). No UI yet — that's TEAM-2.
- [ ] **[TEAM-2] Plan board "Suggested Plan" section** — render the TEAM-1 plan on the `/bgplan` board (posture + reason, FC + escort, focus list, O/D split), class-coloured; **Broadcast** (one-shot to BG chat via `GetChatType()`) + **Refresh** buttons; caveat line "healer counts estimated, tightens as the fight develops". Live-refine on the board's ticker. UI/UX-reviewer pass required (screenshot).
    - **Status (2026-07-04):** shipped + deployed **blind, committed GREEN-pending**. Headline section at the top of `/bgplan`: semantic posture colour (green PRESS / gold STANDARD / orange TURTLE), reason + healer read (`heal N v M, ±d, k confirmed`), class-coloured FC + escort, O/D split (WSG), focus list, muted caveat; a **Broadcast Plan** button (plain-ASCII ` // ` to BG chat) distinct from the assignment Broadcast; disabled + shows the reason when no plan (AV/no-BG/roster-not-loaded). Live-refine = the existing **Refresh** (board rebuilds wholesale; no OnUpdate added to a rebuild-everything window). **OWED in-game:** `ui-ux-reviewer` pass on a `/bgplan` screenshot (spacing/wrap of the new lines is unverified — built without a client) + functional GREEN (real plan renders, Broadcast Plan sends).
- v2 (deferred): soft `ENEMY_ARCHETYPE` headlines + AB node-allocation detail; leader-tunable thresholds; optional toggle.

## Parked / Ideas

- _(none)_
