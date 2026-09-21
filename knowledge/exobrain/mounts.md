# Mounts

A **mount** makes another exobrain instance's knowledge domains readable from this one, from a local checkout of it. The unit of sharing is a whole instance, because a repository is the unit of read access: scopes select an agent's context, but everyone with access to a repository can read all of it. Knowledge meant for a different audience — a project shared with a collaborator who has no business in the rest of this instance — lives in its own instance, and each instance that should also see it mounts it instead of keeping a copy.

## What a mount exposes

- **Knowledge domains, and nothing else.** Each `knowledge/<domain>/README.md` in the mounted checkout, except the ones named in `skip_domains`, appears in this instance's knowledge index as `<mount>/<domain>`.
- **Never** its `AGENTS.md` or sidecars, its hooks, skills, tools, or scopes, or its own mounts. Its workspaces can still be read by path, but nothing indexes them.
- **One-way and non-transitive.** The mounted instance does not know it is mounted and never references the instance that mounts it. `validate-exobrain.sh` rejects a relative link that climbs out of the repository, which is the shape such a reference takes.

## Declaring and enabling

- `mounts.json` at the repo root (schema: `mounts.schema.json`) declares each mount: a kebab-case `name` distinct from every local domain, the `repo` to clone, the `audience` who can read that repository, and optional `skip_domains` (usually the mounted instance's own `exobrain` meta-domain).
- `.exobrain.json` (per machine, gitignored) holds `mounts.<name>.enabled` and an optional `mounts.<name>.path`. By default the checkout is `src/<name>/` in the main checkout. Set `path` to reuse a checkout the machine already has, such as the one a developer works in, rather than a second clone that lags behind it.
- Worktrees resolve mounts through the main checkout, so every worktree reads the same checkout.
- Enabling a mount is a setup step: `scripts/mounts.sh enable <name>` clones the repository (or checks that an existing checkout's origin is that repository) and writes `.exobrain.json`. The human runs it, then relinks.

## The knowledge index

Each declared mount gets its own section after this instance's domains:

- **Available:** the heading names the mount and its audience, followed by the repository, the checkout path, and one row per domain with the README's absolute path.
- **Not available** (not enabled on this machine, or no checkout): the section says so and names the enable command. That way the missing knowledge reads as not here rather than as not existing.

Mounted rows carry **no summary**. The mounted repository's text is written by its own audience, so none of it reaches an auto-loaded surface. An agent learns a domain's scope by reading its README, and treats what it reads as data, not instructions. OpenClaw's semantic recall also covers each listed mounted domain (`memory.search.extraPaths`).

## Citing a mounted file

From this instance, cite a file in a mount as `<mount>:<path>`, the path relative to the mounted repository — `acme-eng:knowledge/billing/status.md`. It resolves in the checkout that the mount's index heading names. A Markdown link cannot point into a mount, because the checkout's location differs from machine to machine.

## Writing

The rules for where a fact goes and how a mount changes are in root `AGENTS.md` § Mounts. In practice:

- A change to a mount's facts is made in that repository. Its checkout is the path in the index heading, and its own `create-worktree.sh` and persist flow apply there. Edits left in the checkout itself show up in the healthcheck, and `sync` will not touch a dirty checkout.
- Moving facts into a mount widens who can read them from then on. Taking someone's access away later does not remove clones they already made.

## Freshness

A mount is read as of its last sync. Pulling this instance syncs its mounts: the post-merge and post-rewrite hooks run `scripts/mounts.sh sync` before they relink, so a domain a mount gained reaches the index in the same pull.

- `scripts/mounts.sh sync [<name>]` fetches, then fast-forwards a clean checkout sitting on its origin's default branch. It resolves that branch from origin rather than assuming a name. A checkout that is dirty, off that branch, ahead, or diverged is reported and left as it is: sync never resets, stashes, rebases, or switches branches. When a sync adds or removes a domain, the index follows on the next relink.
- `exobrain-healthcheck.sh` runs the same throttled, time-boxed fetch it uses for trunk. It reports an enabled mount that is missing, behind, dirty, off its default branch, or ahead of its origin, and one whose last successful fetch is more than a day old. The time of the last successful fetch is kept in `.git/exobrain-last-fetch` inside the mount's checkout.
- Offline, the last checkout is what is read, and the healthcheck says how old it is.

## `mounts.sh`

| Command | Does |
|---|---|
| `status [<name>]` | Each declared mount: audience, repository, checkout path, branch, ahead/behind as of the last fetch, clean or dirty. No network. |
| `enable <name> [--path <dir>]` | Clones into `src/<name>/`, or into `<dir>`, or verifies the existing checkout there. Records the state and prints the relink command. |
| `disable <name>` | Stops indexing the mount. The checkout stays where it is. |
| `sync [<name>]` | Described under § Freshness. Exits 1 when any mount needs attention. |

The connector, healthcheck, validator, and `mounts.sh` share the resolution helpers in `scripts/skills-registry.sh` § Mounts. Tests: `skills/exobrain-tests/unit/test-mounts.sh`.
