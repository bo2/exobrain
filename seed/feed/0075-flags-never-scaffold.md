---
id: 0075
title: Flag-driven connect never scaffolds — connect the deepest existing scope
date: 2026-07-12
tags: [connector, scopes]
touches_invariant: false
files: [scripts/connect-agent.sh]
---

## Problem

Non-interactive connect (`--handle`/`--host`) scaffolded the person + host
scope dirs whenever they were absent — so every fresh machine, CI run, or
mistyped handle silently grew empty `people/<x>/hosts/<y>/` scopes in the
tree, and a scripted caller had no way to say "connect me only if I exist".

## Pattern

Split scaffolding from connection by *entry path*: the **interactive wizard**
(a human present, answers confirmed) is the only path that scaffolds; **flags**
are the scripted path and never create dirs. `--handle` connects the deepest
existing scope for the handle — the host leaf if that dir exists, else the
person scope (ancestors join via chain resolution) — and records the person id
only when a scope actually connected. With no existing scope it connects
nothing beyond `--scope`, printing a notice that names the missing path.
Scripted setups that legitimately need new scopes (`create-instance`, tests)
create the dirs first, then connect — which they already did.

## Adapt notes

- Check what your instance's onboarding docs promise: if a README tells fresh
  users to run the flag path expecting scaffolding, either point them at the
  wizard or have the doc create the scope dirs first.
- Keep the wizard's scaffold behavior; the split is wizard-scaffolds /
  flags-connect, not "never scaffold anywhere".
