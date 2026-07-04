# TitanBgGeneral — Backlog

> Source of truth for what gets built and in what order. Rules (from
> `Process/WorkingWithClaude.md`): only work the next unchecked item, one item =
> one commit, mark `[x]` the moment it's committed — not before. Items that
> depend on unverified WoW APIs get a research spike first.

**The vision:** the best Battleground General addon that ever existed — the
tool a leader opens to **advise and direct players in Warsong Gulch and Arathi
Basin**: fast callouts today, situational awareness and smart direction next.

---

## Bugs

- [x] **[BUG] Announce Threats — "Invalid escape code in chat message"** (2026-06-20) — `AnnounceThreats` joined its KILL/CC groups with `" | "`; a bare `|` in a `SendChatMessage` string is parsed as a chat escape code (`| ` is invalid) and the client rejects the whole message. Fixed: separate groups with `" // "` instead. Any future enemy-facing chat must avoid raw `|` (use `||` only if a literal pipe is truly needed).
- [x] **[BUG] Lua error on BG entry — `NewTicker` nil callback** (2026-06-14) — `ThreatProvider.Start` passed the global `RequestBattlefieldScoreData` straight to `C_Timer.NewTicker`; it was nil on the live Classic Era client → "bad argument #2 to '?'". First fired on the first live BG (WSG) since the threat skeleton landed. Fixed: resolve the request API at call time (global → `C_PvP` fallback), bail cleanly if absent, and wrap the ticker callback. Whether Era actually exposes the request API is a VERIF-3 question. (deployed 2026-06-14; confirm GREEN in WSG)

## Epic 0 — Process Bootstrap (2026-06-09)

Import the battle-tested collaboration process, adapted for WoW addon
development.

- [x] **[PROC-1] Process docs** — `Process/WorkingWithClaude.md`, `SmokeChecklist.md`, this backlog, `Research/RESEARCH-PROCESS.md`, `Design/` folder, CLAUDE.md wiring
- [x] **[PROC-2] Baseline smoke pass** — full `SmokeChecklist.md` run in-game on Classic Era, all rows pass (2026-06-09; see `Design/current-ab-panel-2026-06-09.png`)

## Epic 1 — Battleground Awareness (foundation)

The addon should know where it is. Everything "advisor" builds on this.

- [x] **[AWARE-1] Research: detecting the active battleground per flavor** — `IsInInstance()` + `GetInstanceInfo()` instanceMapID lookup on `PLAYER_ENTERING_WORLD`; covers WSG/AB/AV incl. retail variants (see `Research/bg-detection-reference.md`; retail IDs need in-game `/dump` — action items in the doc)
- [x] **[AWARE-2] Auto-select tab on zone-in** — `GetActiveBg()` (instanceMapID lookup) replaces the locale-fragile zone-name check; committed ahead of the in-game pass per user call — smoke row **W7 still needs verifying in AV/AB/WSG**, which also ticks the Era action items in `Research/bg-detection-reference.md`
- [x] **[AWARE-3] Auto-open option** — `autoOpen` SavedVariable (default on) + Titan-menu checkbox + `PLAYER_ENTERING_WORLD` handler opens on BG entry / closes on leave; menu checkbox eye-verified in-game (smoke row **W8 — the in-BG half — pending**, rides with W7 on the next BG trip)
- [x] **[AWARE-4] Context-aware Titan button text** — `GetButtonText()` via Titan's `buttonTextFunction`: green BG abbreviation on the bar inside WSG/AB/AV, icon-only outside; refreshed on `PLAYER_ENTERING_WORLD`. Clean load verified (smoke row **T5 in-BG half pending**, rides the BG-trip bundle)

## Epic 1.5 — Threat Advisor (pulled forward 2026-06-10)

