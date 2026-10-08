#!/usr/bin/env bash
# seed-mount.sh — sourced by a case's setup.sh: seed_mount <instance> plants a
# content-only mounted repository at <instance>/src/fx (its default branch `main`,
# no origin, so a land into it fast-forwards locally), declares it in mounts.json
# with a charter, enables it in .exobrain.json, commits the declaration onto main,
# and re-wires every agent the sandbox connected so the knowledge index lists it.
#
# The mount: one held domain (projects, about "the fx project"), one domain the
# charter does not hold (internal), and a workspace. The instance's charter: readable
# by the sandbox person, never the terms a case plants as household-private.
seed_mount() {
    local inst="$1" person m
    m="$inst/src/fx"
    person="$(jq -r '.person // "test-user"' "$inst/.exobrain.json" 2>/dev/null)"; person="${person:-test-user}"
    mkdir -p "$m/knowledge/projects" "$m/knowledge/internal" "$m/workspaces/2026/01/10-fx-export-api"
    git -C "$m" init -q -b main
    cat >"$m/README.md" <<'R'
# fx — shared project knowledge

The fx project's knowledge and the work in flight, shared by its developers.
R
    cat >"$m/knowledge/projects/README.md" <<'R'
---
name: projects
summary: The fx project — a small export service — and the decisions that hold.
---

# Projects

## fx

A service that exports a household's ledger rows as CSV through an HTTP API. Status: beta.
Decisions that hold: the API is versioned under `/v1`; exports are paginated.
R
    cat >"$m/knowledge/internal/README.md" <<'R'
---
name: internal
summary: Not in the charter.
---

# Internal
R
    printf '# fx export API\n\nThe plan for the export API, in flight.\n' > "$m/workspaces/2026/01/10-fx-export-api/README.md"
    git -C "$m" add -A
    git -C "$m" -c user.email=harness@exobrain.test -c user.name='exobrain harness' commit -q -m "fx base"

    jq -n --arg p "$person" '{
        instance: {audience: [$p], never: {
            topics: ["the household'"'"'s own money, accounts, and members"],
            terms: ["Example Bank", "joint account"]}},
        mounts: [{name: "fx", repo: "https://example.invalid/fx.git", audience: [$p, "bob"],
                  purpose: "fx development: the export service and the work in flight",
                  holds: {projects: "The fx project: what it is, its API, and the decisions that hold."},
                  never: {topics: ["any household'"'"'s private data"]}}]}' > "$inst/mounts.json"
    if [[ -f "$inst/.exobrain.json" ]]; then
        jq '.mounts = ((.mounts // {}) + {fx: {enabled: true}})' "$inst/.exobrain.json" > "$inst/.exobrain.json.t" \
            && mv "$inst/.exobrain.json.t" "$inst/.exobrain.json"
    else
        printf '{"mounts":{"fx":{"enabled":true}}}\n' > "$inst/.exobrain.json"
    fi
    git -C "$inst" add -A
    git -C "$inst" -c user.email=harness@exobrain.test -c user.name='exobrain harness' \
        commit -q -m "case: declare the fx mount" || true

    # Re-wire the agents the sandbox connected, in place (--wire-sandbox writes nothing
    # outside the instance), so the index shows the mount.
    [[ -f "$inst/.claude/CLAUDE.md" ]] && bash "$inst/scripts/connect-agent.sh" claude --wire-sandbox >/dev/null 2>&1
    [[ -d "$inst/.codex" ]] && CODEX_HOME="$inst/.codex" bash "$inst/scripts/connect-agent.sh" codex --wire-sandbox >/dev/null 2>&1
    return 0
}

# mount_tree_files <instance> — every file under the mount's checkout and its
# worktrees (src/fx, src/fx--*), minus git internals; the helpers' grep_run and
# find_run prune src/, so a case looks here itself.
mount_tree_files() {
    find "$1"/src/fx "$1"/src/fx--* -name .git -prune -o -type f -print 2>/dev/null
}

# mount_edited_in_place <instance> — prints the offending reflog line when the
# mount's main advanced by a commit made on the checkout itself (a land through a
# worktree arrives as a fast-forward merge), or when the checkout is dirty.
mount_edited_in_place() {
    local m="$1/src/fx"
    [[ -z "$(git -C "$m" status --porcelain 2>/dev/null)" ]] || { echo "dirty checkout"; return; }
    git -C "$m" reflog show main 2>/dev/null | grep -E 'main@\{[0-9]+\}: (commit|commit \(amend\)|reset):' | head -1
}

# mount_landed_files <instance> — files the agent added or changed in the mount:
# in its worktrees against main, and on main itself since the seed commit.
mount_landed_files() {
    local inst="$1" m wt
    m="$inst/src/fx"
    { git -C "$m" diff --name-only "$(git -C "$m" rev-list --max-parents=0 HEAD)" main 2>/dev/null | sed "s#^#$m/#"
      for wt in "$inst"/src/fx--*; do
          [[ -d "$wt" ]] || continue
          { git -C "$wt" diff --name-only main 2>/dev/null; git -C "$wt" ls-files --others --exclude-standard 2>/dev/null; } | sed "s#^#$wt/#"
      done
    } | sort -u
}
