---
title: Staying current
description: How an exobrain takes in improvements without ever merging from anyone — and why that means adopting one creates no dependency.
---

This is the part that surprises people, and it's the reason adopting an exobrain doesn't tie you to this project.

## You don't fork, and you never merge

Your exobrain has **no upstream remote.** There is no fork relationship, no merge, no conflicts, and nothing that pulls changes into your tree automatically.

That's not neglect — it's the design. The template model, where you fork a starter repo and periodically merge from it, breaks the moment two instances diverge. And divergence is the *expected* case here: you renamed things, restructured, rewrote a script, dropped a concept you don't use. A line-level merge can't cross that gap.

## Re-synthesis instead

What the template era couldn't assume, and this one can, is that **a competent adapter sits at every node** — your agent.

So improvements propagate as *patterns re-synthesized locally*, not as merged code. This repository publishes each change as a dated card describing the problem and the pattern. Your agent reads those cards, **copies** files you haven't diverged from, and **re-synthesizes** the rest into your names and your structure. Then it records which cards you've taken, so it knows where to resume.

When you want to update, you ask your agent to do it, and it adapts each change to the exobrain you actually have. When you don't want to update, nothing happens.

## Why this means no dependency

Worth being direct about, because it's the usual worry:

**Your instance is yours outright.** It's your repository, your files, your history. Nothing in it phones home, requires an account, or checks a licence. It is markdown and shell scripts on your disk.

**Updates are opt-in and adaptive.** You pull improvements when you want them, and you can decline any single change. There's no version to keep up with and no breakage from skipping a year.

**If this project stopped today, nothing of yours breaks.** You'd stop receiving new patterns. Your exobrain would keep working exactly as it does now, because it doesn't execute anything from here — the scripts were copied into your repo at setup and are yours to edit.

**The exit is that there's nothing to exit.** No migration, no export. Your knowledge is already markdown in a git repository you own. Worst case, you keep the files and ignore where they came from.

MIT licensed, in both directions.

## Contributing back

If you solve something general, the pattern can come back the same way — described generically, free of your specifics, so others adopt it without inheriting anything of yours.

That direction has a strict rule attached: a shared pattern is stripped of its origin. No organisation names, no internal hostnames, no private repository names, no usernames. **A change that can't be described without naming where it came from was never shareable** — so contributing back can't leak your context by accident.
