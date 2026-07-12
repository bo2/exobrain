#!/usr/bin/env bash
# test-connect-agent.sh — tests for the connector + skills registry under the
# scope-tree / opt-in model. Seed-local (lives under seed-tests); it exercises the
# framework scripts in <repo>/scripts/.
#
#   seed/skills/seed-tests/scripts/test-connect-agent.sh            # run all
#   seed/skills/seed-tests/scripts/test-connect-agent.sh <pattern>  # filter by name
#
# Each test builds an isolated fake exobrain in a temp dir and renders the agent
# surface side-effect-free (connect-agent.sh --render-specs-only with HOME /
# CODEX_HOME / OPENCLAW_WORKSPACE pointed at temp dirs), so nothing touches the
# real repo or ~/. Function-level checks source skills-registry.sh directly.

set -uo pipefail

TESTS_RUN=0; TESTS_PASSED=0; TESTS_FAILED=0; FAILURES=()
FILTER="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"          # .../seed-tests/scripts
REPO_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"     # <repo> — the seed
SCRIPTS_DIR="$REPO_DIR/scripts"                       # framework scripts under test
# shellcheck source=../../../../scripts/skills-registry.sh
source "$SCRIPTS_DIR/skills-registry.sh"

RED='\033[0;31m'; GREEN='\033[0;32m'; DIM='\033[0;90m'; RESET='\033[0m'

run_test() {
    local name="$1"; shift
    [[ -n "$FILTER" && "$name" != *"$FILTER"* ]] && return 0
    TESTS_RUN=$((TESTS_RUN + 1))
    printf "${DIM}%-56s${RESET} " "$name"
    TEST_DIR="$(mktemp -d)"
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

claude_manifest() { cat "$1/.claude/connected-scopes.md"; }
claude_index()    { cat "$1/.claude/optional-skills.md"; }
claude_tools()    { cat "$1/.claude/tools-index.md"; }
claude_domains()  { cat "$1/.claude/domains-index.md"; }

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
    cp "$REPO_DIR/skills.schema.json"          "$repo/"
    chmod +x "$repo/scripts/"*.sh
    printf '# Exobrain\n' > "$repo/AGENTS.md"
    printf '{"scopes":[{"type":"group","collection":"groups"},{"type":"person","collection":"people"},{"type":"host","collection":"hosts"}]}\n' > "$repo/scopes.json"
    printf '{"$schema":"./skills.schema.json","skills":[]}\n' > "$repo/skills.json"
    printf '.claude/\n.codex\n.openclaw\nAGENTS.override.md\n.exobrain.json\nsrc/\n' > "$repo/.gitignore"
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
    mkdir -p "$repo/domains/$name"
    printf -- '---\nname: %s\ntype: reference\ncurator: alice\nsummary: %s\n---\n\n# %s\n' \
        "$name" "$summary" "$name" > "$repo/domains/$name/README.md"
}

write_config() { printf '{"connected_scopes":["%s"],"agents":["%s"]}\n' "$2" "${3:-claude}" > "$1/.exobrain.json"; }

# render <repo> <agent> — render the agent surface side-effect-free, HOME-isolated.
render() {
    local repo="$1" agent="$2"
    mkdir -p "$TEST_DIR/home" "$TEST_DIR/codex" "$TEST_DIR/ocw"
    (cd "$repo" && env "HOME=$TEST_DIR/home" "CODEX_HOME=$TEST_DIR/codex" \
        "OPENCLAW_WORKSPACE=$TEST_DIR/ocw" bash scripts/connect-agent.sh "$agent" --render-specs-only)
}

# render_flags <repo> <agent> <flag...> — render with explicit identity flags, so
# resolve_from_flags runs and writes .exobrain.json into the sandbox.
render_flags() {
    local repo="$1" agent="$2"; shift 2
    mkdir -p "$TEST_DIR/home" "$TEST_DIR/codex" "$TEST_DIR/ocw"
    (cd "$repo" && env "HOME=$TEST_DIR/home" "CODEX_HOME=$TEST_DIR/codex" \
        "OPENCLAW_WORKSPACE=$TEST_DIR/ocw" bash scripts/connect-agent.sh "$agent" --render-specs-only "$@")
}

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
    render "$r" claude >/dev/null 2>&1 || return 1
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

