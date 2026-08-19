# Behavioral testing of agents

An agent system's context — the specs, skills, and indexes it auto-loads — is code: changes to it alter behavior and are testable before shipping. These harnesses answer "does the agent actually do what the context says?" empirically instead of by intuition. In an exobrain the first two harnesses exist as skills — cited per section — so reach for the resident implementation before building one.

## Context A/B

Control = current state; treatment = current state + exactly one diff. Both arms run real headless agents in hermetic sandboxes, each wired by the **production loading mechanism itself** — its fidelity is provable with probes (below); a hand-rolled approximation of how context loads drifts from the real mechanism silently, and an in-session sub-agent does not replicate auto-load at all.

- **Discriminator constraint.** A task measures the change only if the target behavior is reachable *only* through the change (not present elsewhere in context, not findable on disk) and observable (a stubbed command, a feature of authored output). Expect this to disqualify most candidate tasks — a binding constraint, not a formality.
- **Dev and held-out task sets, with negatives.** Iterate variants on dev; run held-out once; include tasks where the right behavior is *not* reaching for the target (rationale in [`principles.md`](principles.md)).
- **A/A runs** with an empty diff establish the noise floor — run one before trusting small margins.
- **Production configuration.** Run the model and agent that production runs ([`principles.md`](principles.md)).
- **Infrastructure failure is not behavior.** An empty-output run is retried and never counted as a legitimate "didn't act" — otherwise harness flakiness corrupts the negatives.

*Resident implementation: the `exobrain-ab` skill (`skills/exobrain-ab/`).*

## Behavioral suites

Snapshot the whole system into a throwaway template — including uncommitted working-tree state when testing pre-land — and run each case N times per agent against a fresh copy, reporting k-of-N against a per-case threshold. Cases self-seed their fixtures so the suite ports across instances. Per-case permission profiles are the containment dial (read-only, curated action allowlist, red-team, or static with no agent call at all).

- **ERROR is not FAIL.** A broken fixture, failed render, or unresolvable base is reported as an error, never as a verdict ([`principles.md`](principles.md)).
- **Informational thresholds** for aspirational, model-dependent cases: tracked per agent, never gating.
- **Attribute changes robustly** — diff against a pinned base marker that survives the agent itself committing or merging during the run, and exclude the harness's own fixtures from hit detection.

*Resident implementation: the `exobrain-tests` skill's `behavior/` suite.*

## Harness fidelity probes

Prove the harness before trusting its verdicts. Probe questions target facts reachable *only* through the mechanism under test — e.g. facts that exist solely in the deepest context layer — paired with a bare arm that must fail them; if the bare arm passes, the probes leak. Block alternative routes structurally per agent (deny the file tools, or delete the inlined source after wiring). Surround the model runs with deterministic no-model assertions about the wiring itself.

## Cold-start and equivalence

- **Cold-start tests.** A no-context agent follows your own onboarding docs verbatim in a fresh environment. A discovery variant removes the signposts and requires the agent to navigate the world without them. Unmet environment requirements skip loudly — a skipped case is reported, never silently passed or failed. (*Resident implementation: the `exobrain-tests` skill's `onboarding/` suite.*)
- **Equivalence gates for refactors.** Before rewriting an engine, capture its behavior from the old implementation as a baseline; the gate is a diff of the new engine's output against it, in a format chosen so representation changes can't mask behavioral ones. Freeze the reference's inputs with it, and self-test that the reference compares clean against itself.
- **Single-variable injection.** Hold model, tools, and inputs constant and vary exactly one injected artifact per arm — including keeping any documentation of the target present in *both* arms, so the test measures surfacing, not existence. Each arm loads every co-varying copy of the artifact together: a rule restated in a prompt scaffold or runner is half the treatment, and an arm mixing one file from each condition is neither condition — grep for restatements before assuming there is only one copy.

## Test the gates too

Gate and harness machinery gets its own deterministic tests with a stubbed model on PATH returning canned verdicts — no model spend, and it catches the environment regressions (a leaked proxy variable, a changed exit code) that would otherwise silently disable a gate on every run. (*Resident implementation: the `exobrain-tests` skill's `unit/` suite.*)
