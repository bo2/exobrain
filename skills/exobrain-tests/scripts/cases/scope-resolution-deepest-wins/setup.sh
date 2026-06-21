#!/usr/bin/env bash
# Plant a global tool doc and a person-scope override that disagree on the
# runtime prerequisite. Deepest scope (person) should win.
#
# The person scope must be REAL, not just a directory holding a tool doc: an
# agent that inspects the fixture has to find a flagged, connected scope, or it
# rightly concludes the override is inert and the global doc wins. So flag the
# person and host scopes with AGENTS.md and record the connected leaf in
# .exobrain.json — the same shape a connected instance carries.
set -uo pipefail
INST="$1"

mkdir -p "$INST/tools" "$INST/people/test-user/tools" \
         "$INST/people/test-user/hosts/test-host"

cat >"$INST/people/test-user/AGENTS.md" <<'EOF'
# test-user — person scope

Agent context specific to this person.
EOF

cat >"$INST/people/test-user/hosts/test-host/AGENTS.md" <<'EOF'
# test-host — host scope

Agent context specific to this host.
EOF

cat >"$INST/.exobrain.json" <<'EOF'
{
  "connected_scopes": [
    "people/test-user/hosts/test-host"
  ],
  "agents": [
    "claude"
  ]
}
EOF

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
