# WSG-2 — FC Status Band (design handoff)

**Surface:** the flag-carrier status line in the `BgGeneralWindow`, shown only on
the **WSG** tab, in the same band the AB tab uses for node states.
**Status:** shipped (07-04 batch, `RefreshWsgStrip`) — this doc is the design
**target** the in-game UI review measures the shipped band against.
**Data source:** `FlagState.GetView()` (100% local reads; no addon comms needed).
**Visual mockup:** rendered companion in the Artifact gallery (native-WoW preview
of every state below).

---

## Job

In one glance, while leading a Warsong Gulch match, answer: *is our flag out and
who has it (the kill target), is their flag out and who's running it (escort),
what's the score, and — right after a cap — when does the flag come back?*

## Anchor & frame

- Single **centered** `FontString` (`GameFontNormalSmall`, no word-wrap) spanning
  the window width, anchored in the band between the tab row and the grid
  (`stripY = tabOffsetY - tabH - 4`).
- Toggles with the tab: `wsgStrip:Show()` on the WSG tab, `Hide()` otherwise.
- Refreshed on the window's 0.5s ticker (`RefreshWsgStrip`) — live, no flicker.

## Layout (one line, three groups, left→right)

```
  EFC Kruelhand 34%      FFC Brann 88%      2-1   flag 9s
  └─ our flag / kill ┘   └─ their flag ┘    └ score ┘ └ respawn ┘
     (threat red)           (friendly blue)   (A-H)   (gold, cap only)
```

Groups are separated by 4 spaces (`"%s    %s    %s%s"`). The respawn segment is
appended only while a countdown is live.

## Colour semantics (from the live constants)

| Token | Hex | Used for |
|---|---|---|
| Threat red | `#ff4d4d` (`HORDE_COLOR`) | **EFC** segment — the enemy on our flag = the kill target |
| Friendly blue | `#4d88ff` (`ALLY_COLOR`) | **FFC** segment — our ally on their flag = escort |
| Muted grey | `#808080` (`MUTE_COLOR`) | "our flag safe" / "their flag safe" when a flag is at base |
| Gold | `#ffd100` | `(dropped)` tag and the `flag Ns` respawn countdown |

> **Deliberate:** EFC is **always red, FFC always blue — threat colours, not
> faction colours.** Red = "kill this", blue = "protect this", regardless of
> which side the player is on. This is a UX call, not a faction bug.

## Carrier segment states (`fcSegment`)

| Flag state | Renders | Notes |
|---|---|---|
| `base` | `our flag safe` (muted) | no carrier; the calm default |
| `carried` + health | `EFC Kruelhand 34%` | short name (realm stripped), live HP% |
| `carried`, no health | `EFC Kruelhand` | carrier not currently visible → HP omitted, not shown as 0 |
| `dropped` | `EFC Kruelhand (dropped)` | last-known name kept; `(dropped)` in gold |

Name is always the **short** form (`name:match("^[^-]+")`) — realm stripped for
width. Carrier identity comes from the `CHAT_MSG_BG_SYSTEM_*` pickup message
(**confirmed named on Era, VERIF-5**), with the flag-aura scan as the fallback
when chat gave no name.

## Score & respawn (WSG-4)

- **Score:** `{ally}-{horde}`, ally count in blue, horde in red (e.g. `2-1`).
  Caps-to-win is 3. Prefers the client world-state score, falls back to our own
  capture counter.
- **Respawn:** `flag Ns` in gold, shown only in the ~12s after a capture while
  the flag is resetting, ticking to 0 then disappearing — lets the leader time
  the re-grab.

## Open questions for the UI review

1. **Low-HP emphasis** — the callout text tags `LOW` at ≤35% (WSG-3); should the
   band itself flip the HP% to red / add a `!` at that threshold so the kill
   window reads pre-attentively? (Currently HP% inherits the segment colour.)
2. **Health as a mini-bar** — a 3–4px class/threat-coloured bar under the EFC
   name vs. the bare `34%`. Richer, but heavier than the native one-line band.
3. **Empty-state clarity** — is `our flag safe / their flag safe` legible enough
   at a glance, or should base-state show a subtle 🏳 / anchored dot?
4. **Colour-blind safety** — red/blue threat coding leans on hue alone; the
   `EFC`/`FFC` label prefixes already disambiguate, but worth a deuteranopia check.

## Non-goals

- No enemy positions or minimap integration (out of scope for the band).
- No cross-client HP sync yet — HP% is local visibility only (the `TBG` addon
  channel in `Design/README.md` is a later enrichment, not required here).
