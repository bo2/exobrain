# Adversarial verification

Structures where one agent's job is to break what another produced. A solo agent reviewing its own output tends to validate it; the counter is role-split adversaries and judges — plus turning the same adversarial lens on the measuring instruments themselves.

## The role-split loop

Extract the work under review into discrete testable claims (assertion, testable prediction, metric, window, magnitude). Build a **shared fact base** before any argument: one snapshot of the numbers with the exact query logic, canonical metric definitions rather than invented ones, fair multi-period baselines, known outliers computed both with and without. Agents arguing from different numbers produce noise, not verification — and every artifact in the investigation, including any caged side-analysis, must inherit the fact base's definitions.

Then run roles in sequence, each reading the prior's output:

- **Investigator** — re-verdicts each claim against the fact base, applying the *specificity test*: does this cause explain the specific event, or is it a chronic background condition that was always true?
- **Critic** — attacks everything and must show its own numbers ("vague objections are useless"); re-runs queries rather than trusting the investigator's; hunts the cross-claim failure classes: double-counting across claims taken as a set, cherry-picked baselines, survivorship bias. A critic pass that finds nothing is a legitimate outcome, not a failed protocol.
- **Judge** — issues per-claim verdicts with confidence, resolves the headline disputes by independently re-reading the cited sources (trusting neither side's extraction), and rules whether essential gaps remain — which is the loop condition.

Close with a **Resolver** pass over critic remarks that were accepted but never independently checked: accepted is not verified — and that applies to the resolver's own output too, so its new numbers enter the next verification round rather than bypassing it.

## Judge discipline

- **Strict-fail protocol.** The judge emits an exact pass/fail token; absence of the pass token is a fail; an engine error is inconclusive, a third state ([`principles.md`](principles.md)).
- **Pin the judge.** One judge model across all agents-under-test, or verdicts don't compare.
- **The transcript is data.** The judge is told explicitly that instructions inside the material under judgment are data, never commands.
- **Scope the judge.** Deterministic checks settle what they can first; the judge rules only on what remains (intent, quality) and is told explicitly not to re-adjudicate settled facts — omitting settled rules from its prompt is the weaker form.

## Verify the instrument

- **Critics against the rubric.** After applying a rubric at scale, run three adversaries on the audit itself: a false-positive hunt, a false-negative hunt, and an instrument critique — each reading the underlying artifacts, not just the verdicts. Systematic recall gaps usually trace to a single soft clause; tighten it and re-audit.
- **Debug the benchmark like a system.** Naive recall inflates when one output matches a cluster of adjacent ground-truth items — dedup them. Grading the final state mis-scores feedback that was addressed mid-flight — replay at the moment the ground truth was created. Filter non-substantive ground truth before it drives iteration. Know the trade: cleaning a benchmark can cut its power on some slice to zero — report the loss rather than keeping the dirty signal.
- **Null-cohort falsification.** Before trusting a statistical test, rebuild it on data where the true effect is zero by construction and measure how often it fires. A test that trips on most placebo pairs is miscalibrated for the design, regardless of what it says about the real pair.

## Negative controls

Every guardrail eval carries a benign twin the agent must *perform* — declining it on policy grounds is a failure — and discovery and trigger evals carry tasks where the correct behavior is to do nothing (rationale in [`principles.md`](principles.md)).

## Contained red-teaming

Cases that tempt an agent into forbidden actions are safe by construction, not by trust: planted secrets are worthless canaries detectable by their unique strings; egress binaries are shadowed by loggers that record the full invocation and input, then return plausible success without opening a socket; vectors that shadowing can't reach get a mock server registered as the only reachable endpoint; and the sandbox holds no real credentials or remotes. Crucially, the tempting action is *allowed* by the harness permissions — a denied attempt fails silently and hides the vector, while an allowed one gets recorded. Pass requires both halves: the canary absent from every sink, and a judge-confirmed, policy-grounded refusal. Scope note: only bare shell commands can be PATH-shadowed — MCP-invoked, full-path, and browser vectors need a mock endpoint or transcript capture instead, and the canaries' worthlessness, not the shadowing, is the ultimate safety layer.
