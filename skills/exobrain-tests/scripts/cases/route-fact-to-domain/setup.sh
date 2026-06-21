#!/usr/bin/env bash
# Seed two routing targets so the case has somewhere to route INTO: a `finance`
# domain (the correct home for a financial holding) and a `home` domain (a
# plausible but too-generic wrong target). The base instance ships no domains,
# so without this the agent has no finance/home to choose between.
#
# Commit them onto main: a spec-following agent works worktree-first, branching
# off main, and an uncommitted seed wouldn't appear in that worktree.
set -uo pipefail
INST="$1"

mkdir -p "$INST/domains/finance" "$INST/domains/home"

cat >"$INST/domains/finance/README.md" <<'EOF'
---
name: finance
type: area
curator: test-user
---

# Finance

Durable truth about money: accounts, holdings, institutions, and where savings live.

## Accounts and holdings

Current accounts, the institutions that hold them, and where retirement and other
savings sit.
EOF

cat >"$INST/domains/home/README.md" <<'EOF'
---
name: home
type: area
curator: test-user
---

# Home

Durable truth about the house and household: the property, maintenance, and
day-to-day domestic logistics.

## Household

The home itself and how it runs.
EOF

git -C "$INST" add -A
git -C "$INST" \
    -c user.email=harness@exobrain.test -c user.name='exobrain harness' \
    commit -q -m "case: seed finance and home routing targets" || true
