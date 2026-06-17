#!/usr/bin/env bash
# create-valid — asserts create-instance produced a well-formed instance.
set -uo pipefail
source "$HARNESS_LIB/check-helpers.sh"
INST="$1"

( cd "$INST" && scripts/validate-exobrain.sh --quiet ) || fail "validate-exobrain.sh failed"

# Framework files.
for f in AGENTS.md scopes.json skills.json skills.schema.json .exobrain.json \
         scripts/validate-exobrain.sh scripts/connect-agent.sh; do
    [[ -e "$INST/$f" ]] || fail "missing framework file: $f"
done

# Meta-domain copied in full, with the birth-time adoption ledger.
for f in domains/exobrain/entities.md domains/exobrain/scopes.md \
         domains/exobrain/propagation.md domains/exobrain/adopted-feed.md; do
    [[ -f "$INST/$f" ]] || fail "missing meta-domain file: $f"
done
[[ -d "$INST/domains/exobrain/feed" ]] || fail "missing domains/exobrain/feed/"

# The three shipped skills are present.
for s in exobrain-persist exobrain-update exobrain-reader-lens; do
    [[ -f "$INST/skills/$s/SKILL.md" ]] || fail "missing shipped skill: $s"
done
# The seed-local area (generator + tests) must never be copied into an instance.
[[ ! -e "$INST/seed" ]] || fail "seed/ (generator + tests) should not ship into the instance"

# Person + host scope flags.
[[ -f "$INST/people/test-user/AGENTS.md" ]] || fail "missing person scope AGENTS.md"
[[ -f "$INST/people/test-user/hosts/test-host/AGENTS.md" ]] || fail "missing host scope AGENTS.md"

# connect-agent.sh ran (a per-agent surface was generated). The builder is
# usually claude (.claude/CLAUDE.md); a codex builder leaves a .codex marker.
[[ -f "$INST/.claude/CLAUDE.md" || -e "$INST/.codex" || -f "$INST/CODEX.md" ]] \
    || fail "connect-agent.sh did not generate an agent surface (.claude/CLAUDE.md or .codex)"

# At least two durable domains beyond the meta-domain.
dcount="$(find "$INST/domains" -mindepth 1 -maxdepth 1 -type d ! -name exobrain 2>/dev/null | wc -l | tr -d ' ')"
[[ "$dcount" -ge 2 ]] || fail "expected >=2 starter domains, found $dcount"

pass "instance well-formed ($dcount starter domains)"