# Regression for the set -e abort: a connected scope with no per-agent sidecar must
# still render cleanly (the manifest emitter's last branch returns 0).
test_render_no_sidecar_exit0() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice  # no CLAUDE.md sidecars
    write_config "$r" people/alice/hosts/h1
    render "$r" claude >/dev/null 2>&1
    assert_eq "0" "$?" "render exits 0 when scopes lack sidecars"
}

test_always_skill_linked_unlisted_not() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    declare_skill "$r" global linkme always force
    declare_skill "$r" global hideme unlisted force
    declare_skill "$r" global optme optional force
    write_config "$r" people/alice/hosts/h1
    render "$r" claude >/dev/null 2>&1 || return 1
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
    render "$r" codex >/dev/null 2>&1 || return 1
    assert_file "$r/AGENTS.override.md" "codex override generated in-repo" || return 1
    local a; a="$(cat "$r/AGENTS.override.md")"
    # The override supersedes the bare AGENTS.md, so it must carry the root spec…
    assert_contains "$a" "<!-- scope: global -->" "root spec inlined into override" || return 1
    # …plus each deeper scope's spec.
    assert_contains "$a" "person scope" "person spec inlined into override" || return 1
    # Codex's surface is in-repo, not in CODEX_HOME.
    assert_no_file "$TEST_DIR/codex/AGENTS.md" "no marker block left in ~/.codex/AGENTS.md"
}

# ---------------------------------------------------------------------------
# Tests — tools index injection
# ---------------------------------------------------------------------------

test_tools_index_claude() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    add_tool "$r" global github "Read and act on GitHub via the gh CLI."
    write_config "$r" people/alice/hosts/h1
    render "$r" claude >/dev/null 2>&1 || return 1
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
    render "$r" claude >/dev/null 2>&1 || return 1
    assert_no_file "$r/.claude/tools-index.md" "no tools-index.md when no tool docs" || return 1
    local c; c="$(cat "$r/.claude/CLAUDE.md")"
    assert_not_contains "$c" "@tools-index.md" "CLAUDE.md does not import a missing tools index"
}

# ---------------------------------------------------------------------------
# Tests — domains index injection
# ---------------------------------------------------------------------------

test_domains_index_claude() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    add_domain "$r" health "Conditions, meds, providers, and insurance."
    write_config "$r" people/alice/hosts/h1
    render "$r" claude >/dev/null 2>&1 || return 1
    assert_file "$r/.claude/domains-index.md" "domains-index.md generated" || return 1
    local d; d="$(claude_domains "$r")"
    assert_contains "$d" "health" "domain row present" || return 1
    assert_contains "$d" "domains/health/README.md" "README path present" || return 1
    assert_contains "$d" "Conditions, meds, providers, and insurance." "summary extracted from frontmatter" || return 1
    local c; c="$(cat "$r/.claude/CLAUDE.md")"
    assert_contains "$c" "@domains-index.md" "CLAUDE.md imports the domains index"
}

test_domains_index_empty_skip() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice  # no domains/
    write_config "$r" people/alice/hosts/h1
    render "$r" claude >/dev/null 2>&1 || return 1
    assert_no_file "$r/.claude/domains-index.md" "no domains-index.md when no domains/" || return 1
    local c; c="$(cat "$r/.claude/CLAUDE.md")"
    assert_not_contains "$c" "@domains-index.md" "CLAUDE.md does not import a missing domains index"
}

# ---------------------------------------------------------------------------
# Tests — validator
# ---------------------------------------------------------------------------

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
    render_flags "$r" claude --handle alice --host h1 >/dev/null 2>&1 || return 1
    assert_eq "alice" "$(jq -r '.person' "$r/.exobrain.json")" "person stored from --handle" || return 1
    assert_eq "true" "$(jq '(.connected_scopes // []) | index("people/alice/hosts/h1") != null' "$r/.exobrain.json")" "existing host leaf connected"
}

test_flags_person_only_when_host_missing() {
    local r; r="$(setup_fake_exobrain)"
    mkdir -p "$r/people/carol"; printf '# person scope\n' > "$r/people/carol/AGENTS.md"
    render_flags "$r" claude --handle carol --host h9 >/dev/null 2>&1 || return 1
    assert_eq "true" "$(jq '(.connected_scopes // []) | index("people/carol") != null' "$r/.exobrain.json")" "falls back to the person scope" || return 1
    assert_no_file "$r/people/carol/hosts/h9/AGENTS.md" "missing host dir not scaffolded"
}

