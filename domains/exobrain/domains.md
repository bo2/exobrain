# Domain structure and maintenance

The editor manual for the **domain** entity: directory layout, how to break a domain into sections, the WIP-domain convention, and timeline tracking. For *what* a domain is versus a workspace, see [`entities.md`](entities.md). For *how to write* the prose — horizon test, current-state-only, synthesize-don't-transcribe, order-of-magnitude framing, citations — see [`authoring.md`](authoring.md). This file is the *structure* spec; every effort that builds or maintains a domain reads all three.

## Directory structure

```
domains/<area>/
  README.md        # entry point — frontmatter (name, type, curator, summary), TL;DR, file index
  TIMELINE.md      # optional — append-only change log (see "Timeline tracking")
  <section>/       # one directory per section, when the domain is large enough to need them
    <topic>.md     # one file per topic within the section
  _meta/
    open-questions.md   # unknowns, conflicts between sources
    sources.md          # where non-trivial claims came from
  _raw/            # optional — unsynthesized source captures, kept out of the profile
```

A small domain (under ~10 files) skips section directories and puts topic files at the root beside `README.md`. `_meta/` appears once the domain accumulates open questions or needs a sources index — a one-file domain doesn't need it.

## The README `summary:` and the domains index

Every domain's `README.md` opens with YAML frontmatter — `name`, `type`, `curator`, and a one-line `summary:` (add `timeline: true` to opt into change tracking). The `summary:` states the domain's scope in a sentence — what it covers, kept current — and it is load-bearing: `connect-agent.sh` globs every `domains/*/README.md` and composes a **domains index** (each domain's name, README path, and `summary:`) into every agent's auto-loaded surface, the same way it builds the tools index. That index is how an agent knows which areas of your world exist *before* a task points at one, rather than answering cold — the difference between an agent that knows your world and a stranger.

The index is a pure function of the committed READMEs: generated, never hand-maintained, regenerated on every relink. Domains are root-only and unscoped, so it's a flat catalog — no tiers, overlays, or per-agent filtering. A domain appears as soon as it has a `README.md`; its `summary:` fills the description cell, so keep that to a single line and let the body's TL;DR carry any elaboration. Setting and refreshing `summary:` is part of building and maintaining a domain — the `exobrain-domains` skill does it in every mode.

## Breaking a domain into sections

Sections are subdirectories that group related topic files. They're internal to one domain — distinct from the identity *scopes* in [`scopes.md`](scopes.md). Their purpose is **logical predictability**: "Where would I look for X?" should have an obvious answer.

**When to use them.** Past ~10 topic files, group them into sections; below that, a flat layout is fine. Use sections when they make the tree easier to navigate; skip them when they'd add near-empty directories.

**How to design them.**

1. **Each section is one coherent concern.** Its name should make obvious what's inside without opening the files.
2. **Predictable placement over audience optimization.** The test: *"If I learned a new fact about this domain, would I know which section to put it in without checking?"* Ambiguity means the boundaries are wrong.
3. **Give each section three properties** — what it covers (one line), its editorial voice (reference, runbook, brief, decision log), and its horizon (how fast it changes). These guide what belongs.

Section design is the curator's job — there's no fixed mapping from a domain to a section layout. The examples below are starting points, not templates.

### Example — a sectioned domain (`home`)

```
systems/      — HVAC, plumbing, electrical: what's installed and how it works
maintenance/  — schedules and runbooks (seasonal tasks, filter sizes, shutoffs)
documents/    — warranties, deeds, permits: what exists and where the original lives
vendors/      — the plumber, electrician, contractor: who, and what they did
```

### Example — a flat domain (`vehicle`)

A handful of files, no sections:

```
README.md     — make/model/year, VIN location, the essentials
service.md    — service-history shape and where the records live
documents.md  — registration, insurance, title: what and where
```

## WIP domains

A **WIP domain** (type `wip`) is a domain under active parallel construction — several people building one thing — that will dissolve at delivery, promoting its durable truth into a long-horizon domain. It holds *design and intent*, which keeps it durable: that's what separates it from a **workspace** (a point-in-time record that outdates by design). A WIP domain is kept current while the build runs.

Two conventions set it apart:

- **`.wip` directory suffix.** The directory is `<name>.wip` and the frontmatter `name` matches. The dot sets the suffix apart from in-name hyphens, so a temporary domain is recognizable in the tree and in every link without opening it. It's dropped only by dissolving the domain, never toggled.
- **Design and intent — not live status.** It holds *what and why* you're building: the decisions and the reasoning behind them. Live status (task state, percent-done, who's-on-what) belongs in your tracker, not the domain — it drifts hourly, and mirroring it guarantees staleness, the same failure the "no ephemeral numbers" rule in [`authoring.md`](authoring.md) prevents. Link out to the tracker; keep the durable definition here.

A WIP domain otherwise follows every structure and authoring rule here, and commonly opts into timeline tracking.

## Timeline tracking

A domain with multiple contributors or fast-moving content (WIP domains especially) can opt into the same timeline convention workspaces use: add `timeline: true` to the `README.md` frontmatter. When present, every persist pass that touches the domain appends one row to a `TIMELINE.md` beside the `README.md`:

```markdown
# Timeline

| Date | Author | Summary |
|------|--------|---------|
| 2026-06-11 | oleg | Scaffolded the systems/ section from the June walkthrough |
```

One row per persist pass — a narrative summary of the pass, not a per-edit log. The file is **append-only**: never edit or remove past rows; newest at the bottom. Unlike profile files, `TIMELINE.md` is a change record, not current truth — it's exempt from the current-state-only rule.

## Building a domain

A domain comes together in four moves; a skill can automate them, or you can do them by hand:

1. **Scaffold** — the directory layout, a `README.md` with the file index, and empty topic files (H1 only).
2. **Collect** — gather raw findings from your sources (notes, threads, issues, code), one capture per source, into `_raw/` with citations. No synthesis yet.
3. **Walk the material** — for a system or codebase, trace it end-to-end as a comprehension pass; the trace is scaffolding for understanding, not draft text (see `authoring.md` → "Don't transcribe what the source already holds").
4. **Synthesize** — read the raw captures, fill the topic files per `authoring.md`, populate `_meta/sources.md`, and record gaps and conflicts in `_meta/open-questions.md`.

When the understanding to capture is subtle or contested, drive collection and synthesis as an interview — see [`grill.md`](grill.md).
