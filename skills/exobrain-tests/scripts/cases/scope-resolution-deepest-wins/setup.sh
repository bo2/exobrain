#!/usr/bin/env bash
# Plant a global tool doc and a person-scope override that disagree on the
# runtime prerequisite. Deepest scope (person) should win.
set -uo pipefail
INST="$1"

mkdir -p "$INST/tools" "$INST/people/test-user/tools"

cat >"$INST/tools/acme.md" <<'EOF'
# acme

A command-line tool used across this exobrain.

## Prerequisites

- Runtime prerequisite: **Python 3** must be installed.
EOF

cat >"$INST/people/test-user/tools/acme.md" <<'EOF'
# acme (person-scope override)

Personal configuration for the acme tool on this person's setup.

## Prerequisites

- Runtime prerequisite: **Node.js 20** must be installed.
EOF
