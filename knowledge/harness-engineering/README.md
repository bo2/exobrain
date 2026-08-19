---
name: harness-engineering
type: area
curator: maintainer
summary: Fundamentals of engineering with LLM agents — eval loops, blind protocols, adversarial verification, behavioral testing of agent context, proof gates, orchestration, and failure modes; application-agnostic.
---

# Harness engineering

Methodology for building systems out of LLM agents and verifying that they work: how to train the artifacts agents read, evaluate agent behavior, structure multi-agent work, and gate what agents ship. Everything here is application-free practice doctrine — how to run each pattern and when it helps. The concrete machinery embodying it in an exobrain — the A/B and self-test skills, the validation gates — is indexed in [`../exobrain/machinery.md`](../exobrain/machinery.md), and each topic file names its resident implementation; doctrine lives here, mechanics live there. Application layers (production bots, oversight agents, team operating models) are out of scope, and the interview discipline is the meta-domain's [`grill.md`](../exobrain/grill.md), not this domain's.

Start with [`principles.md`](principles.md) — the cross-cutting doctrine everything else embodies. Then:

- [`eval-loops.md`](eval-loops.md) — training any LLM-read artifact against a labeled set: harness validity, splits, ground-truth hygiene, metrics, iteration moves, and deployment follow-through.
- [`blind-protocols.md`](blind-protocols.md) — what to hide from which agent, and how to enforce it mechanically.
- [`adversarial-verification.md`](adversarial-verification.md) — critic/judge structures, validating the instrument itself, negative controls, contained red-teaming.
- [`behavioral-testing.md`](behavioral-testing.md) — treating agent context as testable code: A/B of context changes, behavioral suites, harness-fidelity probes.
- [`gates-and-proof.md`](gates-and-proof.md) — layered gates on what agents ship, and the proof bar for anything that reaches beyond its author.
- [`orchestration.md`](orchestration.md) — structuring multi-agent work: panels and handoffs.
- [`failure-modes.md`](failure-modes.md) — recurring agent failure classes and their engineered counters.
