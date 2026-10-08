---
id: 0171
title: The A/B runner ships the containment stub every live CLI symlinks to
date: 2026-10-08
tags: [ab, security, scripts]
touches_invariant: false
files: [skills/exobrain-ab/scripts/stubs/contained-cli, skills/exobrain-ab/SKILL.md]
---

## Problem

Card 0125 states the rule — a sandbox agent runs with bypassed permissions on
the real `PATH`, so every live CLI it could reach is shadowed — but the seed
shipped only the graded `example-tool` stub, leaving each instance to write
the catch-all itself.

## Pattern

`scripts/stubs/contained-cli`: logs the invocation like any stub (so a
negative task still counts a reach for it), prints an acknowledgement, and
touches nothing. Each live CLI on the machine is a symlink to it, named as the
bare command the agent would type; the skill's setup step says so.
