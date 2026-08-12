---
id: 0111
title: Gate the handle that decides which identity a machine joins
date: 2026-08-12
tags: [scopes, setup, identity]
touches_invariant: false
files: [scripts/connect-agent.sh, scripts/skills-registry.sh, knowledge/exobrain/scopes.md]
---

## Problem

Identity resolves by **name-match**: the handle typed at setup finds the scope
whose leaf directory carries that name. That is what makes scopes rearrangeable
without a registry — and it means the handle does not *create* an identity so much
as *select* one. Nothing was checking which.

Three ways that goes wrong, all silent:

- **The default was a machine login.** Derived from the git email or `$USER`, so on
  a shared or freshly-imaged box the proposed handle is `admin`, `ubuntu`, `root`.
  Accepting it makes a person scope that names nobody — and collides with the next
  machine that issues the same login.
- **An existing person's id was accepted without comment.** Typing a name someone
  else already has joins *their* scope: their specs load, their owner-gated skills
  resolve, and the config records it as this machine's person.
- **Any other scope type shares the namespace.** Hosts, groups, standalone scopes
  are matched by leaf name too, so a handle equal to a host directory wires that
  host in as if it were a person.

None of these fail. They all produce a working connect with the wrong identity,
which is far more expensive to notice later.

## Pattern

Where an identifier *selects* rather than creates, confirm the selection before
acting on it. Show what already exists, then gate the id three ways:

- a machine login (`admin`, `root`, `ubuntu`, `ec2-user`, `runner`, …) is never
  offered as the bare-Enter default, and is confirmed if typed anyway;
- an id an existing person holds is confirmed — "connecting joins them, is that
  you?" — because joining is sometimes exactly right;
- an id a *non-person* scope holds is refused outright, since that one is never
  what the human meant.

Listing the people already present up front turns two of the three into a
non-event: the human sees the collision before typing.

Put the classification helpers in the shared library the setup script already
sources, not in the script itself — otherwise the interactive path stays untestable
and the rules cannot be unit-checked.

## Adapt notes

No invariant: resolution is unchanged, only what the wizard accepts as input. An
instance that names its collections differently reads them from its scopes
registry rather than assuming `people/`·`hosts/`.

Keep the generic-login list short and obviously-role-shaped; it is a prompt for a
human decision, not an authorization check, and every entry is one more name a
real person cannot pick without a confirmation.
