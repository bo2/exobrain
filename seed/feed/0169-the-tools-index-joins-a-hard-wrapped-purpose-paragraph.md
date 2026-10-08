---
id: 0169
title: The tools index joins a hard-wrapped purpose paragraph
date: 2026-10-08
tags: [tools, connector]
touches_invariant: false
files: [scripts/skills-registry.sh, skills/exobrain-tests/unit/test-connect-agent.sh]
---

## Problem

The tools index took a tool doc's first non-heading content line as its
purpose. A doc whose opening paragraph is hard-wrapped at 80 columns put only
its first physical line in the index, so the agent read a sentence cut mid-way.

## Pattern

The summary is the whole opening paragraph — every line up to the first blank
line or heading, joined with single spaces — mirroring how a folded skill
description is flattened for the optional-skills index.
