# Orchestration

Multi-agent structure earns its cost through deterministic control flow around the agents and through deliberate differences in what each agent can see ([`principles.md`](principles.md)). Check any new design against [`failure-modes.md`](failure-modes.md) before running it.

## Panels

For work too large or too many-angled for one context: fan one rubric across independent agents for coverage (per-area readers, per-item verifiers) or consensus; reconcile in plain code or a dedicated pass, never by letting panelists see each other. Verify per-agent output counts mechanically after reconciliation — item drops and duplications appear at high per-agent loads, and there is no measured safe ceiling. When a source is down for a panelist, record the gap explicitly as a first-class result ([`failure-modes.md`](failure-modes.md)).

## Handoffs

When one session's context ends and another must continue: lead with the outcome, point at artifacts by path rather than copying them, list decisions already made so they aren't re-litigated, rank the open moves, name the capabilities the next session should load, and redact secrets. A handoff that re-explains what's already written somewhere is context spent twice.
