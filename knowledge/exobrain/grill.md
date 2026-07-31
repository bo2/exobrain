# The grill

The shared interview discipline used wherever an exobrain turns one person's understanding into knowledge others — and agents — hold identically: distilling a corpus into a domain, curating a domain, stress-testing a plan, shaping a spec. An adversarial, one-question-at-a-time interview that reaches shared *correct* understanding, not just recorded answers.

It descends from Matt Pocock's `grill-me`; this is the exobrain generalization that knowledge-building and planning skills cite rather than each restating.

## The goal

Shared *correct* understanding. An interview that politely records every answer verbatim aligns the agent with the human's blind spots too — so the grill challenges weak reasoning, it doesn't just collect it.

## Explore before asking

A human question is the most expensive resource in the session; spend it only where it's irreplaceable. Classify every open item before asking anything:

- **Discoverable** — answerable from code, docs, or the cited source the item points at. Look it up, cite it in the target's style, close it.
- **Conventional / low-risk** — covered by an established convention or a reversible default. Decide it, and batch into a numbered decision list the human can veto by number.
- **Human judgment** — taste, history, intent, risk tolerance, a genuine trade-off. Only these reach the interview.

## One question at a time

Ask one question, wait for the answer, continue. Each question carries:

- the current evidence or assumption
- your recommended answer
- what changes downstream if they choose differently

Surface the numbered decision list (the conventional calls you made on the human's behalf) before the next judgment question when those calls affect later branches — the human vetoes by number and moves on.

## Walk the design tree

Use recurring patterns to expose hidden decisions:

- **Cardinality** — 1:1, 1:many, many:many, optional? Can the parent exist with zero children?
- **Orthogonality** — a new category, or metadata layered on an existing concept?
- **Status semantics** — stored, derived from events/timestamps, or both? Linear or free-form transitions?
- **Lifecycle** — what creates, archives, ships, expires, or reveals it?
- **Deletion** — restrict, detach, archive, cascade, soft-delete?
- **Nullability / defaults** — which fields are required; what default represents an unfinished idea?
- **Ownership** — which system owns the concept; which only reference it?

Sharpen fuzzy or overloaded terms into one canonical term — one that can become a file name, a variable, a search query. Call out a term that conflicts with existing language immediately. Stress-test relationships with concrete edge-case scenarios that force precision about boundaries.

## Challenge discipline

Answers are stress-tested, not transcribed. Before writing one in, check the reasoning behind it: unsupported generalizations, conflicts with the corpus or explored evidence, and bias patterns (anchoring on early numbers, survivorship in success stories, recency over base rates, confirmation in source selection). When the reasoning is weak:

1. Challenge once, substantively — name the specific counter-evidence, counterexample, or bias pattern, and offer a steel-manned alternative. "Are you sure?" is not a challenge.
2. The human is the final arbiter. If they hold after a solid challenge round, their answer goes in.
3. A contested claim never enters dressed as plain fact — attribute it ("per <curator>, despite X") and record materially unresolved tension where the target keeps its open questions.

## Delegation

If the human delegates — "it's in that doc / the code / that thread" — treat it as an instruction to investigate, not an answer. Inspect the named source and return with what it appears to say, a recommended answer, and any residual uncertainty that still needs judgment.

## Verify shared understanding

An empty question queue proves the questions were answered, not that the agent understood the answers. Two gates close the session:

1. **Read-back** — walk the human through the synthesized understanding: key concepts, relationships, scope boundaries, and how each contradiction resolved. Correct and re-walk anything they push back on.
2. **Spot-check quiz** — generate scenario questions ("what happens when X?", "which system owns Y?"), answer them yourself, and have the human verify each. Deliberately probe the claims challenged or contested earlier — that's where misalignment is most likely to survive.

Done only when the human signs off.
