---
id: 0118
title: Name a connector mode for what it does, not what it withholds
date: 2026-08-13
tags: [connector, naming, docs, compat]
touches_invariant: false
files: [scripts/connect-agent.sh, knowledge/exobrain/agents.md, knowledge/exobrain/machinery.md, knowledge/exobrain/compat.md, skills/exobrain-ab/SKILL.md, skills/exobrain-tests/unit/test-connect-agent.sh]
---

## Problem

The connector mode that wires a throwaway copy was called `--render-specs-only`.
Both halves misdescribe it. It does not render *specs*: it performs a real connect
— skills linked, indexes generated, the per-agent surface composed — truncated
before the writes that reach outside the checkout. And "only" reads as a preview,
which invited two wrong beliefs: that the result is a lesser artifact than a real
connect, and that it leaves the copy unconnected. Neither holds. For claude the
mode writes the very file that is the connect marker, so a wired sandbox *is*
connected, by the same test everything else uses.

The name had also drifted from its own docs. The prose said the codex/openclaw
guard requires the override to point "away from the real home config"; the code
checks only that the variable is *set*. A reader trusting that sentence would point
it anywhere and believe they were protected.

## Pattern

Name a mode for the thing it produces. `--wire-sandbox` says what it makes (real
wiring) and who it is for (a throwaway copy — a test sandbox, a CI checkout).

Rename the internals with the flag. A script whose variable still says `RENDER_ONLY`
teaches the old model to the next reader, and the prose around it drifts back.

Keep the old name working through the changeover, as a shim with a date rather than
a permanent alias: accept it, warn on stderr, record it in the shim ledger, and
cover it with a test that dies with the shim.

Then say what the mode actually does, in one place. Where the docs restated the
write envelope a second time, they cross-reference it instead — a rule stated twice
is a rule that will disagree with itself.

## Reference (illustration only)

```bash
--wire-sandbox)       WIRE_SANDBOX=true ;;
# COMPAT <id> (remove after <date>) — the flag's name before --wire-sandbox.
--render-specs-only)  WIRE_SANDBOX=true
                      echo "warning: --render-specs-only is now --wire-sandbox" >&2 ;;
```

(The marker above carries placeholders on purpose: a real id and date in a card
would register the card itself as a shim site.)

## Adapt notes

Supersedes the flag name used in cards 0029, 0035, 0046 and 0102; those cards
describe the mode's behaviour, which is unchanged. Sweep every caller — the A/B
eval harness invokes the flag by name, and a test fixture that still passes the old
one will pass while printing a warning nobody reads.

Set the shim's removal date from the window your callers need: this one is a flag
on a script, so a single pass over the callers clears it.
