---
id: 0076
title: instance-tests — real-environment onboarding e2e as a portable skill
date: 2026-07-12
tags: [tests, connector, docker]
touches_invariant: false
files: [skills/instance-tests]
---

## Problem

The behavioral suite is hermetic by design — no network, no credentials — so
nothing verifies the *real* onboarding path: can a genuinely fresh machine
clone this instance's origin, run the connector, and come up healthy? Connector
and onboarding-doc regressions surface only when a human hits them on a new
machine.

## Pattern

A sibling suite that trades hermeticity for realism, kept out of the hermetic
one so each keeps its contract. `instance-tests` stands up a fresh-OS Docker
container and exercises the actual flow, in two modes per case:

- **probe** (deterministic, no credentials): clone the instance's real origin,
  overlay the local checkout's connector (test your changes, not trunk),
  self-seed synthetic scope fixtures, and assert every connect-cascade branch —
  connected scopes, recorded person, zero scaffolded folders — then healthcheck
  and validator on the connected clone.
- **agent** (full e2e, needs a headless token): a no-context headless agent
  follows the onboarding prompt — verbatim first turn, then consent-only
  continuation rounds — and the harness asserts the goal state deterministically.

Per-case `requirements` in `meta.json` (docker, an https-reachable origin, an
oauth token for agent mode); the runner skips — not fails — cases a machine
can't satisfy. The suite ships to every instance, so any instance can self-test
its own onboarding; token extraction copies the single `.env` var by redirect
and never prints it.

## Adapt notes

- A private https origin needs read credentials the container can use; mount
  them read-only in the case's `run.sh` — never bake secrets into an image
  layer.
- An instance whose README carries a real onboarding prompt should extract and
  use that in agent mode instead of the case's default prompt — the real doc is
  the surface worth testing.
- The probe's expected cascade outcomes encode the connector's no-scaffold flag
  semantics (card 0075); if your instance diverged, update the expectations,
  not the assertion machinery.
