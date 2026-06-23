---
id: 0058
title: Generate an auto-loaded domains index from each domain README's summary
date: 2026-06-23
tags: [domains, connector, index, context]
touches_invariant: false
files: [scripts/connect-agent.sh, scripts/skills-registry.sh, domains/exobrain/domains.md, domains/exobrain/machinery.md, skills/exobrain-domains/SKILL.md, skills/exobrain-domains/create.md]
---

## Problem

Skills and tools each get an auto-loaded index so an agent knows what's available before a task needs it. Domains — the durable knowledge areas, the whole point of the exobrain — had no such surface. An agent only discovered a domain existed if a task happened to point at `domains/`, so it would answer a health or finances question from generic knowledge instead of consulting the recorded truth. That's the exact failure the project exists to prevent: acting like a stranger rather than someone who knows your world.

## Pattern

Compose a **domains index** into every agent's auto-loaded context, the same mechanism as the tools index. Each domain `README.md` carries a one-line `summary:` in its frontmatter (alongside `name`/`type`/`curator`); the connector globs `domains/*/README.md` and emits a flat catalog of name + README path + summary. It's a pure function of the committed READMEs — generated, never hand-maintained, regenerated on every relink.

Domains are root-only and unscoped, so the index needs no scope-chain resolution, tiers, overlays, or per-agent filtering (the part that makes the skills/tools indexes complex) — a flat glob suffices. The value is up-front awareness: the agent knows which areas of your world it can draw on, and reads the relevant README before reasoning, instead of cold.

Make the domain-authoring skill own the `summary:` — write it on create/distill, refresh it on curate/update whenever a pass changes what the domain covers — so the index never goes stale.

## Reference (illustration only)

A small frontmatter extractor (the leading `--- … ---` block, one key) plus a flat resolver beside the tools resolver:

```bash
domains_resolve() {            # root-only, unscoped: a flat glob, no scope chain
  for d in "$1"/domains/*/; do
    readme="${d%/}/README.md"; [[ -f "$readme" ]] || continue
    name="$(frontmatter_field "$readme" name)"; [[ -n "$name" ]] || name="$(basename "${d%/}")"
    printf '%s\t%s\n' "$name" "${readme#"$1"/}"
  done | sort
}
```

The connector writes `domains-index.md` (skipping cleanly when there is no `domains/`), then composes it into each agent's surface exactly where it composes the tools index — a `@`-import for Claude, an inlined marker block for Codex/OpenClaw.

## Adapt notes

Additive, no invariant touched. Mirror wherever your connector already builds the tools index — the resolver, the generated-file write, and both composition sites (import + inline). If you renamed the durable-content dir (`knowledge/`, `areas/`, …), point the glob there. The new contract is one `summary:` line per domain README; backfill existing domains' frontmatter and make your domain skill set/refresh it so the catalog stays a true function of the docs. No validator rule is required — keeping `summary:` current is a skill-enforced and authoring-review concern, not a deterministic gate.
