#!/usr/bin/env bash
# The fx mount plus a local finance domain, so each fact has a home to go to.
set -uo pipefail
source "$HARNESS_LIB/seed-mount.sh"
INST="$1"
seed_mount "$INST"
mkdir -p "$INST/knowledge/finance"
cat >"$INST/knowledge/finance/README.md" <<'R'
---
name: finance
type: area
curator: test-user
summary: Durable truth about the household's money — accounts, institutions, subscriptions.
---

# Finance

## Accounts and subscriptions

Which account pays for what.
R
git -C "$INST" add -A
git -C "$INST" -c user.email=harness@exobrain.test -c user.name='exobrain harness' \
    commit -q -m "case: seed the finance domain" || true
