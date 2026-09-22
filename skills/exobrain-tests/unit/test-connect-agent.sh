#!/usr/bin/env bash
# test-connect-agent.sh — tests for the connector + skills registry under the
# scope-tree / opt-in model. Exercises the framework scripts in <repo>/scripts/ of
# whichever instance this suite is installed in.
#
#   skills/exobrain-tests/unit/test-connect-agent.sh            # run all
#   skills/exobrain-tests/unit/test-connect-agent.sh <pattern>  # filter by name
#
# Each test builds an isolated fake exobrain in a temp dir and wires the agent
# surface side-effect-free (connect-agent.sh --wire-sandbox with HOME /
# CODEX_HOME / OPENCLAW_WORKSPACE pointed at temp dirs), so nothing touches the
# real repo or ~/. Function-level checks source skills-registry.sh directly.

set -uo pipefail

TESTS_RUN=0; TESTS_PASSED=0; TESTS_FAILED=0; FAILURES=()
FILTER="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"          # .../exobrain-tests/unit
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"        # repo root: unit→exobrain-tests→skills→root
SCRIPTS_DIR="$REPO_DIR/scripts"                       # framework scripts under test
# shellcheck source=../../../scripts/skills-registry.sh
source "$SCRIPTS_DIR/skills-registry.sh"

RED='\033[0;31m'; GREEN='\033[0;32m'; DIM='\033[0;90m'; RESET='\033[0m'

run_test() {
    local name="$1"; shift
    [[ -n "$FILTER" && "$name" != *"$FILTER"* ]] && return 0
    TESTS_RUN=$((TESTS_RUN + 1))
    printf "${DIM}%-56s${RESET} " "$name"
    mkdir -p "$REPO_DIR/tmp"
    TEST_DIR="$(mktemp -d "$REPO_DIR/tmp/connect-agent.XXXXXX")"
    trap 'rm -rf "$TEST_DIR"' RETURN
    local output
    if output=$("$@" 2>&1); then
        TESTS_PASSED=$((TESTS_PASSED + 1)); printf "${GREEN}PASS${RESET}\n"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1)); FAILURES+=("$name"); printf "${RED}FAIL${RESET}\n"
        echo "$output" | sed 's/^/    /'
    fi
}

assert_eq()           { [[ "$1" == "$2" ]] || { echo "ASSERT_EQ${3:+ ($3)}: expected '$1', got '$2'"; return 1; }; }
assert_contains()     { [[ "$1" == *"$2"* ]] || { echo "ASSERT_CONTAINS${3:+ ($3)}: '$2' not in:"; echo "$1"; return 1; }; }
assert_not_contains() { [[ "$1" != *"$2"* ]] || { echo "ASSERT_NOT_CONTAINS${3:+ ($3)}: '$2' unexpectedly present"; return 1; }; }
assert_file()         { [[ -e "$1" ]] || { echo "ASSERT_FILE${2:+ ($2)}: $1 missing"; return 1; }; }
assert_no_file()      { [[ ! -e "$1" ]] || { echo "ASSERT_NO_FILE${2:+ ($2)}: $1 unexpectedly exists"; return 1; }; }
assert_symlink()      { [[ -L "$1" ]] || { echo "ASSERT_SYMLINK${2:+ ($2)}: $1 not a symlink"; return 1; }; }

# Everything a run left in a dir, one space-separated sorted line — for asserting
# exactly what a connect wrote into an agent's home config dir.
dir_listing()     { (cd "$1" && LC_ALL=C ls -A | LC_ALL=C sort | tr '\n' ' ' | sed 's/ $//'); }

claude_manifest() { cat "$1/.claude/connected-scopes.md"; }
claude_index()    { cat "$1/.claude/optional-skills.md"; }
claude_tools()    { cat "$1/.claude/tools-index.md"; }
claude_knowledge()  { cat "$1/.claude/knowledge-index.md"; }

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

setup_fake_exobrain() {
    local repo="$TEST_DIR/exobrain"
    mkdir -p "$repo/scripts"
    git -C "$repo" init -q
    cp "$SCRIPTS_DIR/connect-agent.sh"         "$repo/scripts/"
    cp "$SCRIPTS_DIR/skills-registry.sh"       "$repo/scripts/"
    cp "$SCRIPTS_DIR/fetch-external-skills.sh"  "$repo/scripts/"
    cp "$SCRIPTS_DIR/skills-validate.sh"        "$repo/scripts/"
    cp "$SCRIPTS_DIR/create-worktree.sh"        "$repo/scripts/"
    cp "$SCRIPTS_DIR/exobrain-healthcheck.sh"   "$repo/scripts/"
    cp "$SCRIPTS_DIR/strip-agent-attribution.sh" "$repo/scripts/"
    if [[ -f "$SCRIPTS_DIR/link-worktree-context.sh" ]]; then
        cp "$SCRIPTS_DIR/link-worktree-context.sh" "$repo/scripts/"
    fi
    cp "$REPO_DIR/skills.schema.json"          "$repo/"
    chmod +x "$repo/scripts/"*.sh
    printf '# Exobrain\n' > "$repo/AGENTS.md"
    printf '{"scopes":[{"type":"group","collection":"groups"},{"type":"person","collection":"people"},{"type":"host","collection":"hosts"}]}\n' > "$repo/scopes.json"
    printf '{"$schema":"./skills.schema.json","skills":[]}\n' > "$repo/skills.json"
    printf '.claude/\n.codex\n.agents/\n.openclaw\nAGENTS.override.md\n.exobrain.json\nsrc/\n' > "$repo/.gitignore"
    echo "$repo"
}

# add_group <repo> <group> — a group scope (groups/<g>/AGENTS.md) + empty registry.
add_group() {
    local repo="$1" g="$2"
    mkdir -p "$repo/groups/$g"
    printf '# %s — group scope\n' "$g" > "$repo/groups/$g/AGENTS.md"
    printf '{"$schema":"../../skills.schema.json","skills":[]}\n' > "$repo/groups/$g/skills.json"
}

# add_person <repo> <person-path> — person + host AGENTS.md at <person-path>
# (e.g. people/alice or groups/acme/people/alice). Host is <person-path>/hosts/h1.
add_person() {
    local repo="$1" p="$2"
    mkdir -p "$repo/$p/hosts/h1"
    printf '# person scope\n' > "$repo/$p/AGENTS.md"
    printf '# host scope\n' > "$repo/$p/hosts/h1/AGENTS.md"
}

# declare_skill <repo> <scope> <name> <tier> [force] — a declaration in <scope>'s
# skills.json, with a real skill dir + SKILL.md. owner = the scope leaf basename
# (or "owner" for global). force=true appends "force":true.
declare_skill() {
    local repo="$1" scope="$2" name="$3" tier="$4" force="${5:-}"
    local dir owner jf rel
    if [[ "$scope" == "global" ]]; then dir="$repo/skills/$name"; jf="$repo/skills.json"; owner="owner"; rel="./skills.schema.json"
    else dir="$repo/$scope/skills/$name"; jf="$repo/$scope/skills.json"; owner="${scope##*/}"
        local depth; depth="$(awk -F/ '{print NF}' <<< "$scope")"; rel=""; local i; for ((i=0;i<depth;i++)); do rel="../$rel"; done; rel="${rel}skills.schema.json"
    fi
    mkdir -p "$dir"
    printf -- '---\nname: %s\ndescription: desc for %s\n---\n# %s\n' "$name" "$name" "$name" > "$dir/SKILL.md"
    [[ -f "$jf" ]] || printf '{"$schema":"%s","skills":[]}\n' "$rel" > "$jf"
    local force_json=""; [[ "$force" == "force" ]] && force_json=',"force":true'
    jq --arg n "$name" --arg o "$owner" --arg t "$tier" \
       ".skills += [{name:\$n,owner:\$o,tier:\$t$force_json}]" "$jf" > "$jf.t" && mv "$jf.t" "$jf"
}

# override_skill <repo> <into-scope> <name> <from-scope> <tier> — write an override.
override_skill() {
    local repo="$1" into="$2" name="$3" from="$4" tier="$5" jf rel
    if [[ "$into" == "global" ]]; then jf="$repo/skills.json"; rel="./skills.schema.json"
    else jf="$repo/$into/skills.json"; local depth; depth="$(awk -F/ '{print NF}' <<< "$into")"; rel=""; local i; for ((i=0;i<depth;i++)); do rel="../$rel"; done; rel="${rel}skills.schema.json"; fi
    [[ -f "$jf" ]] || printf '{"$schema":"%s","skills":[]}\n' "$rel" > "$jf"
    jq --arg n "$name" --arg f "$from" --arg t "$tier" '.skills += [{name:$n,from:$f,tier:$t}]' "$jf" > "$jf.t" && mv "$jf.t" "$jf"
}

# add_tool <repo> <scope> <name> <summary> — tool doc; first content line = summary.
add_tool() {
    local repo="$1" scope="$2" name="$3" summary="$4" dir
    if [[ "$scope" == "global" ]]; then dir="$repo/tools"; else dir="$repo/$scope/tools"; fi
    mkdir -p "$dir"
    printf '# %s\n\n%s\n' "$name" "$summary" > "$dir/$name.md"
}

# add_domain <repo> <name> <summary> — domain README with frontmatter summary.
# Domains are root-only and unscoped, so there's no scope arg.
add_domain() {
    local repo="$1" name="$2" summary="$3"
    mkdir -p "$repo/knowledge/$name"
    printf -- '---\nname: %s\ntype: reference\ncurator: alice\nsummary: %s\n---\n\n# %s\n' \
        "$name" "$summary" "$name" > "$repo/knowledge/$name/README.md"
}

write_config() { printf '{"connected_scopes":["%s"],"agents":["%s"]}\n' "$2" "${3:-claude}" > "$1/.exobrain.json"; }

# fake_openclaw — a stand-in `openclaw` CLI for the connector's runtime-config step:
# `config get <path> --json` / `config set --batch-json <ops>` over a JSON file,
# every argv logged. Every wiring helper points OPENCLAW_BIN at it, so no test
# reaches a real openclaw binary or its config.
fake_openclaw() {
    mkdir -p "$TEST_DIR/bin"
    [[ -f "$TEST_DIR/oc-config.json" ]] || echo '{}' > "$TEST_DIR/oc-config.json"
    cat > "$TEST_DIR/bin/openclaw" <<EOF
#!/usr/bin/env bash
STATE="$TEST_DIR/oc-config.json"
echo "\$*" >> "$TEST_DIR/oc-calls.txt"
case "\$1 \$2" in
  "config get")
    v="\$(jq -c --arg p "\$3" 'getpath(\$p | split("."))' "\$STATE")"
    if [[ "\$v" == "null" ]]; then echo '{"ok":false}'; exit 1; fi
    echo "\$v" ;;
  "config set")
    jq --argjson ops "\$4" 'reduce \$ops[] as \$o (.; setpath(\$o.path | split("."); \$o.value))' "\$STATE" > "\$STATE.t" && mv "\$STATE.t" "\$STATE"
    echo "Updated \$(jq length <<< "\$4") config paths." ;;
  *) echo "fake openclaw: unsupported: \$*" >&2; exit 2 ;;
