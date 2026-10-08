# Mounts

A **mount** is a shared knowledge repository this instance reads from a local checkout: a repository holding `knowledge/<domain>/`, `workspaces/`, and a README, whose audience is its collaborators. Knowledge meant for a different audience — a project shared with a collaborator who has no business in the rest of this instance — lives in such a repository, and every instance whose people are in its audience mounts it. Framework (specs, scripts, skills, tools, scopes) lives in each person's own instance, once; a mount carries none, so nothing in it is ever an instruction and nothing in it has a version to keep in step.

## The charter

`mounts.json` at the repo root (schema: `mounts.schema.json`) declares each mount with its **charter**, and a mount is never declared without one:

| Field | Meaning | Enforced by |
|---|---|---|
| `name` | Kebab-case id, distinct from every local domain: the default checkout (`src/<name>/`), the index prefix (`<name>/<domain>`), and the citation prefix (`<name>:<path>`) | The validator |
| `repo` | The clone URL; an existing checkout is accepted when its origin is the same repository in any spelling | `mounts.sh enable` |
| `audience` | Person ids who can read the repository | The index heading; a fact is recorded there only when everyone named may read it |
| `purpose` | One line: what the repository is for | The index heading |
| `holds` | The domains it carries, by directory name, each with a one-line description written here | Only these are indexed, with that description; a domain in the checkout outside the list, or a held domain the checkout lacks, is reported as drift |
| `never` | Topics, literal terms, and patterns that do not belong there | § Isolation: terms and patterns by the gate, topics by the authoring review |

The top-level `instance` block is this instance's own charter relative to its mounts: its audience and its `never` list. Charters live in the instance that mounts, never in the mount: a mount carries no configuration about who reads it. A `never` term too sensitive for the tracked file goes in the gitignored `local/` scope's `local/mounts.json`, the same shape, merged over the tracked charter on the machine that carries it.

A mount whose boundary cannot be stated in `holds` and `never` is not declared. A fuzzy boundary is a leak waiting to happen.

## What a mount exposes

- **The held knowledge domains, and nothing else.** Each `knowledge/<domain>/README.md` the charter holds appears in this instance's knowledge index as `<mount>/<domain>`, with the charter's description as its summary. No text the mount's audience writes reaches an auto-loaded surface: the README's own summary is not read.
- **Its workspaces are read by path** and cited like any other mounted file; nothing indexes them.
- **A mount carries no framework.** An `AGENTS.md`, or a `scripts/`, `skills/`, `people/`, or `tools/` directory in the checkout is reported by `mounts.sh status`, the connector, and the healthcheck as a misconfigured mount; the held domains are still indexed.
- **One-way and non-transitive.** The mounted repository does not know it is mounted, never references the instance that mounts it, and any `mounts.json` of its own is ignored. `validate-exobrain.sh` rejects a relative link that climbs out of a repository, which is the shape such a reference takes.

## Enabling

