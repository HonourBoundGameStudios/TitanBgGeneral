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
- [ ] **[AWARE-3] Auto-open option** — optionally open the window automatically when entering a supported BG, close on leave
- [ ] **[AWARE-4] Context-aware Titan button text** — show current BG (and later, score/flag state) on the Titan bar

## Epic 2 — AB Advisor

From "callout buttons" to "the addon tells you what to call".

- [x] **[AB-1] Research: reading AB node ownership and capture state per flavor** — answered: `C_AreaPoiInfo` + `AREA_POIS_UPDATED` works on all flavors incl. Era (see `Research/ab-node-state-research.md`); decode tables need one in-game `/dump` session — action items in the doc
- [ ] **[AB-2] Node state strip** — show each base's owner (Alliance/Horde/contested) above its grid column
- [ ] **[AB-3] Capture timers** — countdown until a contested base flips, surfaced on the strip
- [ ] **[AB-4] Smart callout enrichment** — clicking a callout embeds live context ("INC ST — 4+, flips in 0:22")
- [ ] **[AB-5] Advice engine v1** — rule-based suggestions ("you hold 2 bases and are behind — call attack on weakest enemy base")

## Epic 3 — WSG Advisor

- [ ] **[WSG-1] Research: flag state tracking per flavor** — flag pickup/drop/capture events, FC identification, `UPDATE_BATTLEFIELD_SCORE` flag carrier APIs
- [ ] **[WSG-2] FC status panel** — both flag carriers by name, with health when available
- [ ] **[WSG-3] FC-aware callouts** — "EFC <name> LOW — kill at our tunnel" built from live state instead of static text
- [ ] **[WSG-4] Flag respawn / debuff timers** — Focused Assault stacks countdown for endgame calls

## Epic 3.5 — AV Panel (un-parked 2026-06-09)

User call: AV gets a panel too, alongside the WSG/AB advisor focus.

- [x] **[AV-1] AV grid tab** — third tab alongside AB/WSG: 7 columns (DB/IW/SH/SF/TP/IB/FW) × INC/DEF/HELP/CAP/GO/RECAP via the shared `BuildColGrid`; window sizes to the widest grid (smoke rows W5/W6/C5 green in-game 2026-06-09)
- [ ] **[AV-2] AV-specific callouts** — tune locations/actions for AV's flow (towers, GYs, bosses) once AV-1 is played with

## Epic 4 — Command & Control

Directing players, not just announcing.

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
