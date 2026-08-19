# Gates and proof

What agents produce ships through layered gates; what agents impose on others carries a proof bar. Both exist because agent output is cheap and confident — the gates make cost and confidence earn themselves.

## The layered gate

Three layers, cheapest first, each scoped to what only it can check:

1. **Deterministic validator** — fast, grep-safe rules only. A rule whose own description contains the forbidden pattern can't be grep-gated; anything judgment-shaped moves up a layer.
2. **LLM judgment review** — a model pass over the diff against an authoring rubric, fed the diff explicitly as data. Advisory: it degrades open (a missing or failing engine never blocks) and fails only on reported violations.
3. **Behavioral verification** — changes to shared machinery (anything that alters other people's agents) don't ship until behaviorally tested, enforced as a script gate or as an explicit protocol step at persist; pure docs and personal scopes are exempt.

**Anti-reflexive clearing — for blocking gates.** The flag that clears a *blocking* gate is documented only inside the gate's own failure message, so it cannot be passed without reading what it asserts. An advisory gate may document its skip openly — the distinction is whether bypass must be a read-and-understood act. Either way, audit for silent waivers — and close the audit: a gate that can be waived silently isn't a gate, and an audit finding without a landed resolution is just a note.

*Resident stack: `scripts/validate-exobrain.sh` → `scripts/authoring-review.sh` → the behavioral suites; the map is [`../exobrain/machinery.md`](../exobrain/machinery.md) § Validation & quality gates.*

## Prove or narrow

Anything reaching beyond its author — a shared capability, auto-loaded context, standing automation — requires **committed** proof of value: a real run artifact, an eval result, a live usage citation. Testability is not proof; "it could be tested" scores as unproven. The escape hatch is narrowing reach to the author, where it imposes on no one — never waiving the bar. Apply the bar retroactively too: sweep the grandfathered corpus, prioritizing whatever is both imposed-on-everyone and unproven — and treat the sweep as open until its demotions actually land.

*Resident enforcement: the shared-skill proof bar in [`../exobrain/skills.md`](../exobrain/skills.md), applied by `scripts/authoring-review.sh` at the land.*

## Verify the optimistic direction

When automation reconciles state between systems, auto-apply only the safe direction; the favorable direction (promotion to done, approval, closure) routes through explicit verification against stated acceptance criteria before anything is written. The recurring false positive: a dependency link that looks like satisfaction but is mere reuse. Test the routing itself with hermetic synthetic fixtures exercising every branch — no live system involved.

## Propose-only writes

Bulk agent actions land as numbered, human-readable change lists paired with machine-readable ops. Executors are dry-run by default with an explicit live flag; applies are idempotent diffs against freshly-refetched state, so an item someone already handled becomes a no-op rather than a duplicate write; every AI-drafted artifact carries an explicit unreviewed marker until a person clears it. Reviewing a proposal list is cheap; un-doing applied writes is not.

## Calibrated estimation

When historical records are too polluted to calibrate from (bulk state flips, missing timestamps), don't average them — build a ladder of completed exemplars at each size and require every agent estimate to cite an anchor. Timebox research instead of estimating it; let coordination containers roll up from their children rather than carry their own numbers; never overwrite a human's estimate. The ladder is a method to rebuild locally against your own completed work, not a scale to copy.