esac
EOF
    chmod +x "$TEST_DIR/bin/openclaw"
}
oc_config()    { jq -c "$1" "$TEST_DIR/oc-config.json"; }
oc_set_calls() { local n; n="$(grep -c "^config set" "$TEST_DIR/oc-calls.txt" 2>/dev/null)"; echo "${n:-0}"; }

# wire_sandbox <repo> <agent> — wire the agent surface side-effect-free, HOME-isolated.
wire_sandbox() {
    local repo="$1" agent="$2"
    mkdir -p "$TEST_DIR/home" "$TEST_DIR/codex" "$TEST_DIR/ocw"; fake_openclaw
    (cd "$repo" && env "HOME=$TEST_DIR/home" "CODEX_HOME=$TEST_DIR/codex" \
        "OPENCLAW_WORKSPACE=$TEST_DIR/ocw" "OPENCLAW_BIN=$TEST_DIR/bin/openclaw" bash scripts/connect-agent.sh "$agent" --wire-sandbox)
}

# wire_sandbox_flags <repo> <agent> <flag...> — wire with explicit identity flags, so
# resolve_from_flags runs and writes .exobrain.json into the sandbox.
wire_sandbox_flags() {
    local repo="$1" agent="$2"; shift 2
    mkdir -p "$TEST_DIR/home" "$TEST_DIR/codex" "$TEST_DIR/ocw"; fake_openclaw
    (cd "$repo" && env "HOME=$TEST_DIR/home" "CODEX_HOME=$TEST_DIR/codex" \
        "OPENCLAW_WORKSPACE=$TEST_DIR/ocw" "OPENCLAW_BIN=$TEST_DIR/bin/openclaw" bash scripts/connect-agent.sh "$agent" --wire-sandbox "$@")
}

# connect_flags <repo> <agent> <flag...> — a REAL connect, not a sandbox wiring: the only
# way to reach the marker, the git hooks, and the scope hooks. Everything it
# writes stays in the temp repo or the temp HOME.
connect_flags() {
    local repo="$1" agent="$2"; shift 2
    mkdir -p "$TEST_DIR/home" "$TEST_DIR/codex" "$TEST_DIR/ocw"; fake_openclaw
    (cd "$repo" && env "HOME=$TEST_DIR/home" "CODEX_HOME=$TEST_DIR/codex" \
        "OPENCLAW_WORKSPACE=$TEST_DIR/ocw" "OPENCLAW_BIN=$TEST_DIR/bin/openclaw" bash scripts/connect-agent.sh "$agent" "$@")
}

# relink <repo> <agent> — what the post-merge hook runs for each agent in turn.
relink() { connect_flags "$1" "$2" --relink; }

# add_scope_hook <repo> <scope> <agent-suffix|""> [exit-code] — an executable
# connect hook in <scope>/scripts that appends its argv to <repo>/hook-calls.txt.
add_scope_hook() {
    local repo="$1" scope="$2" suffix="$3" rc="${4:-0}" name="connect-agent"
    [[ -n "$suffix" ]] && name="connect-agent.$suffix"
    mkdir -p "$repo/$scope/scripts"
    cat > "$repo/$scope/scripts/$name.sh" <<EOF
#!/usr/bin/env bash
echo "$name|\$1|\$2|\$3" >> "$repo/hook-calls.txt"
[[ $rc -eq 0 ]] || echo "hook is unhappy" >&2
exit $rc
EOF
    chmod +x "$repo/$scope/scripts/$name.sh"
}

hook_calls() { cat "$1/hook-calls.txt" 2>/dev/null; }

# resolve <repo> <leaf> — TSV of resolved skills (empty agent = no filtering).
resolve() { skills_resolve "$1" "" "$2"; }
# tier of <name> in resolved TSV, or "ABSENT".
tier_of() { local t; t="$(awk -F'\t' -v n="$2" '$1==n{print $4}' <<< "$1")"; echo "${t:-ABSENT}"; }

# ---------------------------------------------------------------------------
# Tests — scope chain
# ---------------------------------------------------------------------------

test_scope_chain_shallow_to_deep() {
    local r; r="$(setup_fake_exobrain)"; add_group "$r" acme; add_person "$r" groups/acme/people/alice
    local chain; chain="$(build_scope_chain "$r" groups/acme/people/alice/hosts/h1 | tr '\n' ' ')"
    assert_eq "global groups/acme groups/acme/people/alice groups/acme/people/alice/hosts/h1 " "$chain" "chain shallow->deep"
}

# ---------------------------------------------------------------------------
# Tests — handle classification (what the setup wizard gates on)
# ---------------------------------------------------------------------------

test_person_scope_ids_lists_people_only() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice; add_person "$r" groups/acme/people/bob
    add_group "$r" acme
    mkdir -p "$r/lab"; printf '# lab\n' > "$r/lab/AGENTS.md"   # standalone scope, not a person
    assert_eq "alice bob" "$(person_scope_ids "$r" | tr '\n' ' ' | sed 's/ $//')" "person scopes at any depth, nothing else"
}

test_handle_free_when_unused() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    assert_eq "" "$(handle_taken_by "$r" carol)" "an unused id is free"
}

test_handle_taken_by_person() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    assert_eq "person people/alice" "$(handle_taken_by "$r" alice)" "an existing person is reported as such"
}

# The gate that matters: hosts (and any other scope type) share the handle
# namespace, because identity is name-matched. `--handle h1` would connect
# alice's host scope as if it were a person.
test_handle_taken_by_non_person_scope() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    assert_eq "host people/alice/hosts/h1" "$(handle_taken_by "$r" h1)" "a host name collides with the handle namespace"
}

test_generic_handles_flagged() {
    is_generic_handle admin   || { echo "admin not flagged"; return 1; }
    is_generic_handle ADMIN   || { echo "uppercase not flagged"; return 1; }
    is_generic_handle root    || { echo "root not flagged"; return 1; }
    is_generic_handle carol  && { echo "a real name was flagged"; return 1; }
    return 0
}

# ---------------------------------------------------------------------------
# Tests — scope hooks
# ---------------------------------------------------------------------------

test_scope_hook_runs_with_scope_args() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    add_scope_hook "$r" people/alice ""
    connect_flags "$r" claude --handle alice --host h1 >/dev/null 2>&1 || return 1
    assert_eq "connect-agent|claude|$r/.claude|$r/people/alice" "$(hook_calls "$r")" \
        "the hook gets agent, target dir, and its own scope dir"
}

# Every scope in the chain runs, shallow→deep — not just the connected leaf.
test_scope_hooks_run_shallow_to_deep() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    add_scope_hook "$r" people/alice ""
    add_scope_hook "$r" people/alice/hosts/h1 ""
    connect_flags "$r" claude --handle alice --host h1 >/dev/null 2>&1 || return 1
    assert_eq "people/alice people/alice/hosts/h1" \
        "$(hook_calls "$r" | sed "s|^[^|]*|$r|;s|.*$r/||" | tr '\n' ' ' | sed 's/ $//')" \
        "person hook runs before its host's"
}

test_scope_hook_agent_specific_is_filtered() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    add_scope_hook "$r" people/alice codex
    connect_flags "$r" claude --handle alice --host h1 >/dev/null 2>&1 || return 1
    assert_eq "" "$(hook_calls "$r")" "another agent's hook is not run" || return 1
    connect_flags "$r" codex --handle alice --host h1 >/dev/null 2>&1 || return 1
    assert_contains "$(hook_calls "$r")" "connect-agent.codex|codex|" "its own agent runs it"
}

# The universal hook and this agent's hook both run, universal first.
test_scope_hook_both_variants_run() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    add_scope_hook "$r" people/alice ""
    add_scope_hook "$r" people/alice claude
    connect_flags "$r" claude --handle alice --host h1 >/dev/null 2>&1 || return 1
    assert_eq "connect-agent connect-agent.claude" \
        "$(hook_calls "$r" | cut -d'|' -f1 | tr '\n' ' ' | sed 's/ $//')" "universal first, then agent-specific"
}

# A scope's own extra must never cost the human their wiring.
test_scope_hook_failure_is_reported_not_fatal() {
    local r out; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    add_scope_hook "$r" people/alice "" 3
    out="$(connect_flags "$r" claude --handle alice --host h1 2>&1)" || return 1
    assert_contains "$out" "failed (exit 3) — connect continues" "the failure is named" || return 1
    assert_contains "$out" "hook is unhappy" "its output is surfaced" || return 1
    assert_contains "$out" "✓ Connected claude." "the connect still completes"
}

# The same guarantee for the deepest scope's *last* hook failing **silently** —
# the case the loop tails decide, and the one an output-producing fixture can
# never reach. Printing the hook's (empty) output runs a read loop whose body
# ends on a false test; that status is the loop's, the enclosing loops' and
# finally run_scope_hooks', whose bare call site aborts the connect under
# `set -e` — after the surface is written and before "✓ Connected".
test_scope_hook_silent_failure_is_not_fatal() {
    local r out; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    mkdir -p "$r/people/alice/hosts/h1/scripts"
    printf '#!/usr/bin/env bash\nexit 4\n' > "$r/people/alice/hosts/h1/scripts/connect-agent.claude.sh"
    chmod +x "$r/people/alice/hosts/h1/scripts/connect-agent.claude.sh"
    out="$(connect_flags "$r" claude --handle alice --host h1 2>&1)" || return 1
    assert_contains "$out" "failed (exit 4) — connect continues" "the failure is named" || return 1
    assert_contains "$out" "✓ Connected claude." "the connect still completes"
}

# Wiring a sandbox promises no writes outside the target dir; a hook is arbitrary code.
test_scope_hooks_skipped_on_wire_sandbox() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    add_scope_hook "$r" people/alice ""
    wire_sandbox_flags "$r" claude --handle alice --host h1 >/dev/null 2>&1 || return 1
    assert_eq "" "$(hook_calls "$r")" "no hook runs under --wire-sandbox"
}

# The repo root's scripts/connect-agent.sh is the connector itself: running it as
# a scope hook would recurse.
test_global_connector_is_not_a_scope_hook() {
    local r out; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    out="$(connect_flags "$r" claude --handle alice --host h1 2>&1)" || return 1
    assert_eq "1" "$(grep -c '✓ Connected claude.' <<< "$out")" "the connector runs once, not recursively"
}

# ---------------------------------------------------------------------------
# Tests — the setup wizard, driven over a pty
# ---------------------------------------------------------------------------
# The wizard reads /dev/tty, so it only runs with a terminal attached. These
# drive it through one, which is the only way to reach the prompts, the handle
# gates, and the scope menu. `--configure` performs a real connect, contained to
# the temp repo (Claude's surface is <repo>/.claude, the hooks <repo>/.git).
# python3 supplies the pty; with none installed the cases self-skip, keeping the
# suite runnable on bash + jq alone.

