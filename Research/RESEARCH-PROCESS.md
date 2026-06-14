# TitanBgGeneral — Research Process

**Date:** 2026-06-09
**Status:** Final
**Confidence:** High

---

Research is a project asset and should be treated with the same care as source
code. This document describes how to decide whether research is needed, how to
conduct it, and how to make it permanent, searchable, and actionable.

**Scheduling (fleetcast 2026-06-11, for now): research spikes run at night** — execute them in the
overnight session unless the user explicitly says otherwise; daytime spikes get queued in the backlog
("queued for tonight"). Trivial look-ups that unblock the current item (a quick wowpedia API check) are
not spikes — just answer them.

For a WoW addon, research carries extra weight: the API is community-documented,
changes per patch, and **differs across the three flavors this addon targets**
(retail 11.x, Cataclysm Classic 4.x, Classic Era 1.x). An API that exists on
retail may be missing, renamed, or behave differently on Classic Era — and the
failure mode is usually silent.

---

## Two Tiers of Research

**Quick Note** — A single finding that informs a decision but does not justify a
full document. "Does `C_PvP.IsBattleground()` exist on Classic Era?" — verified
in-game with `/dump`, captured as a line in `CLAUDE.md` or a code comment. No
header, no structure.

**Full Research** — A document under `Research/` with the full header and
structure below. Use this for anything with long-term impact: how node states
are read in AB, how flag carriers are tracked in WSG, event catalogues, a
comparison of approaches.

If you are unsure which tier applies, it is probably a Quick Note. Promote it to
Full Research only if it grows.

---

## When (and When Not) to Research

**Before starting, check whether the answer already exists.** Search `Research/`,
`CLAUDE.md`, `MEMORY.md`, and the codebase itself. Only create new research when
the answer is not already available.

**Full Research is warranted for:**

* Any feature depending on a WoW API not yet verified on every target flavor
* Event catalogues (which events fire in a BG, in what order, with what args)
* Comparisons of two or more implementation approaches
* Reference catalogues (map IDs, world-state IDs, icon paths, chat-type rules)
* New project-wide conventions

**Do not create Full Research for:**

* Lua errors, debugging sessions, one-off investigations
* Anything verifiable in 5 minutes with `/dump` in-game
* Anything already answered in the codebase

---

## Choosing the Right Tool

| Task | Tool |
| --- | --- |
| Read addon files | Read |
| Search code | Grep / Glob |
| Verify an API exists / its return values | **In-game `/dump`** (the primary source) |
| Blizzard UI implementation details | `wow-ui-source` (Gethe mirror on GitHub) / Townlong Yak |
| API documentation | warcraft.wiki.gg (formerly Wowpedia), per-flavor pages |
| How other addons solved it | Source of BattlegroundEnemies, Capping, REPorter, etc. |
| Web research / large comparison | General Agent |
| Independent investigations | Parallel Agents |

Prefer primary sources in this order: **in-game verification → Blizzard's UI
source → wiki → other addons' source → forum posts**. Wiki pages are often
retail-only; always check the flavor banner. A claim verified only on one
flavor is Medium confidence at best.

---

## Defining Scope

Before creating a document or agent task, define:

* **Decision or deliverable** — what backlog item this research unblocks, in one sentence.
* **Existing knowledge** — prior decisions, rejected options, constraints.
* **Flavors in scope** — which of 11.x / 4.x / 1.x the answer must cover.
* **Output format** — event catalogue, API comparison, recommendation, implementation plan.
* **Destination** — the final path, e.g. `Research/ab-node-state-research.md`.

Keep scope narrow. One focused document beats one large multi-topic document.

---

## File Naming

```text
Research/<topic>-<type>.md
```

| Suffix | Purpose |
| --- | --- |
| `-reference.md` | Catalogues and lookup references (map IDs, events, icons) |
| `-research.md` | Exploratory investigations |
| `-decision.md` | Architectural decisions |
| `-plan.md` | Implementation plans |

Kebab-case. No dates or versions in filenames — those belong in the header. The
index table in `CLAUDE.md` is the authoritative list of what exists; keep it
current or `Research/` stops being discoverable.

---

## Document Header

```markdown
# Title

**Date:** YYYY-MM-DD
**Author:** Name
**Status:** Draft | Final | Superseded | Obsolete
**Confidence:** Low | Medium | High
**Flavors verified:** Classic Era | Cata Classic | Retail (list those actually tested)
**Supersedes:** filename.md   (omit if nothing superseded)

---
```

**Confidence levels:**

* **High** — Verified in-game on the flavors in scope, or against Blizzard's UI
  source. Another engineer following the evidence reaches the same conclusion.
* **Medium** — Supported by wiki documentation or another addon's working code,
  but not personally verified in-game on every flavor in scope.
* **Low** — Forum posts, dated guides, or reasoning not yet validated. Provisional.

---

## Document Structure

```markdown
## Executive Summary
## Research Question
## Constraints
## Findings
## Evidence
## Analysis
## Recommendation
## Risks
## Action Items
## Sources
```

Keep evidence separate from interpretation — this is the single most important
rule. Findings and Evidence state what is true (with the flavor it was verified
on); Analysis and Recommendation state what to do about it.

---

## Source Traceability

Every significant finding should be traceable to: an in-game `/dump` (note the
flavor and build number), a file in Blizzard's UI source, a specific wiki page,
or a named addon's source file. WoW research that doesn't note the flavor and
patch it was verified on is stale on arrival.

---

## Updating CLAUDE.md

After research is verified, update `CLAUDE.md` so the finding becomes actionable
rather than archived — this is the step most often skipped and the one that
gives research its value.

1. **Add a row to the Research Documents table** in `CLAUDE.md`.
2. **Update hard rules** if the research established one, stated as an
   imperative the next agent can apply without re-reading the document
   (e.g. *"Never call `Titan_Debug:New()` — it does not exist"*).
3. **Link the backlog item** the research unblocks: `(see Research/foo.md)`.

---

## Verify Before Closing

* [ ] File exists with complete header, including **Flavors verified**
* [ ] Research question answered
* [ ] Findings supported by evidence, kept separate from interpretation
* [ ] Recommendation present (if applicable)
* [ ] `CLAUDE.md` table row added
* [ ] Hard rules / patterns updated if behaviour changed
* [ ] Backlog item linked

---

## Reviewing Freshness

WoW research goes stale **every patch**. When a new patch lands (the `.toc`
Interface bump is the trigger), review any research touching APIs in that
flavor. Mark status as Draft, Final, Superseded, or Obsolete. Never build on
stale research without re-verifying in-game.
