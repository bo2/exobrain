# Failure modes

Recurring classes of agent failure, each with an engineered counter. Check new designs against them.

**The blind session.** A small share of sessions answer without ever invoking the tool that reads their input — describing a file from its path and the prompt's own checklist, refusing, or bluffing a plausible hedged answer. Fabricated output traces disproportionately to these; the rate is environment-specific, so measure it where you run. Counter: read the session's own metadata (turn count, tool invocations) and discard any answer from a session that provably never looked; retry once; treat repeated failure as "uninspected," which downstream logic must handle conservatively rather than as a verdict.

**Self-corroboration.** A bot reading its own past output as independent evidence — one mistake corroborates the next. Annotating is not a counter: a "discount these" instruction leaves the content in evidence, where it still reads as corroboration. Counter: subtract, don't annotate — record authorship and remove the agent's own prior output from its input entirely; and account for authorship-tracking gaps (expired records read as someone else's), which make the subtraction incomplete by construction.

**The poisoned cache.** One bad generation frozen in a keyed cache with no expiry silently decides every later case that touches the key — and a cached judgment is often the one input nothing else in the payload can contradict. Counter: let the consumer flag discordance (one input contradicting everything else), regenerate from scratch once, overwrite the entry, and cap the recheck so it can't loop. Never share a cache between production and evals.

**Context-dependent refusal.** The same aggressive-but-legitimate prompt succeeds inside its project context and reads as an attack from a bare directory — the surrounding context is what legitimizes it. Counter: pin the working context of unattended sessions deliberately, and A/B the refusal rate when a runner misbehaves only in some environments — controlling for the inputs themselves, which can carry their own triggers.

**The unverifiable prose gate.** Any protocol that relies on the agent choosing not to look at something it can read. It may hold — but nothing tells you whether it did. Counter: enforce mechanically ([`blind-protocols.md`](blind-protocols.md)); where only a prose gate is possible, pair it with a mechanical post-hoc detector, and where neither exists, subtract the input.

**The eval that grades its own author.** Seeding an artifact from the corpus that evaluates it, letting the editor see the failing answers, letting panelists read each other — circularity in any form. Counter: pipeline separation, blind editors, independent runs.

**Metric gaming by base rate.** A dominant label or clustered ground truth lets a system score well by degenerate strategy. Counter: score the informative subset, dedup clustered truth, report cost-split errors.

**Silent coverage loss.** A source down for every panelist, a skipped modality, a truncated sweep — all reading as "covered" downstream. Counter: report gaps and skips explicitly as first-class results — and prefer machinery that forces the report (count checks, skip counters) over authors remembering to write it down.