# drive_wizard <repo> <answer>|<answer>|… — feed one answer each time the
# connector falls quiet; print the transcript.
drive_wizard() {
    local repo="$1" answers="$2"
    cat > "$TEST_DIR/drive.py" <<'PY'
import os, pty, select, sys, time
answers = os.environ["ANSWERS"].split("|")
pid, fd = pty.fork()
if pid == 0:
    os.execv(sys.argv[1], sys.argv[1:])
out, i, deadline = b"", 0, time.time() + 30
while time.time() < deadline:
    r, _, _ = select.select([fd], [], [], 0.4)
    if r:
        try:
            chunk = os.read(fd, 4096)
        except OSError:
            break
        if not chunk:
            break
        out += chunk
    elif i < len(answers):
        os.write(fd, (answers[i] + "\n").encode()); i += 1
    else:
        break
os.close(fd); os.waitpid(pid, 0)
sys.stdout.write(out.decode(errors="replace").replace("\r\n", "\n"))
PY
    ANSWERS="$answers" python3 "$TEST_DIR/drive.py" "$repo/scripts/connect-agent.sh" claude --configure 2>/dev/null
}

# wizard_fixture — two people (alice, zoe) so a menu always has an unchecked
# last row, and a fixed git email so the derived default handle is "dev".
wizard_fixture() {
    local r; r="$(setup_fake_exobrain)"
    add_person "$r" people/alice; add_person "$r" people/zoe
    git -C "$r" config user.email dev@example.com
    echo "$r"
}

test_wizard_gates_generic_and_taken_handles() {
    command -v python3 >/dev/null 2>&1 || { echo "SKIP: python3 unavailable"; return 0; }
    local r t; r="$(wizard_fixture)"
    t="$(drive_wizard "$r" 'admin|n|alice|n|h1|carol|mbp|||')"
    assert_contains "$t" "People already here: alice zoe" "existing people are listed up front" || return 1
    assert_contains "$t" "'admin' is a machine login" "a machine login is challenged" || return 1
    assert_contains "$t" "'alice' is an existing person scope" "an existing person is challenged" || return 1
    assert_contains "$t" "'h1' already names a host scope" "a non-person scope name is refused" || return 1
    assert_eq "carol" "$(jq -r '.person' "$r/.exobrain.json")" "the accepted handle is stored" || return 1
    assert_file "$r/people/carol/AGENTS.md" "the new person scope is scaffolded"
}

# A generic default is never offered for a bare Enter — the prompt drops its
# "[default]" and asks outright.
test_wizard_withholds_generic_default() {
    command -v python3 >/dev/null 2>&1 || { echo "SKIP: python3 unavailable"; return 0; }
    local r t; r="$(wizard_fixture)"
    git -C "$r" config user.email admin@example.com
    t="$(drive_wizard "$r" 'carol|mbp|||')"
    assert_not_contains "$t" "[admin]" "a machine login is not offered as the default" || return 1
    assert_eq "carol" "$(jq -r '.person' "$r/.exobrain.json")" "the typed handle is stored"
}

# Regression: the scope menu's last row is unchecked here (zoe's host). A
# selection loop that ends on a false test returns non-zero, and as a function's
# last command that aborted the whole wizard under `set -e` — after the human had
# answered every prompt, leaving no config behind.
test_wizard_completes_with_unchecked_last_row() {
    command -v python3 >/dev/null 2>&1 || { echo "SKIP: python3 unavailable"; return 0; }
    local r t; r="$(wizard_fixture)"
    t="$(drive_wizard "$r" 'alice|y|h1|||')"
    assert_contains "$t" "✓ Connected claude." "the connect runs to completion" || return 1
    assert_file "$r/.exobrain.json" "config is written" || return 1
    assert_eq "alice" "$(jq -r '.person' "$r/.exobrain.json")" "the joined person is stored" || return 1
    assert_eq "people/alice,people/alice/hosts/h1" \
        "$(jq -r '.connected_scopes | join(",")' "$r/.exobrain.json")" "person + host connected, zoe's left out"
}

# ---------------------------------------------------------------------------
# Tests — opt-in resolution (force / owner / override / deepest / off)
# ---------------------------------------------------------------------------

test_force_reaches_nonowner() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    declare_skill "$r" global shared optional force
    local res; res="$(resolve "$r" people/alice/hosts/h1)"
    assert_eq "optional" "$(tier_of "$res" shared)" "forced global reaches a non-owner"
}

test_owner_gated_off_for_others() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice; add_person "$r" people/bob
    declare_skill "$r" people/bob private optional   # owner=bob, not forced
    # alice connects → bob's private skill must be absent (off)
    local res; res="$(resolve "$r" people/alice/hosts/h1)"
    assert_eq "ABSENT" "$(tier_of "$res" private)" "non-owned, non-forced skill is off for others"
}

test_owner_match_enables_for_owner() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/bob
    declare_skill "$r" people/bob private always     # owner=bob, not forced
    local res; res="$(resolve "$r" people/bob/hosts/h1)"
    assert_eq "always" "$(tier_of "$res" private)" "owner-match enables own non-forced skill"
}

# The stored .person key is authoritative for owner-match, not the folder type:
# here the config names zoe while the connected person scope is bob, so bob's own
# owner-gated skill must go off and self-ids must be ["zoe"].
test_stored_person_overrides_type() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/bob
    declare_skill "$r" people/bob private always     # owner=bob, not forced
    printf '{"connected_scopes":["people/bob/hosts/h1"],"person":"zoe","agents":["claude"]}\n' > "$r/.exobrain.json"
    assert_eq '["zoe"]' "$(owner_self_ids "$r" people/bob/hosts/h1)" "stored .person wins over type-derivation" || return 1
    local res; res="$(resolve "$r" people/bob/hosts/h1)"
    assert_eq "ABSENT" "$(tier_of "$res" private)" "owner-match keys off stored person, not folder type"
}

test_override_opts_in() {
    local r; r="$(setup_fake_exobrain)"; add_group "$r" acme; add_person "$r" groups/acme/people/alice
    declare_skill "$r" groups/acme team-skill optional        # group decl, owner=acme, not forced
    override_skill "$r" groups/acme/people/alice team-skill groups/acme always  # alice opts in
    local res; res="$(resolve "$r" groups/acme/people/alice/hosts/h1)"
    assert_eq "always" "$(tier_of "$res" team-skill)" "override opts a non-forced skill in"
}

test_override_off_shadows_force() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    declare_skill "$r" global shared always force             # forced global
    override_skill "$r" people/alice shared global off        # alice opts out
    local res; res="$(resolve "$r" people/alice/hosts/h1)"
    assert_eq "off" "$(tier_of "$res" shared)" "deeper off override shadows a forced global"
}

test_deepest_override_wins() {
    local r; r="$(setup_fake_exobrain)"; add_group "$r" acme; add_person "$r" groups/acme/people/alice
    declare_skill "$r" global shared optional force
    override_skill "$r" groups/acme shared global always      # group says always
    override_skill "$r" groups/acme/people/alice shared global unlisted  # person says unlisted (deeper)
    local res; res="$(resolve "$r" groups/acme/people/alice/hosts/h1)"
    assert_eq "unlisted" "$(tier_of "$res" shared)" "deepest override wins"
}

test_unlisted_resolves() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    declare_skill "$r" global danger unlisted force
    local res; res="$(resolve "$r" people/alice/hosts/h1)"
    assert_eq "unlisted" "$(tier_of "$res" danger)" "unlisted resolves as unlisted"
}

# ---------------------------------------------------------------------------
# Tests — description extraction (what the optional-skills index renders)
# ---------------------------------------------------------------------------

# write_desc <file> <frontmatter-description-lines> — a SKILL.md whose frontmatter
# carries the given raw `description:` text, verbatim.
write_desc() { mkdir -p "$(dirname "$1")"; printf -- '---\nname: s\n%b\n---\n# body\ndescription: body line, not frontmatter\n' "$2" > "$1"; }

test_description_single_line_forms() {
    local f="$TEST_DIR/s/SKILL.md"
    write_desc "$f" 'description: a plain one liner'
    assert_eq "a plain one liner" "$(skills_extract_description "$f")" "plain scalar" || return 1
    write_desc "$f" 'description: "a quoted one liner"'
    assert_eq "a quoted one liner" "$(skills_extract_description "$f")" "double-quoted scalar" || return 1
    write_desc "$f" "description: 'a quoted one liner'"
    assert_eq "a quoted one liner" "$(skills_extract_description "$f")" "single-quoted scalar"
}

# The reported defect: a folded description rendered as the bare fold indicator,
# leaving the index row blank for exactly the skills it had to describe.
test_description_folded_block() {
    local f="$TEST_DIR/s/SKILL.md"
    write_desc "$f" 'description: >\n  line one\n  line two'
    assert_eq "line one line two" "$(skills_extract_description "$f")" "folded block joined" || return 1
    write_desc "$f" 'description: |\n  line one\n  line two'
    assert_eq "line one line two" "$(skills_extract_description "$f")" "literal block joined" || return 1
    write_desc "$f" 'description: >-\n  chomped'
    assert_eq "chomped" "$(skills_extract_description "$f")" "chomping indicator accepted" || return 1
    write_desc "$f" 'description: >\n  para one\n\n  para two'
    assert_eq "para one para two" "$(skills_extract_description "$f")" "blank line inside the block folded"
}

# A block scalar must stop at the next key and at the frontmatter fence — bleeding
# into either one puts YAML or body prose in the index row.
test_description_block_stops_at_boundaries() {
    local f="$TEST_DIR/s/SKILL.md"
    write_desc "$f" 'description: >\n  the description\nname: not-the-description'
    assert_eq "the description" "$(skills_extract_description "$f")" "stops at the next key" || return 1
    write_desc "$f" 'description: >\n  the description'
    assert_eq "the description" "$(skills_extract_description "$f")" "stops at the closing fence"
}

test_description_absent_or_body_only() {
    local f="$TEST_DIR/s/SKILL.md"
    printf -- '---\nname: s\n---\n# body\ndescription: body line\n' > "$f"
    assert_eq "" "$(skills_extract_description "$f")" "no frontmatter description" || return 1
    printf -- '# body\ndescription: body line\n' > "$f"
    assert_eq "" "$(skills_extract_description "$f")" "body text is not frontmatter" || return 1
    assert_eq "" "$(skills_extract_description "$TEST_DIR/s/missing.md")" "missing file"
}

# End to end: a folded description has to survive into the generated index, which
# is the only thing telling the agent what an un-loaded optional skill does.
test_optional_index_carries_folded_description() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    declare_skill "$r" global optme optional force
    write_desc "$r/skills/optme/SKILL.md" 'description: >\n  folded across\n  two lines'
    write_config "$r" people/alice/hosts/h1
    wire_sandbox "$r" claude >/dev/null 2>&1 || return 1
    local i; i="$(claude_index "$r")"
    assert_contains "$i" "folded across two lines" "folded description rendered in the index" || return 1
    assert_not_contains "$i" "| > |" "no bare fold indicator as the summary"
}

# ---------------------------------------------------------------------------
# Tests — tools resolution
# ---------------------------------------------------------------------------

