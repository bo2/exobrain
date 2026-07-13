#!/usr/bin/env bash
# Deterministic connect-cascade probe (runs inside the fresh-machine container).
# Clones the real origin, overlays THIS instance's connect-agent, self-seeds
# synthetic scope fixtures, and asserts every cascade branch — connected scope,
# recorded person, and NO scaffolded folders — then healthcheck + validator on the
# connected clone. Portable: no dependency on any real person/group in the tree.
set -uo pipefail
log(){ echo "[probe] $*"; }

git config --global user.email probe@example.invalid
git config --global user.name probe
# Protect the real origin from any accidental push out of the probe copies.
git config --global url."NO-PUSH:".pushInsteadOf "$ORIGIN_URL"

log "cloning real origin + overlaying this instance's connect-agent"
git clone -q "$ORIGIN_URL" /home/newdev/base 2>/dev/null || { echo "CLONE FAILED: $ORIGIN_URL"; exit 1; }
cp /overlay/connect-agent.sh /home/newdev/base/scripts/connect-agent.sh
cp /overlay/skills-registry.sh /home/newdev/base/scripts/skills-registry.sh
chmod +x /home/newdev/base/scripts/*.sh

seed() {  # synthetic group + person (committed, so connect-agent's creations show as untracked)
  local r="$1"
  mkdir -p "$r/groups/insttest-group/people/insttester/hosts/knownhost"
  printf '# insttest-group — group scope\n' > "$r/groups/insttest-group/AGENTS.md"
  printf '# insttester — person scope\n' > "$r/groups/insttest-group/people/insttester/AGENTS.md"
  printf '# knownhost — host scope\n' > "$r/groups/insttest-group/people/insttester/hosts/knownhost/AGENTS.md"
  ( cd "$r" && git add -A && git commit -qm seed --no-gpg-sign ) >/dev/null 2>&1
}

FAILS=0
run_and_check() {  # <label> <expect_scopes_json> <expect_person> -- <flags...>
  local label="$1" exp_scopes="$2" exp_person="$3"; shift 4   # drop the literal --
  local dir="/home/newdev/case-$label"; rm -rf "$dir"; cp -r /home/newdev/base "$dir"; seed "$dir"
  bash "$dir/scripts/connect-agent.sh" claude "$@" >/dev/null 2>&1
  local got_scopes got_person newdirs ok=1
  got_scopes="$(jq -c '.connected_scopes' "$dir/.exobrain.json" 2>/dev/null || echo MISSING)"
  got_person="$(jq -r '.person // "null"' "$dir/.exobrain.json" 2>/dev/null)"
  newdirs="$(git -C "$dir" status --porcelain | grep -E '^\?\?.*(people|hosts)/' || true)"
  [ "$got_scopes" = "$exp_scopes" ] || { echo "  ✗ $label: connected_scopes got=$got_scopes want=$exp_scopes"; ok=0; }
  [ "$got_person"  = "$exp_person" ] || { echo "  ✗ $label: person got=$got_person want=$exp_person"; ok=0; }
  [ -z "$newdirs" ] || { echo "  ✗ $label: scaffolded folders: $newdirs"; ok=0; }
  [ $ok = 1 ] && echo "  ✓ $label" || FAILS=$((FAILS+1))
}

log "asserting the connect-cascade branches (flags never scaffold):"
# existing person, this host absent -> person scope
run_and_check person-no-host '["groups/insttest-group/people/insttester"]' insttester -- --handle insttester --host newmachine
# existing person + existing host -> host leaf
run_and_check existing-host  '["groups/insttest-group/people/insttester/hosts/knownhost"]' insttester -- --handle insttester --host knownhost
# unknown user -> nothing connected, no person recorded
run_and_check unknown-global '[]' null -- --handle nobody999
# unknown user + an explicit group scope -> the group scope only
run_and_check group-fallback '["groups/insttest-group"]' null -- --handle nobody999 --scope groups/insttest-group

log "post-connect health on the connected clone:"
HDIR=/home/newdev/case-existing-host
if out="$(bash "$HDIR/scripts/exobrain-healthcheck.sh" claude -v 2>&1)" && echo "$out" | grep -q 'connected'; then
  echo "  ✓ healthcheck: $out"
else
  echo "  ✗ healthcheck: $out"; FAILS=$((FAILS+1))
fi
if bash "$HDIR/scripts/validate-exobrain.sh" --quiet; then
  echo "  ✓ validate-exobrain clean"
else
  echo "  ✗ validate-exobrain reported violations"; FAILS=$((FAILS+1))
fi

echo
[ $FAILS -eq 0 ] && { echo "probe: all cascade branches + health OK (connected, identity recorded, zero folders)"; exit 0; } \
                 || { echo "probe: $FAILS check(s) FAILED"; exit 1; }
