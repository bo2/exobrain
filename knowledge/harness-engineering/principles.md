# Principles

The doctrine the rest of this domain embodies. Each principle recurs across independent techniques; when designing something new, check it against these first.

**The grading surface sits strictly upstream of the editing surface.** Whatever scores an artifact must never be readable by whatever edits it — train/val splits, blind editors, held-out sets, and fenced scouts are all this one rule. When the two surfaces touch, you are training on the test set, whatever you call the process.

**Blindness is enforced mechanically wherever possible.** "Don't look at X" in a prompt cannot be verified; a tool wrapper with a cutoff, a moved file, a denied tool, a blocklisted channel is a constraint. A prose gate is acceptable only when paired with a mechanical post-hoc detector; where neither fence nor detector is possible, subtract the input entirely.

**Measure the decision, not the outcome.** Grade the observable choice — which command was reached for, what text was authored, what egress was attempted — from the specific stream that carries it (invocation log, output, egress log). Stub effects so nothing touches live systems.

**Deterministic first, LLM second.** Mechanical assertions run first and settle what they can; a model judge rules only on what mechanics can't (intent, quality, semantics), and is scoped away from re-adjudicating what's already settled.

**Negatives are mandatory.** Every guardrail eval carries a benign twin that must be *performed* — otherwise blanket refusal passes for safety. Every trigger eval carries no-trigger tasks — otherwise over-firing passes for discovery.

**Always run the duel.** An artifact, skill, or structure must beat the identical setup without it, with cost per arm on the table. Without the duel, "it helps" is intuition.

**Plateau is the stop signal.** Iterating past plateau is, by construction, learning the eval set.

**Run the production configuration.** Effects are strongly model- and agent-dependent for agent *behavior* — tool choice, context loading, refusal; classification accuracy can be model-insensitive while calibration still shifts what automates. An eval on a different model or a different context-loading mechanism measures a different system.

**Containment by construction, not by policy.** Harness safety comes from worthless canary data, stubs that never open sockets, and sandboxes with no real remotes — never from the agent having been told to behave.

**Reach must be earned.** Anything imposed beyond its author — auto-loaded context, a forced capability, a standing bot — requires committed proof of value (enforcement: [`gates-and-proof.md`](gates-and-proof.md)).

**Degrade open for advisories, strict for verdicts.** An advisory checker that's missing or erroring must never block; a test judge must never let engine failure read as a verdict — ERROR is a third state distinct from PASS and FAIL.

**The agent proposes; the human executes the irreversible.** Dry-run by default, writes behind explicit flags, AI-drafted artifacts labeled until a person reviews them. This is the default posture; a deliberate deviation carries confidence floors, monitoring, and an accounting of its error cost.
