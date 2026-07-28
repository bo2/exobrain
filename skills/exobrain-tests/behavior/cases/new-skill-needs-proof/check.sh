#!/usr/bin/env bash
# new-skill-needs-proof — authoring-review.sh section 0 blocks a newly declared,
# unproven shared-scope skill and clears once a committed proof signal is present.
# permission_profile: static (no agent) — this drives the gate directly.
set -uo pipefail
source "$HARNESS_LIB/check-helpers.sh"
INST="$1"
cd "$INST" || fail "instance dir missing"

[[ -x scripts/authoring-review.sh ]] || fail "scripts/authoring-review.sh missing or not executable"
[[ -f skills.json ]] || inconclusive "expected a global skills.json in the instance template"

git config user.email harness@exobrain.test >/dev/null 2>&1 || true
git config user.name  'exobrain harness'    >/dev/null 2>&1 || true
git checkout -q -b gate-probe || fail "could not branch off main"

# Stub the review engine so the model pass is hermetic: the gate under test runs
# before it, and a cleared gate must not reach for the network.
shim="$INST/.gate-shim"
mkdir -p "$shim"
for engine in claude codex; do
    printf '#!/usr/bin/env bash\ncat >/dev/null\necho AUTHORING-OK\n' > "$shim/$engine"
    chmod +x "$shim/$engine"
done
export PATH="$shim:$PATH"

probe="skills/zzz-gate-probe"

# --- 1. A new unproven global-scope skill is flagged (exit 2, named) ---
mkdir -p "$probe"
cat > "$probe/SKILL.md" <<'EOF'
---
name: zzz-gate-probe
description: "Gate probe used by the new-skill-needs-proof case."
---

# Gate probe
EOF
jq '.skills += [{"name":"zzz-gate-probe","owner":"maintainer","tier":"optional","force":true}]' \
    skills.json > skills.json.tmp && mv skills.json.tmp skills.json
git add -A && git commit -q -m "probe: declare an unproven shared skill"

out1="$(scripts/authoring-review.sh main 2>&1)"; rc1=$?
[[ "$rc1" -eq 2 ]] || fail "expected exit 2 on an unproven new shared skill, got $rc1"
grep -q "NEW SHARED SKILL" <<<"$out1" || fail "gate did not surface the NEW SHARED SKILL block"
grep -q "zzz-gate-probe"   <<<"$out1" || fail "gate did not name the new skill"

# --- 2. A committed in-dir test artifact clears the block ---
printf '# committed proof artifact for the probe skill\n' > "$probe/test_probe.sh"
git add -A && git commit -q -m "probe: commit a proof artifact"

out2="$(scripts/authoring-review.sh main 2>&1)"; rc2=$?
grep -q "NEW SHARED SKILL" <<<"$out2" && fail "proof artifact committed but the gate still flagged the skill"
[[ "$rc2" -ne 2 ]] || fail "gate still exited 2 after the proof artifact landed"

pass "gate blocks an unproven new shared skill (exit 2, named) and clears once proof is committed"
