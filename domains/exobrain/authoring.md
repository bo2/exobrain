# Domain authoring

How to write a well-formed domain. These rules apply to any writing into `domains/` — first draft, incremental update, or targeted edit.

For *what* a domain is, see [`entities.md`](entities.md). This file is the *how*.

## File anatomy

Each file opens with its H1 and dives into content — no preamble, no FAQ scaffolding. Write reference-style prose for the file's audience. The area's `README.md` is the entry point: a short orientation, then an index of the area's files.

## Horizon test

Every line must pass: **"Will this still matter in 3 months?"** One-off events and routine churn don't belong in a profile; they belong in raw notes or a history file.

- "Switched primary bank to X; auto-pay set up" → **Yes.** Durable state.
- "Paid the electric bill" → **No.** Routine event.
- "Roof replaced in 2025; 20-year warranty, transferable" → **Yes.** Durable fact with future relevance.

## Current state, not change history

Profile files describe what is **true today**. Narratives of how it got there — *"in March I switched from A to B"* — belong in a history file, not the regular profile. Keep in the profile: present-tense facts, plus durable rationale for why things are the way they are. Move to history: when changes happened, what was replaced, what was tried and abandoned.

**Exceptions that stay in the profile:** constraints that originated historically but still bind today, and "scars" you'll still hit (a dual setup mid-migration, a workaround still in place). The *when* goes to history; the *what-you'll-encounter* stays.

**Litmus test.** *"If this change had landed years ago and the change-narrative had been forgotten, would I still need to describe the current state this way?"* If yes, it's current state. If no — if the only reason the sentence exists is to record the change — it's history; move it.

## Synthesize, don't transcribe

Translate findings into implications; fold related findings into one coherent statement. Six receipts about a project become one paragraph on its status. Don't mirror source material you could just link.

## Don't transcribe what the source already holds

Synthesis has a sharp lower bound — the **cut line**: anything a reader could reconstruct by opening the file or running one obvious grep does not belong in a domain doc. Below the line it rots the instant the source moves, producing *drift* rather than knowledge.

**Cut on sight:**

- File:line citations (`internal/foo.go:144`, `class-bar.php:L23-45`) — they rot the moment code moves. Cite the *file*, not the line; the validator rejects `file.ext:NNN` in a profile.
- Code blocks that mirror a function's body, struct shape, or request/response JSON — the code is the source of truth; transcribing it produces drift, not knowledge.
- Class- or function-by-function walks ("`FooBar` owns X, Y, Z…").
- Enum or config-key listings that just restate a constant.
- Hardcoded tuning constants in any format — table or prose (see "Order-of-magnitude" below).

**Survives the cut** (what a profile is actually for):

- **Design rationale** — why the current state is what it is, where the reasoning is durable.
- **Cross-system invariants** — which component is authoritative, what fails open vs. closed, where the source of truth lives.
- **Gotchas the code mis-signals** — a name or layout that misleads a reader, corrected.
- **Operational patterns** — recurring failure shapes and runbook gestures (the durable lesson, not the incident narrative).
- **Migration scars still in the code** — shims kept for compatibility, dual-running paths during a transition.

**Self-check before keeping a passage:** *if I deleted this, what would a reader miss that they couldn't recover from the source in one step?* If the honest answer is "nothing," cut it.

## Order-of-magnitude, not brittle specifics

Values that drift — balances, rates, counts, limits, metrics, percentages — freeze a moment that won't stay frozen. Prefer the durable shape, and point at the source of truth for the live number.

| Brittle | Durable |
|---|---|
| "Savings: $14,237 as of June" | "Emergency fund holds ~4 months of expenses; live balance in [account]." |
| "Mortgage rate 5.25%, $2,140/mo" | "Fixed-rate mortgage renewing in 2027; current terms in [doc]." |

When the exact value genuinely matters, cite where it lives rather than embedding it.

**Watch-for phrasing.** Anything that reads like "N attempts", "X-second timeout", "Z% growth", "$N balance", or "K-item limit" is a value that drifts — a tuning knob or a point-in-time figure. Reframe it as the durable shape, or describe how to measure it and cite where the live value lives. The same holds for point-in-time business or product metrics — a revenue share, fill rate, headcount, or partner count — which drift exactly like a tuning knob: describe *how to measure* the figure and cite its canonical source, never the frozen value.

## Citations

Every non-obvious claim gets a short provenance note in parentheses — where it came from and when (`(Source: <doc/thread/url>, YYYY-MM-DD)`). A dated citation records when the source was created, not when the fact was last verified: treat the fact as current unless you find direct evidence it's stale, then **remove** the stale claim rather than past-tensing it.

## Gaps and conflicts

Don't silently drop an unanswered question or paper over a contradiction. Keep an `open-questions.md` in the area for: things newer evidence contradicts, findings that need human judgment, and references to things not yet documented.

## Don't duplicate drift-prone facts

When a drift-prone fact would appear in several files, write it in **one** place (closest to its source of truth) and cross-link. Duplicates silently diverge when one copy gets updated and the others don't. Reframing a fact as a durable *shape* (rather than a value) also lets it appear in several files without drift risk.
