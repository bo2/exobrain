---
name: exobrain-mounts
description: "Work with this exobrain's mounts — the shared knowledge repositories it reads and writes beside its own content, each with a charter (audience, purpose, the domains it holds, what never goes there). status: every mount's charter, checkout state, and drift. declare: write a new mount's charter through a short grill and refuse a fuzzy boundary. enable/disable: relay the per-machine command. route: decide which root an effort's workspace and facts belong in, and open the worktrees. land: persist every open worktree through its own root, with the isolation gate. audit: run the gate on a worktree or a whole checkout. audience: compare a charter's audience with the repository's collaborators. Use when a task touches a mounted project, when asked to declare, mount, enable, or check a shared repository, when unsure which repository a workspace or fact goes in, or before landing anything that crosses an audience boundary."
---

# Exobrain Mounts

The judgment over this exobrain's mounts; the model, the charter, the index, the gate, and the scripts are [`knowledge/exobrain/mounts.md`](../../knowledge/exobrain/mounts.md), and the rules an agent must follow around a mount are root `AGENTS.md` § Mounts.

| Mode | Does | When |
|---|---|---|
| `status` | Each mount's charter, checkout state, and drift; which roots gate a land where. | *"What's mounted?"* / *"is the shared repo current?"* |
| `declare <name>` | Grill the human for a charter, write the `mounts.json` entry, refuse a boundary that cannot be stated. | A new shared repository to mount. |
| `enable` / `disable` | Relay `scripts/mounts.sh enable|disable <name>` for the human to run. | A mount declared but not available here. |
| `route` | Name the root each artifact of a task belongs in and open the worktrees. | Any effort touching a mounted project. |
| `land` | Persist every worktree the session opened, each through its own root. | The effort's changes are done. |
| `audit` | Run the isolation gate on a worktree, or on a whole checkout against its default branch. | *"Is anything in here that shouldn't be?"* |
| `audience <name>` | The repository's collaborators and visibility beside the charter's audience. | Before widening a charter, or on a drift note. |

## `status`

```bash
scripts/mounts.sh status                               # charter, checkout, drift per mount (exit 1 on drift)
scripts/mount-isolation.py --target <name> --plan      # which roots gate a land into <name>, and why
scripts/mount-isolation.py --target instance --plan    # the same for a land into this instance
```

Report drift as the charter's question, not the checkout's: a domain outside `holds` is either a domain to hold (name it, with its description) or content that does not belong in that repository; framework files mean the repository is not content-only.

## `declare <name>`

Ask, in this order, and write the answer as the charter:

1. **Audience** — the person ids who can read the repository, as `people/` names them. Check with `audience` once the entry exists.
2. **Purpose** — one line: what the repository is for.
3. **Holds** — each domain it carries, by directory name, with a one-line description written here. This description is what reaches the knowledge index; the mount's own README summaries never do.
4. **Never** — topics (judged by the authoring review under the audience lens), literal terms, and patterns (matched by the gate). Terms unfit for a tracked file go in `local/mounts.json`.
5. **Repository** — the clone URL.

Validate with `scripts/validate-exobrain.sh`, then relay `scripts/mounts.sh enable <name>` (`--path <dir>` to reuse a checkout the machine has). If step 3 or 4 cannot be answered, stop: say what is unclear and do not write the entry.

## `route`

For each artifact the task will produce — a workspace, a fact, a script — name the root whose charter covers it, and say why in a line. Then open what the task needs:

```bash
scripts/mounts.sh worktree <name> <branch>     # a worktree of the mount's checkout; prints its path
scripts/create-worktree.sh <branch>            # a worktree of this instance, as always
```

Work in the worktree the artifact belongs to. Cite across roots only from the narrower side.

## `land`

For each worktree the session opened, from this instance's checkout:

```bash
scripts/persist.sh --repo <mount worktree> -m "<message>" [--context <handover>]   # a mount's worktree
scripts/persist.sh -m "<message>"                                                  # this instance's, from inside it
```

A gate finding names the file, line, and what crossed: move the material to the root whose audience may read it, or cut it, amend, and re-run. The `exobrain-persist` skill (step 5) is the land itself.

## `audit`

```bash
scripts/mount-isolation.py --worktree <dir> [--base <ref>] [--text <file>]...   # what this worktree would land
```

To audit a whole checkout, make a throwaway worktree of its default branch, and run the gate with `--base` set to the first commit (`git rev-list --max-parents=0 HEAD`): every line counts as added. Report findings by class and file; do not edit the mount's history.

## `audience <name>`

```bash
scripts/mounts.sh audience <name>     # collaborators and visibility through gh, beside the charter's audience
```

A collaborator the charter does not name is a reader the gate does not know about; a public repository makes every land into it a public publish. Either way, stop and tell the human before landing.