test_tools_resolve_deepest_wins() {
    local r; r="$(setup_fake_exobrain)"; add_group "$r" acme; add_person "$r" groups/acme/people/alice
    add_tool "$r" global dup "shallow global dup."
    add_tool "$r" groups/acme dup "deep group dup."
    add_tool "$r" global gtool "global only."
    local tsv; tsv="$(tools_resolve "$r" groups/acme/people/alice/hosts/h1)"
    assert_contains "$tsv" "groups/acme/tools/dup.md" "deepest tool doc wins" || return 1
    assert_not_contains "$tsv" "$(printf 'dup\ttools/dup.md')" "shallow dup shadowed" || return 1
    assert_contains "$tsv" "gtool" "global-only tool present"
}

test_tools_resolve_excludes_template() {
    local r; r="$(setup_fake_exobrain)"
    add_tool "$r" global example-tool "the template."
    printf '# Tools\nreadme.\n' > "$r/tools/README.md"
    local tsv; tsv="$(tools_resolve "$r" "")"
    assert_eq "" "$tsv" "README + example-tool excluded from the catalog"
}

# ---------------------------------------------------------------------------
# Tests — Claude surface (manifest of @-imports)
# ---------------------------------------------------------------------------

test_claude_manifest_relative_and_resolves() {
    local r; r="$(setup_fake_exobrain)"; add_group "$r" acme; add_person "$r" groups/acme/people/alice
    write_config "$r" groups/acme/people/alice/hosts/h1
    wire_sandbox "$r" claude >/dev/null 2>&1 || return 1
    local m; m="$(claude_manifest "$r")"
    assert_contains "$m" "@../groups/acme/AGENTS.md" "group spec imported (relative)" || return 1
    assert_contains "$m" "@../groups/acme/people/alice/AGENTS.md" "person spec imported" || return 1
    assert_not_contains "$m" "@../AGENTS.md" "global omitted from manifest (loaded via root CLAUDE.md)" || return 1
    # every @-import resolves to a real file, relative to .claude/
    local p; while IFS= read -r p; do
        [[ -z "$p" ]] && continue
        assert_file "$r/.claude/${p#@}" "manifest import resolves: $p" || return 1
    done < <(grep '^@' <<< "$m")
    assert_file "$r/.claude/CLAUDE.md" "generated CLAUDE.md" || return 1
    local c; c="$(cat "$r/.claude/CLAUDE.md")"
    assert_contains "$c" "@connected-scopes.md" "CLAUDE.md imports manifest" || return 1
    assert_no_file "$r/.claude/AGENTS.override.md" "no stale inlined override"
}

# Claude is the one surface that reads the indexes as files on disk, so every
# @-import in the generated CLAUDE.md must land on one.
test_claude_index_imports_resolve() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    declare_skill "$r" global optme optional force
    add_tool "$r" global github "Read and act on GitHub via the gh CLI."
    add_domain "$r" health "Conditions, meds, providers, and insurance."
    write_config "$r" people/alice/hosts/h1
    wire_sandbox "$r" claude >/dev/null 2>&1 || return 1
    local c; c="$(cat "$r/.claude/CLAUDE.md")"
    assert_contains "$c" "@optional-skills.md" "CLAUDE.md imports the optional-skills index" || return 1
    assert_contains "$c" "@tools-index.md" "CLAUDE.md imports the tools index" || return 1
    assert_contains "$c" "@knowledge-index.md" "CLAUDE.md imports the knowledge index" || return 1
    local p; while IFS= read -r p; do
        [[ -z "$p" ]] && continue
        assert_file "$r/.claude/${p#@}" "CLAUDE.md import resolves: $p" || return 1
    done < <(grep '^@' <<< "$c")
    # The durable copies carry the generated content, not an empty placeholder.
    assert_contains "$(claude_index "$r")" "optme" "optional-skills.md holds its rows" || return 1
    assert_contains "$(claude_tools "$r")" "github" "tools-index.md holds its rows" || return 1
    assert_contains "$(claude_knowledge "$r")" "health" "knowledge-index.md holds its rows"
}

# Regression for the set -e abort: a connected scope with no per-agent sidecar must
# still wire cleanly (the manifest emitter's last branch returns 0).
test_wire_no_sidecar_exit0() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice  # no CLAUDE.md sidecars
    write_config "$r" people/alice/hosts/h1
    wire_sandbox "$r" claude >/dev/null 2>&1
    assert_eq "0" "$?" "wiring exits 0 when scopes lack sidecars"
}

test_always_skill_linked_unlisted_not() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    declare_skill "$r" global linkme always force
    declare_skill "$r" global hideme unlisted force
    declare_skill "$r" global optme optional force
    write_config "$r" people/alice/hosts/h1
    wire_sandbox "$r" claude >/dev/null 2>&1 || return 1
    assert_symlink "$r/.claude/skills/linkme" "always skill linked" || return 1
    assert_no_file "$r/.claude/skills/hideme" "unlisted skill not linked" || return 1
    local idx; idx="$(claude_index "$r")"
    assert_contains "$idx" "optme" "optional skill indexed" || return 1
    assert_not_contains "$idx" "hideme" "unlisted skill not in optional index"
}

# ---------------------------------------------------------------------------
# Tests — Codex surface (in-repo AGENTS.override.md, read natively)
# ---------------------------------------------------------------------------

test_codex_inlines_specs() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    write_config "$r" people/alice/hosts/h1 codex
    wire_sandbox "$r" codex >/dev/null 2>&1 || return 1
    assert_file "$r/AGENTS.override.md" "codex override generated in-repo" || return 1
    local a; a="$(cat "$r/AGENTS.override.md")"
    # The override supersedes the bare AGENTS.md, so it must carry the root spec…
    assert_contains "$a" "<!-- scope: global -->" "root spec inlined into override" || return 1
    # …plus each deeper scope's spec.
    assert_contains "$a" "person scope" "person spec inlined into override" || return 1
    # Codex's surface is in-repo, not in CODEX_HOME.
    assert_no_file "$TEST_DIR/codex/AGENTS.md" "no marker block left in ~/.codex/AGENTS.md"
}

# The indexes are build inputs for the composed surface, not deliverables: Codex
# reads them inlined in the override, so nothing belongs in CODEX_HOME — a shared
# dir two checkouts would overwrite, and which the connector leaves untouched.
test_codex_indexes_inlined_not_in_home() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    declare_skill "$r" global optme optional force
    add_tool "$r" global github "Read and act on GitHub via the gh CLI."
    add_domain "$r" health "Conditions, meds, providers, and insurance."
    write_config "$r" people/alice/hosts/h1 codex
    wire_sandbox "$r" codex >/dev/null 2>&1 || return 1
    local a; a="$(cat "$r/AGENTS.override.md")"
    assert_contains "$a" "<!-- optional-skills index -->" "optional-skills index inlined" || return 1
    assert_contains "$a" "<!-- tools index -->" "tools index inlined" || return 1
    assert_contains "$a" "<!-- knowledge index -->" "knowledge index inlined" || return 1
    assert_contains "$a" "optme" "optional skill row inlined" || return 1
    assert_contains "$a" "github" "tool row inlined" || return 1
    assert_contains "$a" "health" "domain row inlined" || return 1
    assert_eq "" "$(dir_listing "$TEST_DIR/codex")" \
        "nothing written to CODEX_HOME"
}

# A sandbox wiring advertised as side-effect-free must refuse the one default that isn't:
# openclaw's USER.md targets the real home config dir when the override is unset.
test_wire_openclaw_refuses_without_workspace() {
    local r out; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    write_config "$r" people/alice/hosts/h1 openclaw
    out="$(cd "$r" && env "HOME=$TEST_DIR/hm" "CODEX_HOME=$TEST_DIR/codex" "OPENCLAW_WORKSPACE=" \
        bash scripts/connect-agent.sh openclaw --wire-sandbox 2>&1)" && { echo "should refuse"; return 1; }
    assert_contains "$out" "OPENCLAW_WORKSPACE" "error names the override" || return 1
    assert_no_file "$TEST_DIR/hm/.openclaw/workspace/USER.md" "nothing written to home workspace"
}

# ---------------------------------------------------------------------------
# Tests — OpenClaw surface (USER.md marker block)
# ---------------------------------------------------------------------------

test_openclaw_indexes_inlined_not_in_home() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    declare_skill "$r" global optme optional force
    add_tool "$r" global github "Read and act on GitHub via the gh CLI."
    add_domain "$r" health "Conditions, meds, providers, and insurance."
    write_config "$r" people/alice/hosts/h1 openclaw
    wire_sandbox "$r" openclaw >/dev/null 2>&1 || return 1
    local u; u="$(cat "$TEST_DIR/ocw/USER.md")"
    assert_contains "$u" "<!-- optional-skills index -->" "optional-skills index inlined" || return 1
    assert_contains "$u" "<!-- tools index -->" "tools index inlined" || return 1
    assert_contains "$u" "<!-- knowledge index -->" "knowledge index inlined" || return 1
    assert_contains "$u" "optme" "optional skill row inlined" || return 1
    assert_contains "$u" "github" "tool row inlined" || return 1
    assert_contains "$u" "health" "domain row inlined" || return 1
    # USER.md is the surface; no index files alongside it.
    assert_no_file "$TEST_DIR/ocw/optional-skills.md" "no optional-skills.md in OPENCLAW_WORKSPACE" || return 1
    assert_no_file "$TEST_DIR/ocw/tools-index.md" "no tools-index.md in OPENCLAW_WORKSPACE" || return 1
    assert_no_file "$TEST_DIR/ocw/knowledge-index.md" "no knowledge-index.md in OPENCLAW_WORKSPACE" || return 1
    # USER.md is the surface; skills/ is OpenClaw's always-tier link dir. Nothing else.
    assert_eq "USER.md skills" "$(dir_listing "$TEST_DIR/ocw")" \
        "only USER.md + the skills link dir written to OPENCLAW_WORKSPACE"
}

# ---------------------------------------------------------------------------
# Tests — tools index injection
# ---------------------------------------------------------------------------

test_tools_index_claude() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    add_tool "$r" global github "Read and act on GitHub via the gh CLI."
    write_config "$r" people/alice/hosts/h1
    wire_sandbox "$r" claude >/dev/null 2>&1 || return 1
    assert_file "$r/.claude/tools-index.md" "tools-index.md generated" || return 1
    local t; t="$(claude_tools "$r")"
    assert_contains "$t" "github" "tool row present" || return 1
    assert_contains "$t" "Read and act on GitHub via the gh CLI." "first-line summary extracted" || return 1
    local c; c="$(cat "$r/.claude/CLAUDE.md")"
    assert_contains "$c" "@tools-index.md" "CLAUDE.md imports the tools index"
}

test_tools_index_empty_skip() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice  # no tool docs
    write_config "$r" people/alice/hosts/h1
    wire_sandbox "$r" claude >/dev/null 2>&1 || return 1
    assert_no_file "$r/.claude/tools-index.md" "no tools-index.md when no tool docs" || return 1
    local c; c="$(cat "$r/.claude/CLAUDE.md")"
    assert_not_contains "$c" "@tools-index.md" "CLAUDE.md does not import a missing tools index"
}

