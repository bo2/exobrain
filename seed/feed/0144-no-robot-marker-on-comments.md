---
id: 0144
title: Retire the robot-marker rule for comments to a person
date: 2026-09-22
tags: [git, spec]
touches_invariant: false
files: [AGENTS.md, skills/exobrain-repair-findings/SKILL.md]
---

## Problem

`AGENTS.md` § Git workflow required a 🤖 prefix on any forge comment an agent
addresses to a person. That is one workplace's convention, not a property of an
exobrain, and it cost a rule in every session's auto-loaded context.

## Pattern

Drop the marker rule. Commit messages and PR titles and descriptions stay
agent-neutral; a comment to a person carries no required prefix. The repair
skill's source-PR comment loses the prefix with it.

## Adapt notes

An instance whose workplace wants the marker keeps it in a person or group scope,
where it applies to the people it serves.
