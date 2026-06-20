---
status: active
created: 2026-06-19
owner: oleg
related:
  - domains/exobrain/scopes.md
  - domains/exobrain/agents.md
  - domains/exobrain/machinery.md
  - scripts/connect-agent.sh
  - scripts/skills-registry.sh
  - seed/skills/create-instance/
  - seed/tests/
---

# Connect & test refactor

Two intertwined reworks, designed together because the test redesign exposed the
connection model:

1. **Connection model** — make scope connection uniform. The connector stores a
   flat list of scope paths and treats them all alike; "person" and "host" stop
   being structurally special. `create-instance` (scaffold) and `connect-agent`
   (identity + connection) split cleanly.
2. **Test suite** — split the seed-local behavioral harness into a **universal**
   suite that runs on any instance (`exobrain-tests`) and a thin **seed-only**
   wrapper (`seed-tests`). `seed/` becomes a real scope.

Readers: the implementing agent (needs the target state, the surface area, and a
shippable sequence) and oleg (reviewing the decisions before build).

## Decisions (settled)

1. **Arbitrary scopes are connectable.** `connected_scopes` is a list; the
   resolver (`build_scope_chain`) unions arbitrary leaves — any `AGENTS.md` dir,
   not only a person/host or one branch. Validated against the code; partially
   documented already (see *Status of prior work*).
2. **Rename `connected` → `connected_scopes`** in `.exobrain.json` and every
   consumer.
3. **The connector is type-agnostic.** `build_scope_chain` already is. After the
   refactor, nothing in the wiring path reads scope *type*.
4. **Ownership by stored person id.** `.exobrain.json` records the connecting
   person's id(s); skill `owner` matches against that — location-independent.
   `owner_self_ids` reads the stored id instead of deriving type-from-folder.
   (`tools.md` already documents an "identity block — person id, hostname";
   today `save_config` writes only `connected`+`agents`, so this implements what
   is already promised.)
5. **Identity resolution = name-match first, `people/`·`hosts/` parent keyword as
   a tiebreaker only.** The collection vocabulary becomes a soft proposal hint,
   not a hard dependency.
6. **First-time setup gathers identity interactively — from the human**, via
   either `connect-agent`'s own prompts or `create-instance`'s chat interview.
   This is about *who answers*, not about `connect-agent` always prompting:
   `connect-agent` accepts the resolved identity from four sources — interactive
   prompts, explicit flags, a copied parent config, or guest (empty).
7. **Tests wire instances without prompts** via two of those sources:
   - *Test on the seed* → guest (person/host empty by design).
   - *Test on a real instance* → copy or symlink `connected_scopes` from the
     parent instance (`create-worktree.sh` already symlinks `.exobrain.json`).
   `discover_person_dirs` and the old non-interactive auto-derive branch are
   removed — nothing derives identity from a headless `connect-agent` run.
8. **Separate `create-instance` from `connect-agent`.** `create-instance`
   scaffolds the instance only and **stops writing `.exobrain.json`**.
   `connect-agent` is the sole owner of identity + connection.
9. **`connect-agent` connection is parameterizable.** A shared connector is fed by
   one of three identity sources — interactive prompts | explicit flags |
   parent-instance copy. `create-instance` calls `connect-agent` at the end with
   the answers it already gathered (no TTY, no re-asking handle/host). Required,
   not optional: an agent running `create-instance` has no human TTY, so a bare
   `connect-agent` call would hit the non-interactive branch and connect the wrong
   scopes — passing params avoids that.
10. **Interactive scope selection.** Show all connectable scopes with **person +
    host pre-checked**; the user toggles/adjusts. `seed` pre-checked when
    `seed/AGENTS.md` is present.
11. **`seed/` becomes a scope** (`seed/AGENTS.md`), auto-included in
    `connected_scopes` when present. The auto-detect is guarded on
    `seed/AGENTS.md`, which exists only in the canonical seed (never copied into
    instances), so it can never leak into a rendered instance.
12. **Test split.** `exobrain-tests` = global skill (tier `optional`): the
    universal behavioral cases + the case-runner + a generic provisioner (sandbox
    copy of the target instance). It **ships into instances** so an instance can
    self-test, and the runner also accepts an external instance path. `optional`
    keeps it discoverable but not auto-loaded; it never auto-runs, so the
    agent-usage cost is incurred only on explicit request. `seed-tests` =
    seed-scoped skill: runs the universal suite against the seed (guest base) and
    owns the deterministic connector harness. Universal cases must **self-seed
    their fixtures** (`setup.sh` scaffolds + connects the scopes/domains a case
    needs) so they are portable to any instance.
13. **`test-connect-agent.sh`** (deterministic connector/registry unit tests)
    stays seed-local under `seed-tests`, distinct from the behavioral suite.
