#!/usr/bin/env bash
# test-validator-checks.sh — the whole-tree checks in validate-exobrain.sh that
# scan every file of a kind: UPPERCASE .md names, bash-4 constructs, unguarded
# empty-array expansions, and the reverse scan for COMPAT markers. Each test
# asserts the exact set of violations its fixture raises, so a check that flags
# too much fails as surely as one that flags too little.
#
#   skills/exobrain-tests/unit/test-validator-checks.sh            # run all
#   skills/exobrain-tests/unit/test-validator-checks.sh <pattern>  # filter by name
#
# The fixtures hold the very constructs these checks flag, so they are written
# with placeholders filled in at render time; a harness spelling them out would be
# flagged by the gate it tests.

set -uo pipefail

TESTS_RUN=0; TESTS_PASSED=0; TESTS_FAILED=0; FAILURES=()
FILTER="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
SCRIPTS_DIR="$REPO_DIR/scripts"

RED='\033[0;31m'; GREEN='\033[0;32m'; DIM='\033[0;90m'; BOLD='\033[1m'; RESET='\033[0m'

run_test() {
    local name="$1"; shift
    [[ -n "$FILTER" && "$name" != *"$FILTER"* ]] && return 0
    TESTS_RUN=$((TESTS_RUN + 1))
    printf "${DIM}%-52s${RESET} " "$name"
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

# assert_violations <category-substring> <expected lines…> — the output's
# violations of that category are exactly these, in any order.
assert_violations() {
    local cat="$1"; shift
    local got want
    got="$(printf '%s\n' "$OUT" | sed -n 's/^  - //p' | grep -F -- "$cat" | sort)"
    want="$(printf '%s\n' "$@" | sort)"
    [[ "$got" == "$want" ]] && return 0
    echo "violations of '$cat' differ:"
    diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/  /'
    return 1
}

D=declare; M=mapfile; R=readarray; E='=()'; C=COMPAT
render() {   # render FILE — write stdin to FILE with the placeholders filled in
    local body; body="$(cat; printf x)"; body="${body%x}"
    body="${body//@DECL@/$D}"; body="${body//@MAPF@/$M}"; body="${body//@READ@/$R}"
    body="${body//@EMPTY@/$E}"; body="${body//@COMPAT@/$C}"
    mkdir -p "$(dirname "$1")"; printf '%s' "$body" > "$1"
}

make_repo() {
    cd "$TEST_DIR" || return 1
    git init -q -b main .
    git config user.email t@example.com
    git config user.name t
    mkdir -p scripts knowledge/exobrain knowledge/notes/_raw
    cp "$SCRIPTS_DIR/validate-exobrain.sh" scripts/
    printf '# Exobrain\n' > AGENTS.md
    printf '{"collections":{"hosts":{"kind":"host"}}}\n' > scopes.json
    printf '{"skills":[]}\n' > skills.json
}

validate() { git add -A && git commit -qm fixture && git update-ref refs/remotes/origin/main HEAD
             OUT="$(bash scripts/validate-exobrain.sh 2>&1)"; }

# ---------------------------------------------------------------------------

test_uppercase_names() {
    make_repo || return 1
    local n; for n in NOTES MY-PLAN UP_2 README My-Plan; do printf 'x\n' > "knowledge/notes/$n.md"; done
    printf 'x\n' > knowledge/notes/_raw/RAWDOC.md
    mkdir -p knowledge/notes/DIRNAME.md && printf 'x\n' > knowledge/notes/DIRNAME.md/inner.txt
    validate
    local tail=" (use lowercase kebab-case unless it's a standard convention)"
    assert_violations "Custom UPPERCASE filename" \
        "Custom UPPERCASE filename: knowledge/notes/NOTES.md$tail" \
        "Custom UPPERCASE filename: knowledge/notes/MY-PLAN.md$tail" \
        "Custom UPPERCASE filename: knowledge/notes/UP_2.md$tail" \
        "Custom UPPERCASE filename: knowledge/notes/DIRNAME.md$tail"
}

test_bash4_constructs() {
    make_repo || return 1
    render scripts/b4.sh <<'EOF'
#!/usr/bin/env bash
@DECL@ -A seen
# @DECL@ -A in a comment is exempt
x=1; @MAPF@ -t lines < f
@READ@ rows < f
  (@MAPF@ -t sub < f)
echo "no construct here"
EOF
    render scripts/optout.sh <<'EOF'
#!/usr/bin/env bash
# exobrain-allow-bash4 — needs associative arrays
@DECL@ -A allowed
EOF
    render knowledge/notes/_raw/snap.sh <<'EOF'
@DECL@ -A raw
EOF
    validate
    local tail=" — macOS ships bash 3.2 at /bin/bash"
    assert_violations "bash 4 construct" \
        "bash 4 construct in scripts/b4.sh:2$tail" \
        "bash 4 construct in scripts/b4.sh:4$tail" \
        "bash 4 construct in scripts/b4.sh:5$tail" \
        "bash 4 construct in scripts/b4.sh:6$tail"
}

# The array assigned empty in one file is expanded in another — the case the
# repo-wide name collection exists for. Line 7 mixes a guarded and a bare
# expansion; the bare one must still be caught.
test_unguarded_empty_arrays() {
    make_repo || return 1
    render scripts/lib.sh <<'EOF'
zqitems@EMPTY@
zqother=(a b)
EOF
    render scripts/caller.sh <<'EOF'
#!/usr/bin/env bash
for i in "${zqitems[@]}"; do :; done
for i in ${zqitems[@]+"${zqitems[@]}"}; do :; done
# "${zqitems[@]}" in a comment is exempt
echo "${!zqitems[@]}" "${zqitems[*]}"
for i in "${zqother[@]}"; do :; done
f "${zqitems[@]}" ${zqitems[@]+"${zqitems[@]}"}
EOF
    validate
    local tail=' — write ${name[@]+"${name[@]}"}; bash 3.2 errors on an empty array under set -u'
    assert_violations "unguarded array expansion" \
        "unguarded array expansion in scripts/caller.sh:2$tail" \
        "unguarded array expansion in scripts/caller.sh:5$tail" \
        "unguarded array expansion in scripts/caller.sh:7$tail"
}

# The reverse scan reads every file for markers; only a comment line in any of
# the recognised comment styles is one, and _raw/ snapshots are exempt.
test_compat_markers_found_in_every_file_kind() {
    make_repo || return 1
    { printf '# Compatibility shims\n\n## Ledger\n\n| id | Heals | Files | Added | Remove after |\n|---|---|---|---|---|\n'
      printf '| 0001 | A. | `scripts/shim.sh` | 2026-01-01 | 2099-01-01 |\n'
    } > knowledge/exobrain/compat.md
    render scripts/shim.sh <<'EOF'
#!/usr/bin/env bash
# @COMPAT@ 0001 (remove after 2099-01-01) — listed and valid
EOF
    render scripts/norow.sh <<'EOF'
# @COMPAT@ 0009 (remove after 2099-01-01) — no ledger row
EOF
    render scripts/nodate.py <<'EOF'
// @COMPAT@ 0001 — no date
EOF
    render knowledge/notes/doc.md <<'EOF'
Prose that mentions @COMPAT@ 0001 is not a marker.
<!-- @COMPAT@ 0001 (remove after 2099-01-01) — HTML-comment marker -->
EOF
    render knowledge/notes/_raw/vendored.sh <<'EOF'
# @COMPAT@ 0042 (remove after 2099-01-01) — in _raw, exempt
EOF
    validate
    assert_violations "COMPAT 0" \
        "COMPAT 0009 marker with no row in knowledge/exobrain/compat.md: scripts/norow.sh" \
        "COMPAT 0001 marker missing its '(remove after YYYY-MM-DD)' date: scripts/nodate.py" \
        "COMPAT 0001 marker in a file its ledger row doesn't list: scripts/nodate.py" \
        "COMPAT 0001 marker in a file its ledger row doesn't list: knowledge/notes/doc.md"
}

test_clean_tree_is_clean() {
    make_repo || return 1
    printf '#!/usr/bin/env bash\nset -euo pipefail\necho ok\n' > scripts/fine.sh
    printf 'lowercase\n' > knowledge/notes/fine-note.md
    validate
    [[ "$OUT" == *"clean (0 violations)"* ]] || { echo "expected a clean run:"; echo "$OUT"; return 1; }
}

# ---------------------------------------------------------------------------

echo
printf "${BOLD}validator whole-tree checks${RESET}\n"
run_test "UPPERCASE .md names"                          test_uppercase_names
run_test "bash 4 constructs"                            test_bash4_constructs
run_test "unguarded empty-array expansions"             test_unguarded_empty_arrays
run_test "COMPAT markers in every file kind"            test_compat_markers_found_in_every_file_kind
run_test "a clean tree is clean"                        test_clean_tree_is_clean

echo
if [[ $TESTS_FAILED -eq 0 ]]; then
    printf "${GREEN}${BOLD}%d/%d passed${RESET}\n" "$TESTS_PASSED" "$TESTS_RUN"
    exit 0
fi
printf "${RED}${BOLD}%d/%d failed${RESET}:\n" "$TESTS_FAILED" "$TESTS_RUN"
for f in ${FAILURES[@]+"${FAILURES[@]}"}; do printf "  ${RED}- %s${RESET}\n" "$f"; done
exit 1
