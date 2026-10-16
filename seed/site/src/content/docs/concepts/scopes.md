---
title: Scopes
description: How an exobrain decides which context loads — for this person, on this machine, in this session.
---

Not everything should load every session. A path that only exists on your laptop is noise on your desktop; your colleague's preferences aren't yours. Scopes are how an exobrain decides what applies.

## A scope is a directory

Specifically, a directory containing an `AGENTS.md`. That file is the flag — its presence makes the directory a scope. Scopes nest by containment, so the structure is just your filesystem.

```
exobrain/
├── AGENTS.md                          ← global: applies to everyone
└── people/
    └── you/
        ├── AGENTS.md                  ← you: your preferences, your projects
        └── hosts/
            └── laptop/
                └── AGENTS.md          ← this machine: paths, local services
```

## Connect a leaf, inherit the chain

You connect the innermost scope that describes your situation — you, on this machine. The agent resolves that leaf plus every scope containing it:

```
global  <  …any scopes between…  <  you  <  this machine
```

Everything in the chain loads. Where two scopes say different things about the same subject, **the deepest one wins** — the machine-specific rule beats the personal one, which beats the global one.

That single rule is what lets the same repository serve you on three machines, and serve other people at the same time, without anyone's context leaking into anyone else's session.

## What goes where

The bias is to put a thing at **the lowest scope it fits**, because that's the scope where it's true.

| Kind of thing | Scope |
|---|---|
| Conventions everyone follows; how the exobrain itself works | global |
| Your preferences, how you want to be addressed, your projects | person |
| Absolute paths, toolchain locations, local services, machine quirks | host |
| Anything private that must never be committed | a gitignored local scope |

The one hard rule: **machine-specific paths belong only in a host scope.** Anything above that is shared across machines, and an absolute path there is wrong somewhere.

## Per-agent sidecars

Most context is agent-neutral and belongs in `AGENTS.md`. When something genuinely applies to only one agent — a tool it alone has, a quirk it alone has — it goes in a sidecar beside it: `CLAUDE.md`, `CODEX.md`, `OPENCLAW.md`.

This is what makes switching agents cheap. The universal material is untouched; only the sidecar differs.

## Keeping it small

Scoped context loads every session, so it costs tokens every session. The discipline is to state rules flatly and push explanation into on-demand documents. A scope file that grows into an essay is one the agent starts skimming — and a rule that gets skimmed is worse than no rule, because you believe it's in effect.
