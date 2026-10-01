#!/usr/bin/env bash
# Give the instance one enabled mount: a content-only repository with a bare
# origin beside the instance, cloned to the default checkout (src/<name>/), and
# declared with a charter in mounts.json. The fact the prompt corrects lives in
# the mount, so the only right place to change it is a worktree of that checkout.
#
# mounts.json is committed onto main so a worktree of the instance carries it;
# .exobrain.json and src/ are gitignored, as in a real checkout.
set -uo pipefail
INST="$1"
RUN="$(dirname "$INST")"
G=(-c user.email=harness@exobrain.test -c user.name='exobrain harness')

work="$RUN/mount-seed"
git init -q -b main "$work"
mkdir -p "$work/knowledge/billing"
printf '# Acme engineering\n\nShared knowledge about the billing system.\n' > "$work/README.md"
cat > "$work/knowledge/billing/README.md" <<'MD'
---
name: billing
type: system
curator: test-user
summary: How the billing system works and where it stands.
---

# Billing

- [`status.md`](status.md) — current state of the billing jobs.
MD
printf '# Billing status\n\nThe invoice export runs weekly, on Mondays.\n' > "$work/knowledge/billing/status.md"
git -C "$work" add -A && git -C "$work" "${G[@]}" commit -q -m "billing domain"
git clone -q --bare "$work" "$RUN/mount-origin.git"
rm -rf "$work"

mkdir -p "$INST/src"
git clone -q "$RUN/mount-origin.git" "$INST/src/acme-eng"
git -C "$INST/src/acme-eng" config user.email harness@exobrain.test
git -C "$INST/src/acme-eng" config user.name 'exobrain harness'

cat > "$INST/mounts.json" <<JSON
{
  "\$schema": "./mounts.schema.json",
  "instance": { "audience": ["alex"] },
  "mounts": [
    {
      "name": "acme-eng",
      "repo": "$RUN/mount-origin.git",
      "audience": ["alex", "sam"],
      "purpose": "Shared engineering knowledge about the billing system",
      "holds": { "billing": "How the billing system works and where it stands." }
    }
  ]
}
JSON
printf '{"mounts":{"acme-eng":{"enabled":true}}}\n' > "$INST/.exobrain.json"

git -C "$INST" add mounts.json
git -C "$INST" "${G[@]}" commit -q -m "case: declare the acme-eng mount" || true