- `.exobrain.json` (per machine, gitignored) holds `mounts.<name>.enabled` and an optional `mounts.<name>.path`. By default the checkout is `src/<name>/` in the main checkout; `path` reuses a checkout the machine already has. Worktrees resolve mounts through the main checkout, so every worktree reads the same checkout.
- `scripts/mounts.sh enable <name>` clones the repository (or checks that an existing checkout's origin is that repository), writes `.exobrain.json`, and relinks every connected agent so the index follows. `--path <dir>` names an existing checkout; `--default-path` drops such an override. The human runs it.

## The knowledge index

Each declared mount gets its own section after this instance's domains:

- **Available:** the heading names the mount and its purpose, then the audience, the repository, the checkout path, the citation form, and one row per held domain with the README's absolute path and the charter's description.
- **Not available** (not enabled on this machine, or no checkout): the section says so and names the enable command. That way the missing knowledge reads as not here rather than as not existing.

OpenClaw's semantic recall also covers each indexed mounted domain (`memory.search.extraPaths`).

## Citing a mounted file

From this instance, cite a file in a mount as `<mount>:<path>`, the path relative to the mounted repository — `acme-eng:knowledge/billing/status.md`. It resolves in the checkout that the mount's index heading names. A Markdown link cannot point into a mount, because the checkout's location differs from machine to machine. The validator resolves each such citation in changed markdown against the enabled checkout, and says how many it left unchecked when the mount is not enabled on the machine.

## Isolation

Information from a root belongs to that root's audience, and landing it in another root exposes it to that root's audience. Which lands are gated follows from the audiences:

- A mount whose audience is **strictly narrower** than this instance's is the **private party**: every land into this instance is gated against it.
- Any other mount is the **shared party** — what its people write is what this instance's people chose to read by mounting it — and every land into it is gated against this instance, and against every other mount whose audience does not include all of its own.
- Equal audiences gate nothing.

`scripts/mount-isolation.py --worktree <dir> --plan` says which roots gate a given land and why.

**The gate** is `scripts/mount-isolation.py`, deterministic, run by persist on every land before the validator. It scans what the land adds — the added lines of every changed file, committed or not, `_raw/` included, each changed file's name, the branch's name and commit messages, the PR title, and the `--context` handover that goes into the PR body — and blocks, attended or unattended, on:

- **Text the gate cannot read.** A changed text file that is not UTF-8 (UTF-16 and UTF-32 are decoded and scanned); recode it. A binary file passes on its name alone.
- **Out of charter.** Into a mount: a file under a `knowledge/<domain>/` the charter does not hold, or a framework file, added or edited. A land that removes one passes.
- **Never terms and patterns** of every gated source, plus card numbers and IBANs (checksum-validated, so an arbitrary digit run is not a hit). National identifiers, emails, and phone numbers are not built in; a charter lists the shapes that must stay out under `patterns`.
- **References into a gated source:** its repository, its checkout path, a mount's name as a `<mount>:<path>` citation — and, into a mount, any `<name>:<path>` citation at all.

**The topics** are judged by the authoring review, which persist runs with the gate's audience lens (`--lens`): who reads the target, its purpose and held domains, and each gated source's never-topics. Under the lens, every changed text file under `knowledge/` and `workspaces/` is reviewed, not only markdown. A lens finding on a land into a mount blocks in every mode, and so does a review that did not answer (no engine, an error, a timeout, an empty result) — the land waits for one that does; a finding on a land into this instance blocks an attended land and is posted as a review on the PR of an unattended one, like any authoring finding, and a review that did not answer there degrades open.

**Drift, not a leak.** A local file that restates a fact whose home is a shared mount, instead of citing it as `<mount>:<path>`, exposes nothing; the lens asks the review to name it as drift.

**Workspaces** are where boundaries get crossed: session narrative, partially processed `_raw/` material, pasted rows. A workspace lives in the root whose charter covers the effort and passes the same gate as knowledge. An effort covering both roots gets one workspace in each: the private material in the narrower root, the shared findings in the wider one, the narrower side citing the wider and never the reverse.

## Changing a mount

A change to a mount is made in a worktree of its checkout and landed through this instance's machinery:

1. `scripts/mounts.sh worktree <name> <branch>` creates the worktree (this instance's `create-worktree.sh`, run in the checkout) and prints its path.
2. Work there. A workspace for the effort lives in the root whose charter covers it (§ Isolation).
3. `scripts/persist.sh --repo <worktree> -m "<message>"` lands it through the persist flow (the `exobrain-persist` skill has the sequence). What differs for a mount: this instance's validator runs on the worktree (`validate-exobrain.sh --repo`), the authoring review runs under the audience lens, and the timeline author comes from this instance's `.exobrain.json`.

The checkout itself never holds edits: `sync` will not touch a dirty checkout, and the healthcheck reports one. Moving facts into a mount widens who can read them from then on; taking someone's access away later does not remove clones they already made. The rules for which repository a fact belongs in are root `AGENTS.md` § Mounts.

## Freshness

A mount is read as of its last sync. Pulling this instance syncs its mounts: the post-merge and post-rewrite hooks run `scripts/mounts.sh sync` before they relink, so a domain a mount gained reaches the index in the same pull.

- `scripts/mounts.sh sync [<name>]` fetches, then fast-forwards a clean checkout sitting on its origin's default branch. It resolves that branch from origin rather than assuming a name. A checkout that is dirty, off that branch, ahead, or diverged is reported and left as it is: sync never resets, stashes, rebases, or switches branches. When a sync adds or removes a domain, it relinks.
- `exobrain-healthcheck.sh` runs the same throttled, time-boxed fetch it uses for trunk. It reports an enabled mount that is missing, behind, dirty, off its default branch, or ahead of its origin, one whose last successful fetch is more than a day old, and charter drift: a domain outside the charter, a held domain missing, framework files in the checkout. The time of the last successful fetch is kept in `.git/exobrain-last-fetch` inside the mount's checkout.
- Offline, the last checkout is what is read, and the healthcheck says how old it is.

## The `exobrain-mounts` skill

The judgment layer over these scripts is the `exobrain-mounts` skill (`skills/exobrain-mounts/SKILL.md`). Its behavior cases in the `exobrain-tests` suite are the `mount-*` cases, seeded by `behavior/lib/seed-mount.sh`.

## `mounts.sh`

| Command | Does |
|---|---|
| `status [<name>]` | Each declared mount: purpose, audience, held domains, repository, checkout path, branch, ahead/behind as of the last fetch, clean or dirty, and charter drift. No network. Exits 1 on drift. |
| `enable <name> [--path <dir> \| --default-path]` | Clones into `src/<name>/`, or into `<dir>`, or verifies the existing checkout there. Records the state and relinks. |
| `disable <name>` | Stops indexing the mount and relinks. The checkout stays where it is. |
| `sync [<name>]` | Described under § Freshness. Exits 1 when any mount needs attention. |
| `worktree <name> <branch>` | A worktree of the mount's checkout for a change to it; prints its path. |
| `audience <name>` | The repository's collaborators and visibility through `gh`, beside the charter's audience. |

The connector, healthcheck, validator, and `mounts.sh` share the resolution helpers in `scripts/skills-registry.sh` § Mounts. Tests: `skills/exobrain-tests/unit/test-mounts.sh`.
