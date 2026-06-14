# Design/ — UI handoffs and mockups

Drop UI design handoffs here (mockups, layout sketches, icon choices, window
wireframes) — e.g. exports from the Claude Design Tool or annotated screenshots.

**Check this folder before starting any UI work.**

Conventions for designs in this project:

- The addon must look **native to WoW** — Blizzard templates, standard font
  objects, `Interface\Icons\…` textures (see `Process/WorkingWithClaude.md` §4).
- A design handoff for a window/panel should specify: size, anchor behaviour,
  icon set per button, and which chat message each control sends.
- Screenshots of the current in-game state belong here too, named
  `current-<surface>-<date>.png`, so before/after is reviewable.

## Inter-Addon Communication — `TBG` Addon Message Channel

Classic Era only (`C_ChatInfo.SendAddonMessage` / `CHAT_MSG_ADDON`).

**Purpose:** crowd-source data that no single client can see alone — primarily
enemy flag-carrier health for WSG-2, potentially enemy unit positions for
future features.

**Protocol prefix:** `TBG` (registered with `C_ChatInfo.RegisterAddonMessagePrefix("TBG")`)

**Channel:** `INSTANCE_CHAT` (scoped to the BG instance; all 10/15 players receive it)

**Message format:** `TYPE:payload` — e.g. `HP:guid:pct` for player health sync.
Types are short uppercase tokens; payloads are colon-delimited primitives.
No encryption, no auth — trust only plausible values (0–100 for HP, etc.).

**Architecture (mirrors DBM-PvP's `healthTracker`):**
1. Scan own `target`, `raidNtarget`, `nameplateN` units each tick
2. Derive HP % from `UnitHealth / UnitHealthMax * 100`
3. Apply monotonic filter before broadcasting: accept decreases, >10% jumps
   upward, or resets to 100 (same rule DBM uses — `isGoodUpdate`)
4. Name-hash stagger (0–1s delay) to avoid simultaneous floods from multiple
   TBG users; effective poor-man's leader election
5. Receive own prefix broadcasts from other TBG users in the instance and
   update local state with the same monotonic filter

**Fallback:** if no other TBG user is in the instance, local scan only
(degraded coverage but functional).

**Optional enrichment:** if `Details` global is present, read
`Details:GetCurrentCombat()` for per-player `actor.total` damage/healing
instead of the scoreboard. No hard dependency — degrade to scoreboard
(`GetBattlefieldScore`) if Details! is not installed.

**What existing channels do NOT carry (investigated 2026-06-13):**
- `DBM-PvP` prefix: NPC/boss CID-keyed HP sync (AV bosses). No player data.
- `Capping` prefix: same NPC HP sync (`strid` = creature ID from GUID).
- DBM-PvP and Capping do not broadcast node state or flag events — those are
  local reads only (`AREA_POIS_UPDATED`, `CHAT_MSG_BG_SYSTEM_*`).