# ---------------------------------------------------------------------------
# Tests — knowledge index injection
# ---------------------------------------------------------------------------

test_knowledge_index_claude() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    add_domain "$r" health "Conditions, meds, providers, and insurance."
    write_config "$r" people/alice/hosts/h1
    wire_sandbox "$r" claude >/dev/null 2>&1 || return 1
    assert_file "$r/.claude/knowledge-index.md" "knowledge-index.md generated" || return 1
    local d; d="$(claude_knowledge "$r")"
    # Both dead-copy prunes identify a stale index by this heading rather than by
    # name, so a human's same-named file survives — change the heading, change them.
    assert_contains "$d" "# Knowledge domains" "heading matches the dead-copy prunes" || return 1
    assert_contains "$d" "health" "domain row present" || return 1
    assert_contains "$d" "knowledge/health/README.md" "README path present" || return 1
    assert_contains "$d" "Conditions, meds, providers, and insurance." "summary extracted from frontmatter" || return 1
    local c; c="$(cat "$r/.claude/CLAUDE.md")"
    assert_contains "$c" "@knowledge-index.md" "CLAUDE.md imports the knowledge index"
}

# A domain (or tool doc) going away must take its durable copy with it — otherwise
# Claude keeps @-importing an index that no longer describes the checkout.
test_claude_index_removed_when_source_goes() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    add_domain "$r" health "Conditions, meds, providers, and insurance."
    add_tool "$r" global github "Read and act on GitHub via the gh CLI."
    write_config "$r" people/alice/hosts/h1
    wire_sandbox "$r" claude >/dev/null 2>&1 || return 1
    assert_file "$r/.claude/knowledge-index.md" "knowledge index present while the domain exists" || return 1
    rm -rf "$r/knowledge" "$r/tools"
    wire_sandbox "$r" claude >/dev/null 2>&1 || return 1
    assert_no_file "$r/.claude/knowledge-index.md" "stale knowledge index cleared on relink" || return 1
    assert_no_file "$r/.claude/tools-index.md" "stale tools index cleared on relink" || return 1
    local c; c="$(cat "$r/.claude/CLAUDE.md")"
    assert_not_contains "$c" "@knowledge-index.md" "CLAUDE.md drops the removed knowledge import" || return 1
    assert_not_contains "$c" "@tools-index.md" "CLAUDE.md drops the removed tools import"
}

test_knowledge_index_empty_skip() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice  # no knowledge/
    write_config "$r" people/alice/hosts/h1
    wire_sandbox "$r" claude >/dev/null 2>&1 || return 1
    assert_no_file "$r/.claude/knowledge-index.md" "no knowledge-index.md when no knowledge/" || return 1
    local c; c="$(cat "$r/.claude/CLAUDE.md")"
    assert_not_contains "$c" "@knowledge-index.md" "CLAUDE.md does not import a missing knowledge index"
}

# ---------------------------------------------------------------------------
# Tests — connect marker / --relink gating
# ---------------------------------------------------------------------------

# fresh_clone_claude_dir <repo> — the shape every clone has before anyone
# connects: .claude/ exists because settings.json is committed, nothing else.
fresh_clone_claude_dir() {
    mkdir -p "$1/.claude"
    printf '{"hooks":{}}\n' > "$1/.claude/settings.json"
}

# The post-merge hook relinks all three agents and leans entirely on this guard,
# so a marker a clone carries for free would connect an agent nobody chose.
test_relink_skips_unconnected_claude() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    write_config "$r" people/alice/hosts/h1
    fresh_clone_claude_dir "$r"
    relink "$r" claude >/dev/null 2>&1 || return 1
    assert_eq "settings.json" "$(dir_listing "$r/.claude")" "relink wrote nothing into .claude/" || return 1
    assert_no_file "$r/.git/hooks/post-merge" "a skipped relink installs no hooks"
}

test_relink_skips_unconnected_file_marker_agents() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    write_config "$r" people/alice/hosts/h1
    relink "$r" codex >/dev/null 2>&1 || return 1
    relink "$r" openclaw >/dev/null 2>&1 || return 1
    assert_no_file "$r/AGENTS.override.md" "codex surface absent without a marker" || return 1
    assert_no_file "$r/.agents/skills" "codex skills unlinked without a marker" || return 1
    assert_eq "" "$(dir_listing "$TEST_DIR/codex")" "nothing written to CODEX_HOME" || return 1
    assert_eq "" "$(dir_listing "$TEST_DIR/ocw")" "nothing written to OPENCLAW_WORKSPACE"
}

# The other half: once connected, a relink must still refresh the surface.
test_relink_refreshes_connected_claude() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    write_config "$r" people/alice/hosts/h1
    fresh_clone_claude_dir "$r"
    connect_flags "$r" claude >/dev/null 2>&1 || return 1
    assert_file "$r/.claude/CLAUDE.md" "connect writes the marker" || return 1
    rm -f "$r/.claude/connected-scopes.md"
    relink "$r" claude >/dev/null 2>&1 || return 1
    assert_file "$r/.claude/connected-scopes.md" "relink regenerated the surface" || return 1
    assert_file "$r/.git/hooks/post-merge" "relink refreshed the hooks"
}

# relink_all <repo> [flag...] — `--relink` with no agent, HOME-isolated like connect_flags.
relink_all() {
    local repo="$1"; shift
    mkdir -p "$TEST_DIR/home" "$TEST_DIR/codex" "$TEST_DIR/ocw"; fake_openclaw
    (cd "$repo" && env "HOME=$TEST_DIR/home" "CODEX_HOME=$TEST_DIR/codex" \
        "OPENCLAW_WORKSPACE=$TEST_DIR/ocw" "OPENCLAW_BIN=$TEST_DIR/bin/openclaw" bash scripts/connect-agent.sh --relink "$@")
}

# With no agent named, --relink refreshes every connected agent and leaves the rest alone.
test_relink_all_connected_agents() {
    local r out; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    write_config "$r" people/alice/hosts/h1
    fresh_clone_claude_dir "$r"
    connect_flags "$r" claude >/dev/null 2>&1 || return 1
    connect_flags "$r" codex >/dev/null 2>&1 || return 1
    add_domain "$r" health "Conditions, meds, providers, and insurance."
    out="$(relink_all "$r" 2>&1)" || { echo "$out"; return 1; }
    assert_contains "$(claude_knowledge "$r")" "health" "claude surface refreshed" || return 1
    assert_contains "$(cat "$r/AGENTS.override.md")" "health" "codex surface refreshed" || return 1
    assert_contains "$out" "── claude" "claude relinked" || return 1
    assert_contains "$out" "── codex" "codex relinked" || return 1
    assert_not_contains "$out" "── openclaw" "unconnected openclaw skipped" || return 1
    assert_eq "" "$(dir_listing "$TEST_DIR/ocw")" "nothing written to OPENCLAW_WORKSPACE"
}

test_relink_all_nothing_connected() {
    local r out; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    write_config "$r" people/alice/hosts/h1
    fresh_clone_claude_dir "$r"
    out="$(relink_all "$r" 2>&1)" || { echo "exit non-zero: $out"; return 1; }
    assert_contains "$out" "No agent is connected" || return 1
    assert_eq "settings.json" "$(dir_listing "$r/.claude")" "nothing written into .claude/" || return 1
    assert_no_file "$r/.git/hooks/post-merge" "no hooks installed"
}

test_relink_all_refuses_other_flags() {
    local r out; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    write_config "$r" people/alice/hosts/h1
    out="$(relink_all "$r" --configure 2>&1)"; local rc=$?
    assert_eq "2" "$rc" "usage error" || return 1
    assert_contains "$out" "takes no other flags"
}

# ---------------------------------------------------------------------------
# Tests — git hooks
# ---------------------------------------------------------------------------

# The hooks are the only thing keeping a checkout's surface fresh after a pull, and
# install_hook locates them through git's --git-common-dir, which answers relative
# to the repo. Resolved against the caller's cwd instead, the hooks land wherever
# the human was standing and the repo silently gets none.
test_hooks_install_into_repo_from_other_cwd() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    mkdir -p "$TEST_DIR/elsewhere" "$TEST_DIR/home"
    (cd "$TEST_DIR/elsewhere" && env "HOME=$TEST_DIR/home" \
        bash "$r/scripts/connect-agent.sh" claude --handle alice --host h1) >/dev/null 2>&1 || return 1
    assert_file "$r/.git/hooks/post-merge" "hooks installed in the repo" || return 1
    assert_no_file "$TEST_DIR/elsewhere/.git" "nothing created in the caller's cwd"
}

# Whatever the committing agent was told to append, a connected checkout's history
# stays agent-neutral: the commit-msg hook strips the attribution as the commit is made.
test_commit_msg_hook_strips_agent_attribution() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    write_config "$r" people/alice/hosts/h1
    fresh_clone_claude_dir "$r"
    connect_flags "$r" claude >/dev/null 2>&1 || return 1
    assert_file "$r/.git/hooks/commit-msg" "commit-msg hook installed" || return 1
    git -C "$r" -c user.email=t@example.com -c user.name=t -c commit.gpgsign=false \
        commit -q --allow-empty -m $'Change x\n\nCo-Authored-By: Claude Opus 5 <noreply@anthropic.com>' 2>/dev/null || return 1
    local msg; msg="$(git -C "$r" log -1 --format=%B)"
    assert_contains "$msg" "Change x" "message kept" || return 1
    assert_not_contains "$msg" "Co-Authored-By" "trailer stripped"
}

# ---------------------------------------------------------------------------
# Tests — validator
# ---------------------------------------------------------------------------

# The portability gate. A published rule did not keep bash-4 constructs out of the
# framework, so the constructs themselves are checked — while the prose that
# discusses them stays writable.
test_validate_flags_bash4_constructs() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    cp "$SCRIPTS_DIR/validate-exobrain.sh" "$r/scripts/"
    printf '#!/usr/bin/env bash\ndeclare -A m=()\n# a comment naming mapfile and declare -A\n' \
        > "$r/scripts/probe.sh"
    local o; o="$(cd "$r" && bash scripts/validate-exobrain.sh 2>&1)"
    assert_contains "$o" "bash 4 construct in scripts/probe.sh:2" "flagged with its line" || return 1
    assert_not_contains "$o" "scripts/probe.sh:3" "a comment mentioning one is not flagged"
}

# The companion gate. Names are collected repo-wide, so the array assigned empty
# in one file is still caught where another expands it — the shape that let the
# behavioral harness die before the agent started.
test_validate_flags_unguarded_array_expansion() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    cp "$SCRIPTS_DIR/validate-exobrain.sh" "$r/scripts/"
    printf '#!/usr/bin/env bash\nSINK=()\n' > "$r/scripts/lib.sh"
    printf '#!/usr/bin/env bash\nfoo "${SINK[@]}"\n# prose naming "${SINK[@]}"\n' > "$r/scripts/probe.sh"
    local o; o="$(cd "$r" && bash scripts/validate-exobrain.sh 2>&1)"
    assert_contains "$o" "unguarded array expansion in scripts/probe.sh:2" "flagged across files" || return 1
    assert_not_contains "$o" "scripts/probe.sh:3" "a comment mentioning one is not flagged"
}