14. **Bootstrap coverage is kept.** `seed-tests` drives `create-instance` via a
    builder agent that plays the user (canned answers), which then calls
    `connect-agent` with those answers as flags (Decision 9's path). This
    exercises the real bootstrap flow end-to-end and the parameterized connector
    without a human TTY — a harness simulating the user, not a violation of
    Decision 6.

## Target architecture

### Connection model

`.exobrain.json` (per machine, gitignored):

```json
{ "connected_scopes": ["people/oleg", "people/oleg/hosts/2mac"],
  "person": "oleg",
  "agents": ["claude"] }
```

- **Identity layer** (knows "person"/"host"): resolves `handle` + `hostname` into
  concrete leaf *paths* via name-match (tiebreak on `people/`·`hosts/` parent).
  Source of the values is pluggable: prompts, flags, or a copied parent config.
- **Connector** (knows nothing special): takes a flat list of scope paths,
  validates each has an `AGENTS.md`, writes `connected_scopes`, wires the surface.
- **Ownership**: `owner_self_ids` returns the stored `person` id(s); skill `owner`
  matches against it.

### create-instance vs connect-agent

- `create-instance` — scaffold scope dirs, scripts, domains, README. No
  `.exobrain.json`. Final step: invoke `connect-agent <agent>` with gathered
  params.
- `connect-agent` — establish identity, write `connected_scopes` + `person`, wire
  each agent surface. Single source of truth for connection state.

### Tests

- `exobrain-tests` (global, tier `optional`): universal cases + runner +
  provisioner. Provisions a sandbox (copy of the target instance, or the seed),
  wires it (guest, copied-from-parent, or the case's own fixtures), runs the agent
  task, checks. Runs on any instance; ships into instances so they can self-test
  (manual, never auto-run).
- `seed-tests` (seed scope): runs `exobrain-tests` against a sandbox copy of the
  seed (guest base); owns `test-connect-agent.sh`.
- Cases self-seed fixtures, so even a guest-base run can scaffold the scopes a
  case needs.

### seed scope

`seed/AGENTS.md` marks the canonical seed as a scope. `connect-agent` auto-includes
`seed` in `connected_scopes` when `seed/AGENTS.md` exists. `seed/skills.json`
declares `seed-tests` (and, if registry-tracked, `create-instance`) as owned by
the seed scope.

## Surface area

| Area | Change |
|------|--------|
| `.exobrain.json` + schema/docs | key rename; add `person` id |
| `scripts/connect-agent.sh` | split identity/connector; parameterize (flags); name-match identity; drop discovery + non-interactive derive; store `person`; seed auto-detect; interactive multi-select |
| `scripts/skills-registry.sh` | `build_scope_chain` key; `owner_self_ids` reads stored id; `scope_type_for`/`scopes_collection_for_type` demoted to heuristic/cosmetic |
| `scripts/skills-status.sh`, `scripts/skills-promote.sh` | `connected_scopes` key |
| `scripts/test-connect-agent.sh` | new key + identity model; moves under `seed-tests` |
| `seed/skills/create-instance/SKILL.md` | stop writing `.exobrain.json`; call `connect-agent` with params |
| `seed/AGENTS.md` | NEW — seed scope flag |
| `seed/skills.json` | NEW — declare `seed-tests` (+ `create-instance`?) |
| `skills/exobrain-tests/` | NEW — universal cases + runner + provisioner (migrated from `seed/tests/`) |
| `seed/skills/seed-tests/` | NEW — guest-on-seed runner + `test-connect-agent.sh` |
| `seed/tests/` | dismantled into the two skills above |
| Global `skills.json` | register `exobrain-tests` |
| Docs | `scopes.md`, `agents.md`, `machinery.md`, `skills.md`, `tools.md`, `seed/README.md`, root `AGENTS.md`; + a `feed/` card |

## Sequenced plan

Each phase is an independently shippable PR. Dependency order: 2 → 3 → {4, 5} → 6 → 7.

1. **Doc prerequisite** — land the arbitrary-scope-connection clarification
   (`scopes.md` + `AGENTS.md`). *Done — PR #25, feed card 0043.*
2. **Rename `connected` → `connected_scopes`.** All consumers + docs. *Done — PR
   #27, feed card 0044.* (The `person`-id write moved to 3a — it's entangled with
   the connector logic Phase 3 rewrites.)
3. **Connector refactor** — split into two shippable steps:
   - **3a** — store + read the `person` id (owner-match keys off it, falls back to
     type-derivation). *Done — PR #28, feed card 0045.*
   - **3b** — split identity layer / connector; name-match identity with tiebreaker;
     `--handle`/`--host`/`--scope`/`--guest` flags; interactive multi-select
     (person/host pre-checked); drop discovery + the headless auto-derive. *Done —
     PR #29, feed card 0046.*
4. **create-instance split** — scaffold only; stop writing `.exobrain.json`; end by
   calling `connect-agent <agent> --handle … --host …`. *In progress.*
5. **seed scope** — `seed/AGENTS.md` + `seed/skills.json`; `connect-agent` seed
   auto-detect.
6. **Test split** — extract universal cases + runner into `exobrain-tests` (global,
   tier `optional`); make cases self-seed fixtures; build `seed-tests`
   (guest-on-seed + the connector harness + the builder-agent bootstrap test).
7. **Docs sweep** — `scopes.md`, `agents.md`, `machinery.md`, `skills.md`, seed
   READMEs; publish a feed card.

## Resolved questions

1. **Bootstrap testing under always-interactive** → *keep it* (Decision 14). A
   builder agent plays the user and calls `connect-agent` with flags; the real
   bootstrap path stays covered without a human TTY.
2. **`exobrain-tests` propagation** → *ship into instances*, tier `optional`
   (Decision 12). Discoverable, never auto-run, so usage cost is opt-in.

## Non-goals

- No change to the resolution algorithm itself (deepest-wins union) — only to how
  the leaf list is produced and stored.
- No flattening of the directory structure; `people/`·`hosts/` stay as organizing
  convention.

## Status of prior work

- Phase 1 (the `scopes.md`/`AGENTS.md` clarification that arbitrary scopes are
  connectable + feed card 0043) merged as **PR #25**. Phase 2's rename
  (`connected` → `connected_scopes`) will revise the same `scopes.md` connection
  section — fold the wording forward there.
