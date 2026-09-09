---
title: Knowledge and workspaces
description: The split between what you know and what you're doing — and why keeping them apart is what stops an agent going stale.
---

An exobrain holds two kinds of content, and keeping them separate is most of what makes it work.

## Knowledge — what you know

Durable areas: how a system is set up, which conventions hold, what a project's facts are, what you decided.

Knowledge **holds current truth and is kept current.** When a fact changes, you change it in place. There's no changelog, no "as of March" — the file says what is true now.

Each area has a `README.md` as its entry point, carrying a one-line summary. Those summaries are indexed and loaded every session, so the agent knows *which* areas exist without loading their contents. It reads the area itself only when the work touches it. Knowing what you know is cheap; knowing it all at once is not.

## Workspaces — what you're doing

Time-bound efforts: an investigation, a migration, a spike, a piece of analysis.

Workspaces are **point-in-time records, and they outdate by design.** That's not a flaw to manage, it's the entire purpose. A workspace is allowed to say something that stopped being true, because it's a record of a moment.

Keeping scratch work in a workspace also means it's somewhere — the queries, the intermediate output, the half-finished script. The alternative is scattering it across your temp directory and rewriting it in six weeks.

## Why the split matters

Because **drift is what kills an agent's knowledge base**, and the split is what contains it.

A prose wiki that mixes both degrades in a specific way: pages accumulate history, nothing forces them current, and the agent confidently reports last year's architecture with no way to know it's wrong. Every page is equally suspect.

With the split, staleness has somewhere harmless to live. Workspaces are *expected* to be out of date and are read as historical. Knowledge areas carry one obligation — be true now — and that's a small enough promise to actually keep.

## Promotion

When something durable falls out of time-bound work — the investigation concluded, and *this is how it works now* — it gets **promoted** into a knowledge area. Not linked: written there.

That last part is a rule worth keeping. **Nothing that must stay current should cite a workspace.** A link from a knowledge area into a workspace looks like a citation and behaves like a trapdoor: the workspace ages, the knowledge area still points at it, and nothing announces that the reference went stale. Copy the durable conclusion up; leave the story behind.