test_validate_guarded_array_expansion_passes() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    cp "$SCRIPTS_DIR/validate-exobrain.sh" "$r/scripts/"
    printf '#!/usr/bin/env bash\nSINK=()\nfoo ${SINK[@]+"${SINK[@]}"}\n' > "$r/scripts/probe.sh"
    local o; o="$(cd "$r" && bash scripts/validate-exobrain.sh 2>&1)"
    assert_not_contains "$o" "unguarded array expansion" "the guarded form is not flagged as its own substring"
}

test_validate_ignores_never_empty_array() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    cp "$SCRIPTS_DIR/validate-exobrain.sh" "$r/scripts/"
    printf '#!/usr/bin/env bash\nfixed=(one two)\nrun "${fixed[@]}"\n' > "$r/scripts/probe.sh"
    local o; o="$(cd "$r" && bash scripts/validate-exobrain.sh 2>&1)"
    assert_not_contains "$o" "unguarded array expansion" "a never-empty array is not flagged"
}

test_validate_bash4_optout_honored() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    cp "$SCRIPTS_DIR/validate-exobrain.sh" "$r/scripts/"
    printf '#!/usr/bin/env bash\n# exobrain-allow-bash4 — deliberately bash 4 only\nmapfile -t a < <(echo hi)\n' \
        > "$r/scripts/probe.sh"
    local o; o="$(cd "$r" && bash scripts/validate-exobrain.sh 2>&1)"
    assert_not_contains "$o" "bash 4 construct" "an opted-out script is skipped"
}

test_validate_clean() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    declare_skill "$r" global ok optional force
    (cd "$r" && bash scripts/skills-validate.sh >/dev/null 2>&1)
    assert_eq "0" "$?" "valid registry passes validation"
}

test_validate_dangling_override() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    override_skill "$r" people/alice ghost global always   # no 'ghost' declaration anywhere
    local o; o="$(cd "$r" && bash scripts/skills-validate.sh 2>&1)" && { echo "expected non-zero exit"; return 1; }
    assert_contains "$o" "DANGLING OVERRIDE" "dangling override flagged"
}

# ---------------------------------------------------------------------------
# Tests — external fetcher (arg plumbing + plan resolution; no network)
# ---------------------------------------------------------------------------

test_fetcher_accepts_leaves_no_external() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    local o; o="$(cd "$r" && bash scripts/fetch-external-skills.sh "$TEST_DIR/sk" --agent claude --leaves people/alice/hosts/h1 2>&1)"
    assert_eq "0" "$?" "fetcher exits 0 with --leaves and no external skills" || return 1
    assert_contains "$o" "no external skills" "fetcher reports empty plan"
}

test_external_resolve_plan() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    # external declaration at global (forced) + a person override turning it off
    jq '.skills += [{name:"ext",owner:"acme",tier:"optional","force":true,source:{repo:"https://example.com/r",path:"p",ref:"main"}}]' \
        "$r/skills.json" > "$r/skills.json.t" && mv "$r/skills.json.t" "$r/skills.json"
    local plan; plan="$(skills_resolve_external_json "$r" "" people/alice/hosts/h1)"
    assert_eq "optional" "$(jq -r '.[0].tier' <<< "$plan")" "forced external declaration resolves on" || return 1
    override_skill "$r" people/alice ext external off
    # external overrides carry owner; patch it in (override_skill omits owner)
    jq '(.skills[] | select(.name=="ext" and .from=="external")) |= (. + {owner:"acme"})' \
        "$r/people/alice/skills.json" > "$r/people/alice/skills.json.t" && mv "$r/people/alice/skills.json.t" "$r/people/alice/skills.json"
    plan="$(skills_resolve_external_json "$r" "" people/alice/hosts/h1)"
    assert_eq "off" "$(jq -r '.[0].tier' <<< "$plan")" "external override off wins"
}

# ---------------------------------------------------------------------------
# Tests — flag-driven (non-interactive) identity resolution
# ---------------------------------------------------------------------------

test_flags_connect_existing_host() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    wire_sandbox_flags "$r" claude --handle alice --host h1 >/dev/null 2>&1 || return 1
    assert_eq "alice" "$(jq -r '.person' "$r/.exobrain.json")" "person stored from --handle" || return 1
    assert_eq "true" "$(jq '(.connected_scopes // []) | index("people/alice/hosts/h1") != null' "$r/.exobrain.json")" "existing host leaf connected"
}

test_flags_person_only_when_host_missing() {
    local r; r="$(setup_fake_exobrain)"
    mkdir -p "$r/people/carol"; printf '# person scope\n' > "$r/people/carol/AGENTS.md"
    wire_sandbox_flags "$r" claude --handle carol --host h9 >/dev/null 2>&1 || return 1
    assert_eq "true" "$(jq '(.connected_scopes // []) | index("people/carol") != null' "$r/.exobrain.json")" "falls back to the person scope" || return 1
    assert_no_file "$r/people/carol/hosts/h9/AGENTS.md" "missing host dir not scaffolded"
}

test_flags_no_scaffold_unknown_handle() {
    local r; r="$(setup_fake_exobrain)"
    wire_sandbox_flags "$r" claude --handle bob --host h9 >/dev/null 2>&1 || return 1
    assert_eq "[]" "$(jq -c '.connected_scopes' "$r/.exobrain.json")" "unknown handle connects nothing" || return 1
    assert_eq "null" "$(jq -r '.person // "null"' "$r/.exobrain.json")" "no person stored without a scope" || return 1
    assert_no_file "$r/people/bob/AGENTS.md" "flags never scaffold"
}

test_flags_guest() {
    local r; r="$(setup_fake_exobrain)"
    wire_sandbox_flags "$r" claude --guest >/dev/null 2>&1 || return 1
    assert_eq "[]" "$(jq -c '.connected_scopes' "$r/.exobrain.json")" "guest connects nothing" || return 1
    assert_eq "null" "$(jq -r '.person // "null"' "$r/.exobrain.json")" "guest stores no person"
}

test_flags_extra_scope() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    mkdir -p "$r/lab"; printf '# lab scope\n' > "$r/lab/AGENTS.md"
    wire_sandbox_flags "$r" claude --handle alice --host h1 --scope lab >/dev/null 2>&1 || return 1
    assert_eq "true" "$(jq '(.connected_scopes // []) | index("lab") != null' "$r/.exobrain.json")" "standalone --scope connected"
}

test_flags_name_match_nested() {
    local r; r="$(setup_fake_exobrain)"; add_group "$r" acme; add_person "$r" groups/acme/people/alice
    wire_sandbox_flags "$r" claude --handle alice --host h1 >/dev/null 2>&1 || return 1
    assert_eq "true" "$(jq '(.connected_scopes // []) | index("groups/acme/people/alice/hosts/h1") != null' "$r/.exobrain.json")" "name-match found the nested person/host" || return 1
    assert_no_file "$r/people/alice/AGENTS.md" "did not scaffold a duplicate top-level person"
}

# ---------------------------------------------------------------------------
# Tests — the canonical seed's own seed/ scope auto-joins the chain
# ---------------------------------------------------------------------------

test_seed_scope_auto_joins_chain() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    mkdir -p "$r/seed"; printf '# seed scope\n' > "$r/seed/AGENTS.md"
    local chain; chain="$(build_scope_chain "$r" people/alice/hosts/h1 | tr '\n' ' ')"
    assert_eq "global seed people/alice people/alice/hosts/h1 " "$chain" "seed/ auto-joins the chain at depth 1"
}

test_no_seed_scope_without_seed_dir() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice   # no seed/
    local chain; chain="$(build_scope_chain "$r" people/alice/hosts/h1 | tr '\n' ' ')"
    assert_not_contains "$chain" "seed" "no seed scope when seed/AGENTS.md is absent (wired instance)"
}

test_seed_scope_in_manifest() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    mkdir -p "$r/seed"; printf '# seed scope\n' > "$r/seed/AGENTS.md"
    write_config "$r" people/alice/hosts/h1
    wire_sandbox "$r" claude >/dev/null 2>&1 || return 1
    assert_contains "$(claude_manifest "$r")" "@../seed/AGENTS.md" "seed scope wired into the Claude manifest"
}


# ---------------------------------------------------------------------------
# Tests — OpenClaw runtime config
# ---------------------------------------------------------------------------

# A real openclaw connect reconciles openclaw.json: every linked skill's real
# parent dir joins the trusted symlink roots, skill_workshop joins tools.deny,
# Workshop autonomy is off — and what the human already had there stays.
test_openclaw_runtime_config_reconciled() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    declare_skill "$r" global g-skill always force
    declare_skill "$r" people/alice a-skill always force
    write_config "$r" people/alice/hosts/h1 openclaw
    fake_openclaw
    echo '{"skills":{"load":{"allowSymlinkTargets":["/kept/root"]}},"tools":{"deny":["browser"]},"agents":{"defaults":{"bootstrapTotalMaxChars":150000}}}' > "$TEST_DIR/oc-config.json"
    connect_flags "$r" openclaw >/dev/null 2>&1 || return 1
    local real; real="$(cd "$r" && pwd -P)"
    assert_eq "$(jq -nc --arg a "$real/skills" --arg b "$real/people/alice/skills" '[$a, $b, "/kept/root"] | sort')" \
              "$(oc_config '.skills.load.allowSymlinkTargets | sort')" "linked roots unioned with the kept one" || return 1
    assert_eq '["browser","skill_workshop"]' "$(oc_config '.tools.deny | sort')" "skill_workshop denied beside the kept entry" || return 1
    assert_eq '"off"' "$(oc_config '.skills.workshop.autonomous.mode')" "Workshop autonomy off" || return 1
    assert_eq '60000' "$(oc_config '.agents.defaults.bootstrapMaxChars')" "per-file bootstrap budget raised to its floor" || return 1
    assert_eq '150000' "$(oc_config '.agents.defaults.bootstrapTotalMaxChars')" "a larger human-set total budget stays"
}

test_openclaw_indexes_knowledge_domains() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    write_config "$r" people/alice/hosts/h1 openclaw
    mkdir -p "$r/knowledge/health/_raw"
    fake_openclaw
    echo '{"memory":{"search":{"extraPaths":[{"path":"runbooks","pattern":"**/*.md"}]}}}' > "$TEST_DIR/oc-config.json"
    connect_flags "$r" openclaw >/dev/null 2>&1 || return 1
    assert_eq "4" "$(oc_config '[.memory.search.extraPaths[] | select(.path | endswith("/knowledge"))] | length')" \
              "one entry per directory depth" || return 1
    assert_eq "1" "$(oc_config '[.memory.search.extraPaths[] | select(.path == "runbooks")] | length')" \
              "a human-added extra path survives the union" || return 1
    # Every pattern must reject a path segment starting with "_": _raw holds source
    # captures and _meta open questions, neither of which is current truth.
    assert_eq "0" "$(oc_config '[.memory.search.extraPaths[] | select(.pattern | test("(^|/)\\[!_\\]\\*/") | not) | select(.path | endswith("knowledge"))] | length')" \
              "every knowledge pattern guards its first segment against _"
}

