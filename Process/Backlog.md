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
- [ ] **[VERIF-6] Details! enrichment** — **PROMOTED from optional**: with Era scoreboard damage/healing always 0 (VERIF-3 finding), `Details:GetCurrentCombat()` is the *only* damage/healing source on Era. If `Details` global present, read per-player `actor.total` in the ThreatProvider tick; degrade gracefully (class-prior only) if Details! absent.

## Epic 3.5 — AV Panel (un-parked 2026-06-09)

User call: AV gets a panel too, alongside the WSG/AB advisor focus. The grid tab
shipped (AV-1 → `Archive.md`); the callout tuning remains.

- [ ] **[AV-2] AV-specific callouts** — tune locations/actions for AV's flow (towers, GYs, bosses) once AV-1 is played with

## Epic 5 — Release Quality

REL-1 (options panel) + REL-2 (sound cues) shipped this session (→ `Archive.md`,
pending in-game GREEN). These close out the epic.

- [ ] **[REL-3] Multi-flavor verification pass** — full smoke checklist on retail and Cata Classic, flavor guards where APIs diverge
- [ ] **[REL-4] CurseForge release** — changelog, `.toc` version bump, packaging via `.pkgmeta`

## Parked / Ideas

- Eye of the Storm / Twin Peaks / Deepwind Gorge support (retail)
- Voice (TTS) callout playback for the leader
- **10v10 team-strategy advisor** (to discuss 2026-07-03) — read the whole enemy *and* friendly comp (both 10-player rosters), evaluate the team-level matchup, and suggest the best strat for it (opener split, who to focus, defend/offense balance). Team-composition scale, above the per-enemy `MATCHUP` 1v1 advice we already ship. Design conversation pending with the Admiral.
