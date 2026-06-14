# TitanBgGeneral — Backlog

> Source of truth for what gets built and in what order. Rules (from
> `Process/WorkingWithClaude.md`): only work the next unchecked item, one item =
> one commit, mark `[x]` the moment it's committed — not before. Items that
> depend on unverified WoW APIs get a research spike first.

**The vision:** the best Battleground General addon that ever existed — the
tool a leader opens to **advise and direct players in Warsong Gulch and Arathi
Basin**: fast callouts today, situational awareness and smart direction next.

---

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
- [ ] **[CMD-6] CC-priority callouts** — surface the top-threat enemies (healers first) from the ThreatProvider and call them for crowd control / kill targets ("CC Kruelhand — healer"), reusing the one-implementation-many-surfaces callout path
- [ ] **[CMD-7] Engage/Avoid advisor window** (requested 2026-06-09) — a small per-player window in AB/WSG listing enemy players to **engage** vs **avoid**: ThreatProvider ranking × `MATCHUP[myClass][enemyClass]` from the matchup reference, healer flag overriding the matrix ("CC, don't chase"); updates on the scoreboard ticker

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

- [ ] **[VERIF-1] Recorder scaffold** — `TitanBgGeneralSaved.Analytics` slot + `/bganalytics` slash command that prints collected data; on/off gate; no impact on existing functionality
- [ ] **[VERIF-2] Zone-in snapshot** — on `PLAYER_ENTERING_WORLD` in a BG: log `instanceMapID` (`select(8, GetInstanceInfo())`), `uiMapID` (`C_Map.GetBestMapForUnit`), timestamp; closes Era ID rows in `bg-detection-reference.md`; confirms smoke W7/W8/T5
- [ ] **[VERIF-3] Scoreboard shape** — on first `UPDATE_BATTLEFIELD_SCORE` per session: dump full return shape of `GetBattlefieldScore(1)` (all N values, positions for faction/classToken/damageDone/healingDone); fixes or confirms `SCORE_POS` in `ThreatProvider`; closes smoke TP2; unblocks CMD-6/7
- [ ] **[VERIF-4] AB POI logger** — on each `AREA_POIS_UPDATED` in AB: snapshot full POI list (`areaPoiID`, `name`, `textureIndex`) with timestamp and changed-entry diff; fills the Era decode table; unblocks AB-2/3/4/5
- [ ] **[VERIF-5] WSG event capture** — on `CHAT_MSG_BG_SYSTEM_*` in WSG: log raw message + timestamp; on targeting a flag carrier: aura scan (`UnitAura` loop, capture name + spellID); confirms DBM's "Unused"-pattern caveat; unblocks WSG-2/3/4
- [ ] **[VERIF-6] Details! enrichment** — if `Details` global present, read `Details:GetCurrentCombat()` in the ThreatProvider tick instead of (or to supplement) scoreboard damage/healing; optional, no hard dependency; degrades gracefully if Details! not installed

## Epic 2 — AB Advisor

From "callout buttons" to "the addon tells you what to call".

- [x] **[AB-1] Research: reading AB node ownership and capture state per flavor** — answered: `C_AreaPoiInfo` + `AREA_POIS_UPDATED` works on all flavors incl. Era (see `Research/ab-node-state-research.md`); decode tables need one in-game `/dump` session — action items in the doc
- [ ] **[AB-2] Node state strip** — show each base's owner (Alliance/Horde/contested) above its grid column
- [ ] **[AB-3] Capture timers** — countdown until a contested base flips, surfaced on the strip
- [ ] **[AB-4] Smart callout enrichment** — clicking a callout embeds live context ("INC ST — 4+, flips in 0:22")
- [ ] **[AB-5] Advice engine v1** — rule-based suggestions ("you hold 2 bases and are behind — call attack on weakest enemy base")

## Epic 3 — WSG Advisor

- [x] **[WSG-1] Research: flag state tracking per flavor** — answered: events via `CHAT_MSG_BG_SYSTEM_*` pattern parsing (locale-dependent, enUS first); FC names only from pickup messages, aura check as locale-independent confirmation (see `Research/wsg-flag-state-research.md`; enUS patterns + aura IDs need in-game capture — action items in the doc)
- [ ] **[WSG-2] FC status panel** — both flag carriers by name, with health when available
- [ ] **[WSG-3] FC-aware callouts** — "EFC <name> LOW — kill at our tunnel" built from live state instead of static text
- [ ] **[WSG-4] Flag respawn / debuff timers** — Focused Assault stacks countdown for endgame calls

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

## Epic 5 — Release Quality

- [ ] **[REL-1] Options panel** — Titan right-click → settings (auto-open, channel override, sounds)
- [ ] **[REL-2] Sound cues** — optional audio on critical advisor alerts
- [ ] **[REL-3] Multi-flavor verification pass** — full smoke checklist on retail and Cata Classic, flavor guards where APIs diverge
- [ ] **[REL-4] CurseForge release** — changelog, `.toc` version bump, packaging via `.pkgmeta`

## Parked / Ideas

- Eye of the Storm / Twin Peaks / Deepwind Gorge support (retail)
- Voice (TTS) callout playback for the leader
