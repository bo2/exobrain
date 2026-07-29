---
id: 0093
title: Ledger every compatibility shim with a removal date
date: 2026-07-29
tags: [scripts, gates, maintenance]
touches_invariant: false
files: [domains/exobrain/compat.md, scripts/validate-exobrain.sh, scripts/exobrain-healthcheck.sh, skills/exobrain-tests/unit/test-compat-ledger.sh, AGENTS.md]
---

## Problem

Transitional code — the cleanup that heals checkouts carrying state from before a change — is correct while checkouts are crossing over and dead weight once they all have. Nothing distinguishes the two, so it survives indefinitely: a later reader meets a block whose reason is undocumented, cannot prove deleting it is safe, and leaves it. Connectors accrete these fastest, since every change to how context is delivered leaves one behind. The cost is silent — dead branches that every future edit has to reason around.

## Pattern

Give each shim two halves that check each other: a **marker** on the code block and a **row** in one tracked ledger.

- The marker is the block's opening comment line, carrying the id and the date: `COMPAT 0007 (remove after 2026-09-15) — <what old state this heals>`. Requiring a comment line keeps docs and tests that quote the string from reading as live shims.
- The row carries the id, what it heals, every file carrying that marker (the code *and* its tests), the date it landed, and the date it may go.

The deterministic push gate holds the two in sync **both ways** — a row's files must carry its marker, a marker must have a row, and the two must agree on the date — so a shim can neither lose its date nor outlive its entry. The **date** belongs to the advisory session-start check, not the push gate: an overdue shim is named every session and blocks nothing, because a calendar boundary is a poor reason to stop an unrelated push. Retiring one deletes code, tests, and row in a single change; the ledger lists live shims only.

Set each date from the window a checkout needs to cross the shim once — for connector shims, one connect or relink per machine. A shim that still earns its keep at the date gets an explicit bump with a reason, which is a decision rather than a default.

The distinction worth stating in the ledger itself: a mechanism that keeps paying off is not a shim. Re-running hook installation on every relink carries *future* template changes to connected checkouts, so it has no end date; a shim, by contrast, names a state that stops existing.

## Adapt notes

- Ledger rows are instance state, not framework content: an instance carries rows for the shims *its* tree holds, dated from *its* adoption, not the seed's.
- Put the ledger wherever the instance keeps meta-domain docs; the two gates only need one agreed path.
- The marker grep runs over the whole tree — reuse the validator's existing prune list for clone/generated dirs so it stays sub-second, and skip the ledger itself, whose convention section shows an example marker on a comment line.
