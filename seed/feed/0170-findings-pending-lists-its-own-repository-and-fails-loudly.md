---
id: 0170
title: findings-pending.sh lists its own repository and fails loudly
date: 2026-10-08
tags: [persist, repair, scripts]
touches_invariant: false
files: [skills/exobrain-repair-findings/scripts/findings-pending.sh, skills/exobrain-repair-findings/tests/test-findings-pending.sh]
---

## Problem

`gh pr list` resolves the repository from the working directory, so a
scheduled caller running the repair detector from elsewhere listed another
repository — or all of the forge. A failed listing printed nothing and exited
0, which reads exactly like "nothing pending".

## Pattern

The script changes to the repository it lives in before listing, exits 1 with a
message when the listing fails, and reads the 200 most recently merged
unlabelled PRs so a repair pass that missed several days of lands still finds
what they recorded. The harness's fake `gh` records its arguments and can be
told to fail.
