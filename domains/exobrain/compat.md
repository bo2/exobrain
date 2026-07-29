# Compatibility shims

Transitional code: a cleanup that heals checkouts carrying state from before a change, a fallback for a renamed key. It is correct while checkouts are crossing over, and dead weight once they all have. Unmarked, it outlives its reason — nobody remembers what it healed, so nobody dares delete it.

A mechanism that keeps earning its keep is not a shim. The connector rewrites the git hooks on every relink so *future* template changes reach connected checkouts; that pays off indefinitely and has no removal date. A shim, by contrast, names a state that stops existing.

Every shim carries a **marker** at the code site and a **row** in the ledger below. `validate-exobrain.sh` fails when the two disagree; `exobrain-healthcheck.sh` names each shim past its date at session start — advisory, so a due shim nags every session and blocks no push.

## Marking one

Take the next unused id (four digits, never reused) and open the block with it. The marker is the block's opening **comment line** — a doc or test quoting the string in prose is not a marker, so writing about one is safe:

```bash
# COMPAT 0007 (remove after 2026-09-15) — codex config key renamed; read the old one too.
```

Then add a ledger row: the id, what old state it heals, every file carrying that marker (the code *and* its tests), the date it landed, the date it may go. Set the removal date from the window a checkout needs to cross the shim once — a connector shim clears as soon as every machine has run one connect or relink, so 30 days is generous; a shim waiting on a human migration needs however long that migration takes.

## Removing one

Delete the marked block, the tests that cover it, and the row — in one change. The ledger lists live shims only; retired ones live in git history. If a shim still earns its keep when the date arrives, move the date out and say why in the commit: a bump is a decision, not a default.

## Ledger

| id | Heals | Files | Added | Remove after |
|---|---|---|---|---|
| 0001 | Codex skill symlinks in the agent's home config dir, from before skills linked repo-locally into `.agents/skills`. | `scripts/connect-agent.sh` | 2026-06-18 | 2026-08-28 |
| 0002 | The `<!-- BEGIN exobrain -->` marker block in the Codex home `AGENTS.md`, superseded by the in-repo `AGENTS.override.md`. | `scripts/connect-agent.sh` | 2026-07-11 | 2026-08-28 |
| 0003 | Generated index copies in the agent's home config dir, from when that dir was the delivery transport. | `scripts/connect-agent.sh`, `skills/exobrain-tests/unit/test-connect-agent.sh` | 2026-07-28 | 2026-08-28 |
