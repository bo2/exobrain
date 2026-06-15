# Domain — distill mode

Turn a corpus of already-collected knowledge (workspace notes, docs, transcripts, posts) into a domain whose content the human and the agent understand identically. The corpus seeds a draft; an adversarial interview resolves every gap and contradiction; a read-back and quiz prove alignment before anything ships.

Positioning: [`create`](create.md) builds from a broad source sweep and a code walk; distill builds from an existing corpus plus the human's head. Use it when the knowledge is already collected (typically a workspace) and the remaining risk is **misunderstanding, not missing sources**.

Arguments: `<workspace>` (source path) and optionally `<domain-name> <type>` (without it, detect the target in Phase 1 and propose it). The corpus is the primary source, not the only one — when a register item is answerable from code or connected tools, explore there before spending a human question.

The [shared foundation](SKILL.md) applies. The interview runs the discipline in [`domains/exobrain/grill.md`](../../domains/exobrain/grill.md) — this file adds only the distill-specific flow.

## Phase 1 — Ingest and target

Read the source workspace fully (`README.md`, workstreams, artifacts, `_raw/`). Map it against the existing `domains/` landscape: if a suitable domain exists, extend it in place (respecting its file structure); otherwise scaffold a new one — don't create a parallel home for knowledge that already has one. Confirm the target (extend vs. create, name, type, boundaries) with the user before touching files.

## Phase 2 — Draft and register

Scaffold (the file shapes `create` produces) or open the existing files, and write a **complete draft** from the corpus, applying [`authoring.md`](../../domains/exobrain/authoring.md). While drafting, build the **register** — a session working file (under `tmp/`, not committed) with one entry per unresolved item: **gap** (corpus silent on something the domain needs), **contradiction** (two sources disagree), **low-confidence** (claim rests on thin evidence or agent inference). Each entry records the claim, its type, the evidence on each side, and a proposed resolution. Never smooth over a conflict silently — that converts a known unknown into a silent error.

## Phase 3 — Triage

Classify every register item (the `grill.md` triage): **discoverable** → explore, cite, close; **conventional / low-risk** → decide, batch into a numbered veto list; **human judgment** → queue for the grill.

## Phase 4 — Grill

Run the interview per [`grill.md`](../../domains/exobrain/grill.md): present the decision list, then work the judgment queue one question at a time, updating the domain files inline as each item resolves (don't batch edits to the end). Hold the challenge discipline — a contested claim enters attributed, never as plain fact.

## Phase 5 — Verify

Run the two `grill.md` gates — read-back and spot-check quiz — probing the claims that were challenged or contested in Phase 4. Corrections loop back into the domain files (and the register, if they expose new gaps). Done only when the user signs off.

## Phase 6 — Deliver

Move register leftovers the user explicitly consented to park into `open-questions.md` (nothing parked without consent). The source workspace stays untouched as the historical record; note the promotion in its `README.md` and append its `TIMELINE.md` row if it has `timeline: true`. Persist (shared foundation).

## `--wip` — parallel-build WIP domains

A **WIP domain** exists to let several people build one thing in parallel without colliding — not to document everything. Its conventions (the `.wip` suffix, design-and-intent-not-live-status, the dissolve-and-promote lifecycle) are in [`domains/exobrain/domains.md`](../../domains/exobrain/domains.md) → "WIP domains". Same adversarial discipline as above, opposite completeness goal: **plan up front as little as possible, but no less.**

**Definition altitude — set it first.** How precisely is this project meant to be specified? Establish it with the curator explicitly before drafting depth is chosen or any question is asked: *"are exact metrics, data paths, and UI choices in scope now, or are those implementation's to answer?"* Record it in the WIP domain's README; note per-area deviations in the area file.

**The two gates** — every open question found while drafting passes both:
1. **Altitude gate** — at or above the project's definition altitude? Below-altitude questions are not grilled: park them as *answer during implementation* with an owner, or convert to named research tasks. Below-altitude *content* (proposals, mechanics from the corpus) isn't discarded — it lands in the stream's **Suggestions** section (preserved input the lead takes or leaves, never commitments).
2. **Collision test** — *if we don't answer this now, will people working in parallel collide, or be blocked from starting, when it's answered later?* A failing question gets grilled **regardless of altitude**: architecture homes, shared contracts (canonical data model, adapter interfaces, extension points), ownership boundaries between areas, anything one area builds that another consumes, externally-binding choices. Grill = (at/above altitude AND substantial) OR collision-critical. Park everything else.

**Two sub-modes.** *Bootstrap* (new WIP domain): scaffold a `wip`-type domain (`.wip` suffix), confirm the scope boundary against the long-horizon domains it borrows from, declare the lifecycle (dissolves at delivery, promote-back target) and the definition altitude in the README, plus the stream registry. *Area* (ingest one area into an existing WIP domain): read the area's corpus **in the original** (raw brain dumps/transcripts, not only summaries — summaries drop the below-altitude material that becomes Suggestions); write the stream folder (`streams/<area>/` — `README.md` + `open-questions.md`) at the project's altitude, routing every source item to **Decided** / **Suggestions** / **open question** / **left in the source**; self-check the sweep by grepping distinctive source terms against the stream files. Cross-stream items and citations live at the domain root (`open-questions.md`, `sources.md`), not in `_meta/`.

Hold the altitude during the grill: when the conversation sinks below it, restate the question one level higher and note the detail as deferred; when the expert can't answer at altitude, step *up*, not down; when the honest answer is "we need to check," record a named research task with an owner rather than forcing a guess.