Pulled ahead of the AB advisor per the market gap analysis
(`Research/addon-market-gap-research.md`): no addon on any flavor ranks enemy
threats or advises engage/avoid, the research is already done, it needs no
node-state plumbing, and it helps every player every match. Gated only on the
Era scoreboard `/dump` verify (Friday). **Skeleton landed 2026-06-10:**
ThreatProvider (10s ticker, healer inference, CC/KILL ranking) + `/bgthreat`
debug print, behind the clearly-marked `SCORE_POS` gate — Friday's dump fixes
the table if needed and flips it GREEN (smoke rows TP1/TP2).

- [x] **[CMD-5] Research: identifying the most dangerous enemy players** — answered: scoreboard-based ThreatProvider (`GetBattlefieldScore` damage/healing/classToken on a 10s ticker); healers inferred by class + healing ratio, no Era spec detection; includes the classic class rock/paper/scissors as shippable data (see `Research/enemy-threat-research.md` + `Research/classic-class-matchup-reference.md`; Era scoreboard shape needs Friday's `/dump` verify)
- [x] **[CMD-6] CC-priority callouts** (2026-06-20) — "Announce Threats" button on the Live Intel panel + `/bgthreat announce` send the deadliest enemies to BG chat via `GetChatType()`: KILL = top CLEU damage dealers, CC heal = healers (confirmed via heal events, or class-prior marked "?"). Built on the CLEU threat aggregate (the Era-real damage/healing source), not the always-0 scoreboard.
- [x] **[CMD-7] Engage/Avoid advisor** (2026-06-20) — ported the `MATCHUP[myClass][enemyClass]` table from `classic-class-matchup-reference.md`; `EngageAdvice()` resolves Engage/Avoid/CC (confirmed-healer overrides the matrix → "CC, don't chase"; Neutral renders as nothing). Surfaced as a **"You" column** in the merged window's enemy table (green Engage / red Avoid / cyan CC), updating on the live ticker — integrated into the table rather than a separate window.
- [x] **[CMD-8] Rework ThreatProvider ranking for Era** (2026-07-04) — Era scoreboard never populates `damageDone`/`healingDone` (always 0), so the old scoreboard ranking + `healing>1.5×damage` healer inference were dead on Era. Retired the dead `ThreatProvider` ranking (`SCORE_POS`/`Rebuild`/`ccList`/`killList`/`GetAdvisoryLine`) down to a lean **scoreboard poller** (keeps `GetEnemyIntel`/headcount fed even with the recorder off, post-release). Real danger order now lives in `GetEnemyIntel`/`IntelPanel`: healer-first (behaviour-first `ResolveRole` from [SPEC-1]), then real CLEU damage. Added a shared `BuildThreatLists` with a **cold-start fallback to scoreboard `killingBlows`** (a real Era field) so KILL callouts name the enemy's killers before CLEU damage accumulates; bare `/bgthreat` now prints this CLEU/KB ranking (`IntelPanel.GetAdvisoryLine`) instead of the dead scoreboard. **In-game GREEN PENDING** next live session. _Deferred to VERIF-5:_ verify school/`healOthers` CLEU shapes live + the optional `SIGNATURE_SPELL` deep-talent override.
  - _Progress (2026-06-20):_ CLEU aggregate now ranks real damage/healing live (Intel panel: aligned table, Heal column, post-match retention, reload persistence). **Healer sub-bug FIXED** via [SPEC-1] behaviour-first role inference (`ResolveRole`): healer = ally-healing (`destGUID≠src`) ≥ damage (drops the `heals>0` test that flagged Elemental shaman Ña + self-healing warriors/locks); CASTER vs MELEE by magic/physical damage school; `heal?` = class prior; legacy-snapshot fallback uses class-guarded healing dominance.
- [x] **[SPEC-1] Research: how addons detect enemy spec/role on Classic Era** (2026-06-20) — done: `Research/spec-detection-research.md`. Key finding: arena addons use `ARENA_PREP_OPPONENT_SPECIALIZATIONS` (arena-only, **absent on Era**) and group libs are group-only — neither sees BG enemies. Only path = **CLEU** (`spellId` back since 1.15.0), but vanilla baseline spells can't prove spec. Recommendation: **behaviour-first role inference** (WCL method) — healer = ally-healing > damage; caster vs melee by magical/physical school; optional signature-spell override. Unblocks the CMD-8 healer/spec sub-bug.
- [x] **[CMD-9] Nemesis database — persistent deadliest opponents + skull on load** (2026-06-20) — `Nemesis` module persists peak damage/healing + class/times-met/last-seen per enemy name under `TitanBgGeneralSaved.nemeses` (survives logout; capped at 300, least-recently-seen pruned). Banked at match end from the CLEU aggregate (`Recorder.Stop` → `Nemesis.Record`). `GetEnemyIntel` flags `e.nemesis = Nemesis.IsNemesis(name)` (peak dmg ≥ 15k) so the **skull shows the instant the scoreboard names a known nemesis**, before this match's combat data builds. Inspect/clear via `/bganalytics nemesis [clear]`. _v2 caveat:_ CLEU vs scoreboard name format (Name vs Name-Realm) can occasionally miss a match.

## Epic 1.6 — Auto-Verification Recorder (2026-06-13)

Every pending research gate (scoreboard shape, AB POI decode, WSG flag patterns,
Era instance IDs) is blocked on manual `/dump` runs mid-match — unrealistic in
practice. This epic bakes a passive recorder into the addon: events fire
automatically, raw data lands in `TitanBgGeneralSaved.Analytics`, and
`/bganalytics` prints a structured report after the session. One BG trip closes
every open research gate simultaneously.

Data sources investigated (2026-06-13): **Details!** exposes a real public API
(`Details:GetCurrentCombat()` → per-player `actor.total` damage/healing) and
works on Classic Era — the ThreatProvider should read from it when available.
**DBM-PvP / Capping** HP-sync channels carry NPC/boss CIDs only, not player HP
— not useful for player tracking. Node state and flag events are local-only;
no addon broadcasts them. See `Design/README.md` for the `TBG` addon message
channel design (player HP sharing between TBG users, inspired by DBM's
healthTracker architecture).

- [x] **[VERIF-1] Recorder scaffold** — `TitanBgGeneralSaved.Analytics` slot + `Analytics.Record(category, entry)` no-op-when-off helper for VERIF-2..6 + `/bganalytics [on|off|clear]` control surface; off by default, persists across `/reload`; no impact on existing functionality (GREEN 2026-06-14)
- [x] **[VERIF-2] Zone-in snapshot** — `Recorder.CaptureZone` (immediate + 3s re-check) logs `instanceMapID`/`uiMapID`/`name`/`recognizedBg` on any pvp instance. GREEN 2026-06-14: **WSG = instanceMapID 489, uiMapID 1460** (confirms `bg-detection-reference.md`). AB/AV Era IDs still want a trip.
- [x] **[VERIF-3] Scoreboard shape** — `Recorder` captures the full positional `GetBattlefieldScore(1)` return on first `UPDATE_BATTLEFIELD_SCORE`. GREEN 2026-06-14: 12-value Era shape decoded; **`SCORE_POS` confirmed correct** (faction=6, classToken=10, dmg=11, heal=12). 🔴 **Finding: Era never populates `damageDone`/`healingDone` (always 0)** → breaks the damage/healing ranking; see new [CMD-8]. Details in `enemy-threat-research.md`.
- [x] **[VERIF-4] AB POI logger** (2026-06-20) — `Recorder.CapturePOIs` snapshots the full POI list (`areaPoiID`, `name`, `textureIndex`) on `AREA_POIS_UPDATED` with baseline + changed-entry diffs. GREEN: a full AB match captured cleanly (uiMapID **1461**) and **confirmed the Era `textureIndex` decode table in-game** + filled in the neutral column (GM 16 / LM 21 / BS 26 / Farm 31 / Stables 36; +1..+4 = A-contested, A-controlled, H-contested, H-controlled; 64s cap timer observed). Decode: `node=floor((ti-16)/5)`, `state=(ti-16)%5`. See `Research/dbm-pvp-review-reference.md`. Unblocks AB-2/3/4/5.
- [ ] **[VERIF-5] WSG event capture** — on `CHAT_MSG_BG_SYSTEM_*` in WSG: `Analytics.Record` raw message + timestamp; on targeting a flag carrier: aura scan (`UnitAura` loop, capture name + spellID); confirms DBM's "Unused"-pattern caveat; unblocks WSG-2/3/4. **Capture into SavedVariables** (not `LoggingChat`): the chat log carries the same `/reload`-only flush requirement and is unstructured — one channel (recorder → SV → `/reload`) covers everything. See `project-addon-claude-comms-protocol` memory.
- [ ] **[VERIF-6] Details! enrichment** — **PROMOTED from optional**: with Era scoreboard damage/healing always 0 (VERIF-3 finding), `Details:GetCurrentCombat()` is the *only* damage/healing source on Era. If `Details` global present, read per-player `actor.total` in the ThreatProvider tick; degrade gracefully (class-prior only) if Details! absent.
- [x] **[VERIF-7] Developer panel + test buttons** (requested 2026-06-14) — `DevPanel` (`/bganalytics panel`): Toggle BG Analytics / Clear Log / Print Report / Reload UI / Close; status line shows recorder ON/OFF + entry count. Position + open-state persist under `TitanBgGeneralSaved.devPanel`. GREEN 2026-06-14 (survived a full WSG match + reloads).

## Epic 2 — AB Advisor

From "callout buttons" to "the addon tells you what to call".

- [x] **[AB-1] Research: reading AB node ownership and capture state per flavor** — answered: `C_AreaPoiInfo` + `AREA_POIS_UPDATED` works on all flavors incl. Era (see `Research/ab-node-state-research.md`); decode tables need one in-game `/dump` session — action items in the doc
- [x] **[AB-2] Node state strip** (2026-06-20) — `GetAbNodeStates()` decodes per-node owner/contested from the POI `textureIndex` (VERIF-4 table); a strip in the band between the tabs and the AB grid shows one marker per column (ST/GM/BS/LM/FM): blue **A** / red **H** / yellow **A!**/**H!** while contested / grey — neutral. Shown only on the AB tab, live on the 0.5s ticker.
- [x] **[AB-3] Capture timers** (2026-06-20) — while a node is contested, the AB-2 strip shows a ~64s capture countdown (Era cap time, VERIF-4) in place of the owner letter, faction-coloured by who's capturing (blue=Alliance, red=Horde). Timed from first-seen-assault on the 0.5s ticker (Era has no real `GetAreaPOITimeLeft`, so it's derived → approximate, resets if the window opens mid-assault). Clears back to the owner letter on capture/neutral.
- [x] **[AB-4] Smart callout enrichment** (2026-06-20) — AB grid callouts append live node state via `AbCalloutSuffix(abbr)` reading `GetAbNodeStates()`: `"4 INC Stables - Horde held"` or `"... - Alliance capping 0:18"` while contested (with the AB-3 derived countdown). Plain ASCII (chat-safe). `GetAbNodeStates` now owns the assault-timer (forward-declared so the callout + strip share one source).
- [x] **[AB-5] Advice engine v1** (2026-06-20) — `GetAbAdvice()` turns live base control into one actionable line, shown between the AB grid and the table (AB tab only, live): priority **DEFEND <node> - enemy capping M:SS!** (red) → **Behind N-N - attack <enemy node>** (yellow) → **Ahead N-N - hold & defend** (green) → **Even N-N - grab a 3rd base**. Reuses `GetAbNodeStates` (owner/contested/remain). v2 ideas: factor resource rate + pick the genuinely *weakest* enemy node.

## Epic 3 — WSG Advisor

- [x] **[WSG-1] Research: flag state tracking per flavor** — answered: events via `CHAT_MSG_BG_SYSTEM_*` pattern parsing (locale-dependent, enUS first); FC names only from pickup messages, aura check as locale-independent confirmation (see `Research/wsg-flag-state-research.md`; enUS patterns + aura IDs need in-game capture — action items in the doc)
- [x] **[WSG-2] FC status panel** (2026-07-04; **in-game GREEN PENDING**) — new `FlagState` provider (lands here per the research): parses `CHAT_MSG_BG_SYSTEM_{ALLIANCE,HORDE,NEUTRAL}` against the enUS pattern table (F8) into a two-flag state machine (base/carried/dropped + carrier name from the pickup message). Locale-independent aura recovery (Silverwing 23335 / Warsong 23333, F4) fills a name chat missed, wrapped for `C_UnitAuras`/`UnitAura`. `FlagState.GetView()` gives player-POV **EFC** (enemy carrying our flag) + **FFC** (ally carrying theirs), each with best-effort health (target/mouseover/nameplate unit → `UnitHealth`). Surfaced as a live WSG-tab status line in the strip band: red `EFC Name 45%` / blue `FFC Name` / muted "flag safe". Provider self-gated on `GetActiveBg()=="WSG"`, started/stopped from `PLAYER_ENTERING_WORLD`. _Caveats:_ names are enUS-only (degrades to aura-recovery elsewhere); health only when the carrier is a visible unit. **Verify next session:** run/defend a flag, watch the line track pickup/drop/capture + health. Confirms the F8 `dropped` named row + aura API flavour (VERIF-5 action items).
- [ ] **[WSG-3] FC-aware callouts** — "EFC <name> LOW — kill at our tunnel" built from live state instead of static text
- [ ] **[WSG-4] Flag respawn timers** — **12s respawn** (double-confirmed) + match-time widgets for endgame calls. _(2026-07-04 research: the original "Focused Assault stacks countdown" premise is **dead on Era** — those FC debuffs are a TBC 2.4.0 addition, excluded from Classic; F7 resolved in `wsg-flag-state-research.md`. Watch SoD/custom realms.)_

## Epic 3.5 — AV Panel (un-parked 2026-06-09)

User call: AV gets a panel too, alongside the WSG/AB advisor focus.

- [x] **[AV-1] AV grid tab** — third tab alongside AB/WSG: 7 columns (DB/IW/SH/SF/TP/IB/FW) × INC/DEF/HELP/CAP/GO/RECAP via the shared `BuildColGrid`; window sizes to the widest grid (smoke rows W5/W6/C5 green in-game 2026-06-09)
- [ ] **[AV-2] AV-specific callouts** — tune locations/actions for AV's flow (towers, GYs, bosses) once AV-1 is played with

## Epic 4 — Command & Control

Directing players, not just announcing. (CMD-5/6/7 — the threat advisor —
moved to Epic 1.5 on 2026-06-10, IDs kept.)

- [ ] **[CMD-1] Role assignment board** — assign raid members to nodes/roles (O/D, FC escort) and broadcast the plan
- [ ] **[CMD-2] Opening split caller** — one click sends the standard opener ("5 ST / 5 BS / rest GM" style presets, editable)
- [ ] **[CMD-3] Raid-marker integration** — mark FCs/targets when leader/assist
- [ ] **[CMD-4] Custom callout editor** — per-cell message editing persisted in SavedVariables

## Epic 6 — Persistent Enemy Intel (2026-07-03)

Extends the CMD-9 nemesis DB into a real cross-match **dossier**: remember each
enemy's *role* (not just peak damage) so the addon knows what to do to them by
name, accumulate it without loss, and brief the team from memory before the
gates open. Vision captured 2026-07-03 from a WSG post-match review.

- [x] **[INTEL-1] Enemy dossier — remember role, not just damage** (2026-07-04) — `Nemesis.Record` now persists the role signal (`healOthers` + `magicDamage`/`physDamage` peaks) alongside peak dmg/heal/met/last; `Nemesis.Lookup(name)` returns a CLEU-shaped remembered record (nil when never banked, and nil-passthrough on the role fields so legacy pre-INTEL-1 records fall to `ResolveRole`'s healing-dominance branch instead of misreading a healer as MELEE). `ResolveRole` forward-declared so the dossier classifies with the *same* logic the live panel uses (one source of truth). `GetEnemyIntel` falls back to `Lookup` when there's no live combat record, so role + engage/CC advice show **on sight** from the name alone (damage columns stay live-only). `IsNemesis` broadened: skull for peak dmg ≥ 15k **or** ally-healing ≥ 10k (healers were invisible to the damage-only gate). **GREEN 2026-07-04:** fresh multi-match dossier read from SavedVariables — healers (Infamous priest ho 11.7k, Necio resto shaman) tagged HEAL; **shadow priest Negradamus (37k dmg / 5.7k heal, ho 1.6k) correctly CASTER not HEAL** (the "any heal = healer" trap dodged on live data); casters/melee split by school. `/bganalytics nemesis` prints the role + healOthers per record.
- [x] **[INTEL-2] Never lose their fights — continuous banking** (2026-07-04; committed — **in-game GREEN PENDING** next live session) — the dossier was banked only in `Recorder.Stop` (leaving the BG), so a mid-match `/reload` or disconnect lost the whole match's accumulation (observed 2026-07-03: reloaded mid-WSG → `nemeses` still `{}`). Fix: split `Nemesis.Record` into an idempotent `Nemesis.Merge(threat, bumpMet)` (all-`math.max` stat peaks, safe to call repeatedly) plus a thin `Record` = `Merge(…, true)`; the 5s snapshot ticker now calls `Nemesis.Merge(threat)` (stats only) so the record survives reload/DC, while `met` still bumps exactly once at `Recorder.Stop`. A mid-match `/reload` re-enters via `Start` (not `Stop`), so it can't double-count `met`. **Verify next session:** play → `/reload` mid-match → confirm `nemeses` already populated (not `{}`) and `met` == number of matches, not tick count.
- [x] **[INTEL-3] Pre-match briefing from memory** (2026-07-04; committed — **in-game GREEN PENDING** next live session) — `IntelPanel.BuildBriefing()` scans the enemy roster (`GetEnemyIntel`), keeps only the **remembered** entries (`e.remembered` — met before), and buckets the actionable ones: healers → `CC:`, standing nemeses → `Focus: {skull}…`. Chat-safe (`" // "` separator + `{skull}` token, reusing the CMD-6 `AnnounceThreats` conventions), capped 4+4, returns nil when nobody known. `IntelPanel.ShowBriefing(broadcast)` prints locally (leader) or sends to team via `GetChatType()`. **Delivery decision (autonomous, outward-facing + untested):** auto path on BG entry (`PLAYER_ENTERING_WORLD`, 5s delay for roster, once-per-entry `preBriefed` guard) **prints LOCALLY only**; broadcasting to team is the explicit **`/bgthreat brief`** — no untested auto-spam to team chat. Flip to auto-broadcast once the wording is confirmed in-game. **Verify next session:** enter a BG with known enemies → local "Pre-match intel >>" line appears; `/bgthreat brief` sends it to team; tune the 5s roster delay if the line comes up empty. _Caveats:_ CMD-9 name-format (`Name-Realm` vs stored key) can miss a match; 5s may be short on slow loads.

## Epic 5 — Release Quality

- [ ] **[REL-1] Options panel** — Titan right-click → settings (auto-open, channel override, sounds)
- [ ] **[REL-2] Sound cues** — optional audio on critical advisor alerts
- [ ] **[REL-3] Multi-flavor verification pass** — full smoke checklist on retail and Cata Classic, flavor guards where APIs diverge
- [ ] **[REL-4] CurseForge release** — changelog, `.toc` version bump, packaging via `.pkgmeta`

## Parked / Ideas

- Eye of the Storm / Twin Peaks / Deepwind Gorge support (retail)
- Voice (TTS) callout playback for the leader
- **10v10 team-strategy advisor** (to discuss 2026-07-03) — read the whole enemy *and* friendly comp (both 10-player rosters), evaluate the team-level matchup, and suggest the best strat for it (opener split, who to focus, defend/offense balance). Team-composition scale, above the per-enemy `MATCHUP` 1v1 advice we already ship. Design conversation pending with the Admiral.
