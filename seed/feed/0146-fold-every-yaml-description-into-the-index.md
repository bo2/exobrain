---
id: 0146
title: Fold every YAML description form into the optional-skills index
date: 2026-09-22
tags: [skills, scripts, index]
touches_invariant: false
files: [scripts/skills-registry.sh, skills/exobrain-tests/unit/test-connect-agent.sh]
---

## Problem

`skills_extract_description` (card 0136) folded a block-scalar `description` but
treated any `---` line as the frontmatter fence, so a file with no frontmatter
served a `description:` from its body; rendered an indentation indicator (`>2`)
as the bare `>2`; and missed `description :` spacing. Each form left the index
row — the only thing telling an agent what an un-loaded skill does — blank or
wrong.

## Pattern

Parse the frontmatter as YAML front matter: it opens on line 1, closes at the next
fence, and a block scalar (`>` or `|`, any chomping or indentation indicator)
consumes indented and blank lines until an unindented line or the fence, then
space-joins them. Quoted single-line values lose their quotes. A harness covers
each form and checks a folded description reaches the generated index.