# A repo with no knowledge/ contributes no extra paths at all.
test_openclaw_no_knowledge_no_extra_paths() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    write_config "$r" people/alice/hosts/h1 openclaw
    connect_flags "$r" openclaw >/dev/null 2>&1 || return 1
    assert_eq "null" "$(oc_config '.memory.search.extraPaths // "null"' | tr -d '"')" \
              "no extraPaths key written without a knowledge dir"
}

# The union must compare equal on a second run, or every relink rewrites the config.
test_openclaw_knowledge_paths_idempotent() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    write_config "$r" people/alice/hosts/h1 openclaw
    mkdir -p "$r/knowledge/home"
    connect_flags "$r" openclaw >/dev/null 2>&1 || return 1
    assert_eq "1" "$(oc_set_calls)" "first connect wrote once" || return 1
    local out; out="$(relink "$r" openclaw 2>&1)" || return 1
    assert_eq "1" "$(oc_set_calls)" "relink wrote nothing" || return 1
    assert_contains "$out" "already reconciled"
}

# A second run with nothing to change writes nothing.
test_openclaw_runtime_config_idempotent() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    declare_skill "$r" people/alice a-skill always force
    write_config "$r" people/alice/hosts/h1 openclaw
    connect_flags "$r" openclaw >/dev/null 2>&1 || return 1
    assert_eq "1" "$(oc_set_calls)" "first connect wrote once" || return 1
    local out; out="$(relink "$r" openclaw 2>&1)" || return 1
    assert_eq "1" "$(oc_set_calls)" "relink wrote nothing" || return 1
    assert_contains "$out" "already reconciled"
}

# Without the CLI the connect still completes — reported, not fatal.
test_openclaw_runtime_config_degrades_without_cli() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    write_config "$r" people/alice/hosts/h1 openclaw
    mkdir -p "$TEST_DIR/home" "$TEST_DIR/ocw"
    local out
    out="$(cd "$r" && env "HOME=$TEST_DIR/home" "OPENCLAW_WORKSPACE=$TEST_DIR/ocw" \
        "OPENCLAW_BIN=$TEST_DIR/none/openclaw" bash scripts/connect-agent.sh openclaw 2>&1)" || { echo "$out"; return 1; }
    assert_contains "$out" "openclaw CLI not found" || return 1
    assert_file "$r/.openclaw" "connect completed"
}

# A sandbox wiring promises no out-of-dir writes: the runtime config is untouched.
test_openclaw_runtime_config_skipped_on_wire_sandbox() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    declare_skill "$r" people/alice a-skill always force
    write_config "$r" people/alice/hosts/h1 openclaw
    wire_sandbox "$r" openclaw >/dev/null 2>&1 || return 1
    assert_no_file "$TEST_DIR/oc-calls.txt" "no openclaw call from a sandbox wiring"
}

test_openclaw_gitignore_block_written() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    write_config "$r" people/alice/hosts/h1 openclaw
    mkdir -p "$TEST_DIR/ocw"; git -C "$TEST_DIR/ocw" init -q
    wire_sandbox "$r" openclaw >/dev/null 2>&1 || return 1
    assert_file "$TEST_DIR/ocw/.gitignore" "workspace .gitignore written" || return 1
    local body; body="$(cat "$TEST_DIR/ocw/.gitignore")"
    assert_contains "$body" 'memory/????-??-??-*.md' "session-summary pattern ignored" || return 1
    assert_contains "$body" 'memory/.dreams/' "dreaming corpus ignored" || return 1
    assert_contains "$body" 'memory/dreaming/' "dreaming phase logs ignored" || return 1
    assert_contains "$body" "# BEGIN exobrain" "block fenced with a gitignore comment"
}

test_openclaw_gitignore_idempotent() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    write_config "$r" people/alice/hosts/h1 openclaw
    mkdir -p "$TEST_DIR/ocw"; git -C "$TEST_DIR/ocw" init -q
    wire_sandbox "$r" openclaw >/dev/null 2>&1 || return 1
    wire_sandbox "$r" openclaw >/dev/null 2>&1 || return 1
    local n; n="$(grep -c '^# BEGIN exobrain$' "$TEST_DIR/ocw/.gitignore")"
    assert_eq "1" "$(printf '%s' "$n" | tr -d ' ')" "one block after a second run"
}

test_openclaw_gitignore_preserves_human_rules() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    write_config "$r" people/alice/hosts/h1 openclaw
    mkdir -p "$TEST_DIR/ocw"; git -C "$TEST_DIR/ocw" init -q
    printf 'secrets.env\n' > "$TEST_DIR/ocw/.gitignore"
    wire_sandbox "$r" openclaw >/dev/null 2>&1 || return 1
    assert_contains "$(cat "$TEST_DIR/ocw/.gitignore")" "secrets.env" "human rule survives the append"
}

test_openclaw_gitignore_skipped_without_git() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    write_config "$r" people/alice/hosts/h1 openclaw
    wire_sandbox "$r" openclaw >/dev/null 2>&1 || return 1
    assert_no_file "$TEST_DIR/ocw/.gitignore" "no ignore file for a workspace that is not a repo"
}

test_openclaw_gitignore_reports_tracked_summaries() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    write_config "$r" people/alice/hosts/h1 openclaw
    mkdir -p "$TEST_DIR/ocw/memory/.dreams"; git -C "$TEST_DIR/ocw" init -q
    : > "$TEST_DIR/ocw/memory/2026-01-01-1200.md"
    : > "$TEST_DIR/ocw/memory/.dreams/corpus.txt"
    git -C "$TEST_DIR/ocw" add -A >/dev/null 2>&1
    git -C "$TEST_DIR/ocw" -c user.email=t@t -c user.name=t commit -qm seed >/dev/null 2>&1
    local out; out="$(wire_sandbox "$r" openclaw 2>&1)" || return 1
    assert_contains "$out" "still tracked" "an already-committed summary is reported"
}

# ---------------------------------------------------------------------------


# Codex wiring must leave both existing and absent personal configuration alone.
test_codex_preserves_home_links() {
    local r mode; r="$(setup_fake_exobrain)"
    mkdir -p "$TEST_DIR/codex"
    printf 'personal rules\n' > "$TEST_DIR/personal.md"
    ln -s "$TEST_DIR/personal.md" "$TEST_DIR/codex/AGENTS.override.md"
    ln -s "$TEST_DIR/personal.md" "$TEST_DIR/codex/CODEX.personal.md"
    for mode in sandbox connect; do
        if [[ "$mode" == sandbox ]]; then
            wire_sandbox "$r" codex >/dev/null 2>&1 || return 1
        else
            connect_flags "$r" codex --guest >/dev/null 2>&1 || return 1
        fi
        assert_symlink "$TEST_DIR/codex/AGENTS.override.md" "$mode preserves personal override" || return 1
        assert_symlink "$TEST_DIR/codex/CODEX.personal.md" "$mode preserves personal sidecar" || return 1
    done
}

test_codex_does_not_create_home() {
    local r; r="$(setup_fake_exobrain)"
    (cd "$r" && env "HOME=$TEST_DIR/home" CODEX_HOME= \
        bash scripts/connect-agent.sh codex --wire-sandbox --guest) >/dev/null 2>&1 || return 1
    assert_no_file "$TEST_DIR/home/.codex" "default home untouched without an override" || return 1
    (cd "$r" && env "CODEX_HOME=$TEST_DIR/absent-codex-home" \
        bash scripts/connect-agent.sh codex --guest) >/dev/null 2>&1 || return 1
    assert_no_file "$TEST_DIR/absent-codex-home" "normal connect leaves absent home alone"
}

# A connected fake main checkout plus a real sibling worktree.
make_codex_worktree() {
    local r; r="$(setup_fake_exobrain)"
    declare_skill "$r" global core always force
    write_config "$r" "" codex
    wire_sandbox "$r" codex >/dev/null 2>&1 || return 1
    touch "$r/.codex"
    git -C "$r" config core.hooksPath /dev/null
    git -C "$r" add -A
    git -C "$r" -c user.email=t@t -c user.name=t commit -qm fixture || return 1
    (cd "$r" && bash scripts/create-worktree.sh feature 2>/dev/null)
}

test_codex_worktree_skills() {
    local wt; wt="$(make_codex_worktree)" || return 1
    assert_file "$wt/.agents/skills/core/SKILL.md" "skill discoverable in worktree" || return 1
    [[ ! -L "$wt/.agents/skills" ]] || { echo 'skills parent must be a real directory'; return 1; }
    printf '\nWorktree-only instructions\n' >> "$wt/skills/core/SKILL.md"
    assert_contains "$(cat "$wt/.agents/skills/core/SKILL.md")" 'Worktree-only instructions' "link uses branch-local source" || return 1
    assert_not_contains "$(cat "$TEST_DIR/exobrain/skills/core/SKILL.md")" 'Worktree-only instructions' "main source unchanged"
}

test_codex_worktree_rewire_preserves_main() {
    local wt before; wt="$(make_codex_worktree)" || return 1
    before="$(cat "$TEST_DIR/exobrain/AGENTS.override.md")"
    printf '\nWorktree-only context\n' >> "$wt/AGENTS.md"
    wire_sandbox "$wt" codex >/dev/null 2>&1 || return 1
    assert_eq "$before" "$(cat "$TEST_DIR/exobrain/AGENTS.override.md")" "rewire must not follow the inherited link" || return 1
    assert_contains "$(cat "$wt/AGENTS.override.md")" 'Worktree-only context' "worktree gets its own composition"
}

test_codex_worktree_linker_preserves_owned_files() {
    local wt; wt="$(make_codex_worktree)" || return 1
    rm "$wt/AGENTS.override.md" "$wt/.agents/skills/core"
    printf 'owned context\n' > "$wt/AGENTS.override.md"
    mkdir "$wt/.agents/skills/core"
    printf 'owned skill\n' > "$wt/.agents/skills/core/SKILL.md"
    bash "$wt/scripts/link-worktree-context.sh" "$TEST_DIR/exobrain" "$wt" >/dev/null 2>&1 || return 1
    assert_eq 'owned context' "$(cat "$wt/AGENTS.override.md")" || return 1
    assert_eq 'owned skill' "$(cat "$wt/.agents/skills/core/SKILL.md")"
}

# Claude's per-machine settings (permission allowlists, gitignored) follow the
# worktree, or every session there starts with a bare permission set.
test_worktree_links_claude_local_settings() {
    local r; r="$(setup_fake_exobrain)"
    mkdir -p "$r/.claude"; printf '{"permissions":{}}\n' > "$r/.claude/settings.local.json"
    git -C "$r" config core.hooksPath /dev/null
    git -C "$r" add -A
    git -C "$r" -c user.email=t@t -c user.name=t commit -qm fixture || return 1
    local wt; wt="$(cd "$r" && bash scripts/create-worktree.sh feature 2>/dev/null)" || return 1
    [[ -L "$wt/.claude/settings.local.json" ]] || { echo "settings.local.json not linked"; return 1; }
    assert_eq '{"permissions":{}}' "$(cat "$wt/.claude/settings.local.json")"
}

