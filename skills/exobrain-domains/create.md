# Domain — create mode

Build a new domain from scratch: a broad sweep of your sources plus a code walk. Use when no domain exists yet and the knowledge is scattered across sources and code (no pre-collected corpus — for that, use [`distill`](distill.md)).

Arguments: `<name>` (folder name, lowercase-hyphenated, under `domains/`) and `<type>` (the domain's kind — `system`, `process`, `expertise`/`reference`, `product`/`project`, or another type that fits; see existing `domains/*/README.md` for the vocabulary in use). For a parallel-build WIP domain, use [`distill --wip`](distill.md) instead — those are grilled into existence at a definition altitude, not built from source search.

The [shared foundation](SKILL.md) (worktree, `authoring.md`, bookkeeping, landing) applies. This file adds the create-specific phases.

## Phase 1 — Scope definition

Gather enough context to define boundaries before scaffolding — this prevents creating files you can't fill and missing files you need.

1. Establish (ask the curator or infer from context): the one-sentence TL;DR; which repos or systems implement it; what's in/out of scope (especially which adjacent domains exist and where the boundaries are); who curates it.
2. Read [`domains/exobrain/domains.md`](../../domains/exobrain/domains.md) (layout, section design), [`domains/exobrain/authoring.md`](../../domains/exobrain/authoring.md) (editorial rules), and existing `domains/*/README.md` (overlap, cross-references).
3. **Design sections** (domains.md "Breaking a domain into sections"): list the distinct concerns; for each, define what it covers, its editorial voice, its refresh horizon. Under ~10 files → flat layout, no section dirs. Predictability test: "if I learned a new fact, would I know which file it goes in without checking?" `_meta/` appears once the domain accumulates open questions or a sources index.

## Phase 2 — Scaffold

Create the directory and all files:

1. **`README.md`** — frontmatter (`name`, `type`, `curator`, `summary`), TL;DR, status line (`Status: draft | Last synthesis: YYYY-MM-DD`), scope (in/out), and a file index linking every file with a one-line concern. The `summary:` is the one-sentence scope from Phase 1 — it feeds the auto-loaded domains index, so write it now. Opt into `timeline: true` for multi-contributor or fast-moving domains.
2. **`sources.json`** — search config for `update` mode (schema in [`update.md`](update.md)). Populate from the repos, tools, and channels found in Phase 1 — each source naming a tool registered in [`tools/`](../../tools/).
3. **Profile files** — one per topic, each opening with its H1 only (`# <Domain> — <File Title>`). No checklist, no FAQ scaffolding. Filled in Phase 4.
4. **`_meta/open-questions.md`** and **`_meta/sources.md`** — empty templates.
5. **`_raw/`** — empty (add `.gitkeep`).

Commit the scaffold: `Scaffold <name> domain (<type>)`.

## Phase 3 — Collection

Breadth first — capture everything, filter later. Use parallel sub-agents per source. **Wider time window than a refresh** (12+ months).

- **Source sweep** — for each source in `sources.json`, collect into `_raw/collection-YYYY-MM-DD.md`. Same procedures as [`update.md`](update.md) (GitHub PRs via `gh`; other tools via their read/search interface, per each tool's doc under `tools/`), but a wider window and more aggressive keywords; capture architectural context, not just recent change.
- **Code walk** — what a refresh doesn't do. Trace the product/system flow end-to-end through the real code (clone into `src/<repo>/` per `AGENTS.md` if it isn't already there): entry points → each layer → data stores → external services. Document in `_raw/code-walk-YYYY-MM-DD.md` (boundaries, data flow, key abstractions, config/flags, integrations). The code walk is a **comprehension artifact**, not source text to transcribe into the technical files — see authoring.md "Don't transcribe what the source already holds".
- **Existing docs** — repo `AGENTS.md`/`README.md`, any reference docs for the area, existing exobrain files that reference it.

## Phase 4 — Synthesis

Read all `_raw/` output and fill the profile files, applying every rule in [`domains/exobrain/authoring.md`](../../domains/exobrain/authoring.md). Suggested order (each builds on the last): the technical/reference section (reframe the code walk — apply "don't transcribe what the source already holds" strictly here), then the product, business, and operations sections (or whatever sections this domain defined), then compile `_meta/sources.md` and `_meta/open-questions.md`. Set `Last synthesis: YYYY-MM-DD` in the README.

## Quality checklist

- README scope boundaries clear, no overlap with existing domains (use "Out of scope → see `../other/`")
- `sources.json` covers all relevant repos, tools, and channels
- Profile files open with their H1 only; no point-in-time metrics (horizon test)
- No file:line citations, code transcriptions, enum listings, or function walks in the technical/reference files (authoring.md "Don't transcribe what the source already holds")
- Source citations on every non-obvious claim; cross-references to adjacent domains; gaps captured honestly in open-questions

## Edge cases

- **Overlaps an existing domain** — define clear boundaries in both READMEs; reference, don't duplicate.
- **Shared infrastructure** — reference the shared system's domain; document only the domain-specific surface.
- **Sparse sources** — lean on the code walk and existing docs; flag gaps in open-questions.
- **Very large** (>~100 findings) — synthesize in sub-agent batches by section.