test_flags_no_scaffold_unknown_handle() {
    local r; r="$(setup_fake_exobrain)"
    render_flags "$r" claude --handle bob --host h9 >/dev/null 2>&1 || return 1
    assert_eq "[]" "$(jq -c '.connected_scopes' "$r/.exobrain.json")" "unknown handle connects nothing" || return 1
    assert_eq "null" "$(jq -r '.person // "null"' "$r/.exobrain.json")" "no person stored without a scope" || return 1
    assert_no_file "$r/people/bob/AGENTS.md" "flags never scaffold"
}

test_flags_guest() {
    local r; r="$(setup_fake_exobrain)"
    render_flags "$r" claude --guest >/dev/null 2>&1 || return 1
    assert_eq "[]" "$(jq -c '.connected_scopes' "$r/.exobrain.json")" "guest connects nothing" || return 1
    assert_eq "null" "$(jq -r '.person // "null"' "$r/.exobrain.json")" "guest stores no person"
}

test_flags_extra_scope() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    mkdir -p "$r/lab"; printf '# lab scope\n' > "$r/lab/AGENTS.md"
    render_flags "$r" claude --handle alice --host h1 --scope lab >/dev/null 2>&1 || return 1
    assert_eq "true" "$(jq '(.connected_scopes // []) | index("lab") != null' "$r/.exobrain.json")" "standalone --scope connected"
}

test_flags_name_match_nested() {
    local r; r="$(setup_fake_exobrain)"; add_group "$r" acme; add_person "$r" groups/acme/people/alice
    render_flags "$r" claude --handle alice --host h1 >/dev/null 2>&1 || return 1
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
    assert_not_contains "$chain" "seed" "no seed scope when seed/AGENTS.md is absent (rendered instance)"
}

test_seed_scope_in_manifest() {
    local r; r="$(setup_fake_exobrain)"; add_person "$r" people/alice
    mkdir -p "$r/seed"; printf '# seed scope\n' > "$r/seed/AGENTS.md"
    write_config "$r" people/alice/hosts/h1
    render "$r" claude >/dev/null 2>&1 || return 1
    assert_contains "$(claude_manifest "$r")" "@../seed/AGENTS.md" "seed scope wired into the Claude manifest"
}

# ---------------------------------------------------------------------------

run_test "scope chain shallow->deep"          test_scope_chain_shallow_to_deep
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
run_test "render no-sidecar exits 0"           test_render_no_sidecar_exit0
run_test "always linked, unlisted not"         test_always_skill_linked_unlisted_not
run_test "codex inlines specs"                 test_codex_inlines_specs
run_test "tools index (claude)"                test_tools_index_claude
run_test "tools index empty -> skip"           test_tools_index_empty_skip
run_test "domains index (claude)"              test_domains_index_claude
run_test "domains index empty -> skip"         test_domains_index_empty_skip
run_test "validate clean"                      test_validate_clean
run_test "validate dangling override"          test_validate_dangling_override
run_test "fetcher accepts --leaves"            test_fetcher_accepts_leaves_no_external
run_test "external resolve plan"               test_external_resolve_plan
run_test "flags connect existing host"         test_flags_connect_existing_host
run_test "flags person-only when host missing" test_flags_person_only_when_host_missing
run_test "flags never scaffold"                test_flags_no_scaffold_unknown_handle
run_test "flags guest connects nothing"        test_flags_guest
run_test "flags extra --scope"                 test_flags_extra_scope
run_test "flags name-match nested"             test_flags_name_match_nested
run_test "seed scope auto-joins chain"         test_seed_scope_auto_joins_chain
run_test "no seed scope without seed/"         test_no_seed_scope_without_seed_dir
run_test "seed scope in manifest"              test_seed_scope_in_manifest

echo ""
printf "Ran %d  ${GREEN}passed %d${RESET}  ${RED}failed %d${RESET}\n" "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
if [[ $TESTS_FAILED -gt 0 ]]; then printf 'Failures: %s\n' "${FAILURES[*]}"; exit 1; fi
exit 0