test_codex_health_missing_surfaces() {
    local r out; r="$(setup_fake_exobrain)"
    write_config "$r" "" codex; touch "$r/.codex"
    out="$(bash "$r/scripts/exobrain-healthcheck.sh" codex -v)" || return 1
    assert_contains "$out" 'missing or empty AGENTS.override.md' || return 1
    assert_contains "$out" 'missing skills directory' || return 1
    assert_not_contains "$out" 'connected and linked' "missing surfaces cannot report healthy"
}

test_codex_health_checks_worktree() {
    local wt out; wt="$(make_codex_worktree)" || return 1
    out="$(bash "$wt/scripts/exobrain-healthcheck.sh" codex -v)" || return 1
    assert_contains "$out" 'connected and linked' "valid worktree passes" || return 1
    rm -f "$wt/.agents/skills/core"
    out="$(bash "$wt/scripts/exobrain-healthcheck.sh" codex -v)" || return 1
    assert_contains "$out" 'missing skill core' || return 1
    assert_contains "$out" "$wt" "warning identifies active checkout" || return 1
    assert_not_contains "$out" 'connected and linked' || return 1
    out="$(bash "$TEST_DIR/exobrain/scripts/exobrain-healthcheck.sh" codex -v)" || return 1
    assert_contains "$out" 'connected and linked' "main remains healthy"
}

test_codex_health_ignores_personal_home() {
    local wt out; wt="$(make_codex_worktree)" || return 1
    ln -s "$TEST_DIR/nonexistent-personal-rules" "$TEST_DIR/codex/AGENTS.personal.md"
    out="$(CODEX_HOME="$TEST_DIR/codex" bash "$wt/scripts/exobrain-healthcheck.sh" codex -v)" || return 1
    assert_contains "$out" 'connected and linked' "unrelated personal links do not affect repo wiring"
}

test_description_block_scalars() {
    local r marker desc; r="$(setup_fake_exobrain)"
    for marker in '>' '>-' '>+' '|' '|-' '|+'; do
        printf -- '---\nname: example\ndescription: %s\n  First line\n  second line.\n\n  Next paragraph.\nmetadata:\n  ignored: value\n---\nBody ignored.\n' "$marker" > "$r/description.md"
        desc="$(skills_extract_description "$r/description.md")"
        assert_eq 'First line second line. Next paragraph.' "$desc" "$marker flattened for table" || return 1
    done
    printf -- '---\ndescription: "Single line."\n---\n' > "$r/description.md"
    assert_eq 'Single line.' "$(skills_extract_description "$r/description.md")" "quoted inline description stays intact"
}

test_description_block_in_index() {
    local r; r="$(setup_fake_exobrain)"
    declare_skill "$r" global optional-skill optional force
    printf -- '---\nname: optional-skill\ndescription: >\n  Discover this skill\n  from both lines.\n---\n' > "$r/skills/optional-skill/SKILL.md"
    wire_sandbox "$r" codex >/dev/null 2>&1 || return 1
    assert_contains "$(cat "$r/AGENTS.override.md")" '| Discover this skill from both lines. |' "complete summary in generated index"
}

run_test "scope chain shallow->deep"          test_scope_chain_shallow_to_deep
run_test "person scope ids list people only"   test_person_scope_ids_lists_people_only
run_test "unused handle is free"               test_handle_free_when_unused
run_test "handle taken by a person"            test_handle_taken_by_person
run_test "handle taken by a non-person scope"  test_handle_taken_by_non_person_scope
run_test "generic handles flagged"             test_generic_handles_flagged
run_test "scope hook runs with scope args"     test_scope_hook_runs_with_scope_args
run_test "scope hooks run shallow->deep"       test_scope_hooks_run_shallow_to_deep
run_test "scope hook agent-specific filtered"  test_scope_hook_agent_specific_is_filtered
run_test "scope hook both variants run"        test_scope_hook_both_variants_run
run_test "scope hook failure not fatal"        test_scope_hook_failure_is_reported_not_fatal
run_test "silent hook failure not fatal"       test_scope_hook_silent_failure_is_not_fatal
run_test "scope hooks skipped on sandbox"     test_scope_hooks_skipped_on_wire_sandbox
run_test "global connector is not a hook"      test_global_connector_is_not_a_scope_hook
run_test "wizard gates generic + taken ids"    test_wizard_gates_generic_and_taken_handles
run_test "wizard withholds generic default"    test_wizard_withholds_generic_default
run_test "wizard completes, last row unchecked" test_wizard_completes_with_unchecked_last_row
run_test "force reaches non-owner"             test_force_reaches_nonowner
run_test "owner-gated off for others"          test_owner_gated_off_for_others
run_test "owner-match enables for owner"       test_owner_match_enables_for_owner
run_test "stored person wins over type"        test_stored_person_overrides_type
run_test "override opts in"                    test_override_opts_in
run_test "override off shadows force"          test_override_off_shadows_force
run_test "deepest override wins"               test_deepest_override_wins
run_test "unlisted resolves"                   test_unlisted_resolves
run_test "tools resolve deepest wins"          test_tools_resolve_deepest_wins
run_test "tools resolve excludes template"     test_tools_resolve_excludes_template
run_test "claude manifest relative + resolves" test_claude_manifest_relative_and_resolves
run_test "wiring no-sidecar exits 0"          test_wire_no_sidecar_exit0
run_test "always linked, unlisted not"         test_always_skill_linked_unlisted_not
run_test "claude index imports resolve"        test_claude_index_imports_resolve
run_test "codex preserves personal home links" test_codex_preserves_home_links
run_test "codex does not create home"          test_codex_does_not_create_home
run_test "codex worktree discovers local skills" test_codex_worktree_skills
run_test "codex worktree rewire preserves main" test_codex_worktree_rewire_preserves_main
run_test "codex worktree keeps owned files"     test_codex_worktree_linker_preserves_owned_files
run_test "worktree links claude local settings" test_worktree_links_claude_local_settings
run_test "codex health catches missing surfaces" test_codex_health_missing_surfaces
run_test "codex health checks active worktree"  test_codex_health_checks_worktree
run_test "codex health ignores personal home"  test_codex_health_ignores_personal_home
run_test "description block scalars"           test_description_block_scalars
run_test "description block reaches index"     test_description_block_in_index
run_test "codex inlines specs"                 test_codex_inlines_specs
run_test "codex indexes inlined, not in home"  test_codex_indexes_inlined_not_in_home
run_test "openclaw indexes inlined, not home"  test_openclaw_indexes_inlined_not_in_home
run_test "tools index (claude)"                test_tools_index_claude
run_test "tools index empty -> skip"           test_tools_index_empty_skip
run_test "knowledge index (claude)"              test_knowledge_index_claude
run_test "knowledge index empty -> skip"         test_knowledge_index_empty_skip
run_test "stale claude index cleared"          test_claude_index_removed_when_source_goes
run_test "relink skips unconnected claude"     test_relink_skips_unconnected_claude
run_test "relink skips unconnected codex/oc"   test_relink_skips_unconnected_file_marker_agents
run_test "relink refreshes connected claude"   test_relink_refreshes_connected_claude
run_test "relink, no agent: every connected"    test_relink_all_connected_agents
run_test "relink, no agent: none connected"     test_relink_all_nothing_connected
run_test "relink, no agent: refuses flags"      test_relink_all_refuses_other_flags
run_test "hooks install into repo, other cwd"  test_hooks_install_into_repo_from_other_cwd
run_test "commit-msg hook strips attribution"  test_commit_msg_hook_strips_agent_attribution
run_test "validate flags bash 4 constructs"    test_validate_flags_bash4_constructs
run_test "validate honors bash 4 opt-out"      test_validate_bash4_optout_honored
run_test "validate flags unguarded arrays"     test_validate_flags_unguarded_array_expansion
run_test "validate passes guarded arrays"      test_validate_guarded_array_expansion_passes
run_test "validate spares never-empty arrays"  test_validate_ignores_never_empty_array
run_test "validate clean"                      test_validate_clean
run_test "validate dangling override"          test_validate_dangling_override
run_test "fetcher accepts --leaves"            test_fetcher_accepts_leaves_no_external
run_test "description single-line forms"      test_description_single_line_forms
run_test "description folded block"           test_description_folded_block
run_test "description block boundaries"       test_description_block_stops_at_boundaries
run_test "description absent"                 test_description_absent_or_body_only
run_test "index carries folded description"   test_optional_index_carries_folded_description
run_test "external resolve plan"               test_external_resolve_plan
run_test "flags connect existing host"         test_flags_connect_existing_host
run_test "flags person-only when host missing" test_flags_person_only_when_host_missing
run_test "flags never scaffold"                test_flags_no_scaffold_unknown_handle
run_test "flags guest connects nothing"        test_flags_guest
run_test "flags extra --scope"                 test_flags_extra_scope
run_test "flags name-match nested"             test_flags_name_match_nested
run_test "wire openclaw refuses without workspace" test_wire_openclaw_refuses_without_workspace
run_test "openclaw runtime config reconciled"   test_openclaw_runtime_config_reconciled
run_test "openclaw indexes knowledge domains" test_openclaw_indexes_knowledge_domains
run_test "openclaw no knowledge no extrapaths" test_openclaw_no_knowledge_no_extra_paths
run_test "openclaw knowledge paths idempotent" test_openclaw_knowledge_paths_idempotent
run_test "openclaw runtime config idempotent"   test_openclaw_runtime_config_idempotent
run_test "openclaw runtime config without cli"  test_openclaw_runtime_config_degrades_without_cli
run_test "openclaw runtime config skipped in sandbox" test_openclaw_runtime_config_skipped_on_wire_sandbox
run_test "openclaw gitignore block written"   test_openclaw_gitignore_block_written
run_test "openclaw gitignore idempotent"      test_openclaw_gitignore_idempotent
run_test "openclaw gitignore keeps human rules" test_openclaw_gitignore_preserves_human_rules
run_test "openclaw gitignore skipped without git" test_openclaw_gitignore_skipped_without_git
run_test "openclaw gitignore reports tracked"  test_openclaw_gitignore_reports_tracked_summaries
run_test "seed scope auto-joins chain"         test_seed_scope_auto_joins_chain
run_test "no seed scope without seed/"         test_no_seed_scope_without_seed_dir
run_test "seed scope in manifest"              test_seed_scope_in_manifest

echo ""
printf "Ran %d  ${GREEN}passed %d${RESET}  ${RED}failed %d${RESET}\n" "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
if [[ $TESTS_FAILED -gt 0 ]]; then printf 'Failures: %s\n' ${FAILURES[*]+"${FAILURES[*]}"}; exit 1; fi
exit 0
