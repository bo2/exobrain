---
name: exobrain-authoring-audit
description: "Audit a doc/spec against its readers before it lands — the heavy reader-lens tool. Use when creating a new doc, or writing/revising a substantial or justification-heavy one: models who will read it (predicting reader personas and needs blind to your draft), derives what it must contain, and traces each contested fact to a real reader need (verified in the exobrain, then with the human) before keeping. Cuts session-narrative and 'why we did X' justifications that serve the author, not any reader."
---

# exobrain-authoring-audit

Operationalizes the **Reader Lens** principle (root `AGENTS.md`) for substantial writing: scope a doc by *who reads it* before drafting, and audit a draft for facts no reader needs. The principle is the always-on lens; this skill is its heavy tool — model readers, derive scope, verify contested facts against real demand.

## When to use

- Creating a new doc and need to define its scope.
- A large or justification-heavy addition to an existing spec/doc.
- A contested keep/cut call on a specific fact — especially explanatory "why we did X" prose.

Skip it for mechanical edits (typos, links, renames); those get only the in-head test from the principle.

## Method

### 1. Name the genre

Identify the artifact kind — skill-behavior doc, API reference, domain profile, connector doc, README, auto-loaded spec. The genre fixes the readers, and the genre→personas mapping is reusable across artifacts of the same kind.

### 2. Predict readers — blind to your draft

Spawn an audience-scout sub-agent to reconstruct who reads this genre and why, fenced from your draft so it can't launder your framing back to you:

- **Mechanical fence:** point it at the committed version on the default branch, or revert the doc-under-audit to that version in a scratch copy — your unmerged prose isn't there to read. For a net-new doc, let it read the *code/behavior* (ground truth) but not your new prose.
- Give it the artifact's name, location, and durable higher-altitude context (root `AGENTS.md`, `domains/exobrain/`, the scope/domain it serves) — never a brief you authored.
- Ask it to output, per persona: trigger, the question in their head, plausibility, and **whether they'd actually arrive at *this* genre** vs. elsewhere. A reader who exists but lands on a different doc justifies nothing here.

### 3. Derive scope from personas

List what the doc *must* contain for each predicted reader to succeed. This is the coverage target — derived from readers, not from your draft.

### 4. Audit each fact — the demand backtrace

Atomize the draft (or planned content) into atomic facts. Per fact:

1. **Fact → question** it answers. Can't name one → cut.
2. **Question → presupposed expectation.** ("Why isn't X here?" arises only for a reader who expected X.)
3. **Universal or narrow** to this genre's readers? Universal → keep. Narrow → verify.
4. **Verify the need is real,** cheapest-authoritative-first:
   - grep **the exobrain** (domains / skills / docs / workflows) — present = strong keep.
   - if absent, check the discussion history or ask the human — judged by recurring demand, not a single hit.
5. **Decide:** real recurring need → keep (sized to it); none/rare → cut. **Default cut.**

### 5. (Optional) generic judge

For a still-contested fact, hand a fresh agent only `{fact, genre persona list}` and ask it to name the persona-goal the fact serves or cut. It needs no project context — it stays generic.

## Honesty limits

- **This is a cut instrument.** It flags facts no reader needs; it does not find *missing* facts — coverage is step 3's job, done separately.
- **The evidence search can be gamed.** Pre-register a few query phrasings; judge by frequency, not whether one stale hit exists.
- **The fence isn't airtight.** Hiding prose removes most of the leak; your fingerprints survive in code comments/docstrings — don't chase the last of it.

## Worked example — the contested caveat

A `home` domain's `appliances.md` records *why* a dishwasher warranty claim was once denied. Question: should the profile keep the denial reasoning?

- Reasoning alone failed twice — first "keep the full denial story" (author-serving narrative), then, over-correcting, "cut it, nobody needs old claim history." Two blind sub-agents didn't settle it either.
- The **evidence step** did: grepping the exobrain surfaced a `maintenance` runbook that checks warranty status before scheduling any paid repair, plus an open question about whether the warranty transfers on sale. The need is real — but only for the **runbook** genre (someone deciding repair-vs-replace), not the appliance-profile genre.
- Calibrated outcome: **cut** the denial narrative from `appliances.md` (its at-a-glance readers don't need it); **keep** the durable fact ("warranty voids if serviced by a non-authorized tech") in the maintenance runbook, where the repair-decision reader does.

The lesson the skill encodes: on contested facts, judgment is unreliable in both directions; the evidence check is what calibrates.
