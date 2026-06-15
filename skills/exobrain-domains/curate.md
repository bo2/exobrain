# Domain — curate mode

An interactive session that keeps a domain true: incorporate what's new, settle what's open, ask only what can't be settled. The human is present — that's the design assumption. For unattended refreshes use [`update`](update.md); for corpus-scale distillation with a full alignment pass use [`distill`](distill.md).

Two entry shapes, one flow:
- **With input** — a doc, transcript, chat thread, meeting notes, a decision: incorporate it.
- **Without input** — work the domain's open-questions backlog: resolve what targeted lookups answer, bring the rest to the human.

Arguments: `<domain>` and optionally `<input>` (file path, URL, pasted text, or pointer). Omit `<input>` to run an open-questions session.

The [shared foundation](SKILL.md) applies. Triage and challenge run the discipline in [`domains/exobrain/grill.md`](../../domains/exobrain/grill.md), scoped to a session — this file adds the session flow.

## 1. Ingest (with input)

Land the source in `_raw/` first — files keep their **original filename** (source traceability); non-file inputs (threads, pasted text, links) are fetched and captured to `_raw/curate-YYYY-MM-DD-<slug>.md` with link, author, date. **Dedupe before anything else** — check `_raw/` for the same document by content, not name. Byte-identical and already incorporated → report and stop, no PR. A revision of an existing doc → ingest alongside and incorporate only the delta.

## 2. Map (with input)

List which profile files the input touches — one input usually fans out to several (a release-date change can touch the README, a release file, and a stream's status). Route each fact to the file the README's index assigns to that concern. In WIP domains, per-stream content routes to `streams/<stream>/`, respecting each stream's Decided / Suggestions / open-questions split.

## 3. Build the item list

- **With input:** each fact that conflicts with existing text, is ambiguous, or lands outside any file's concern — plus any open-questions items the input answers or touches.
- **Without input:** the open-questions backlog. If it's larger than a session, ask the user to scope it (a section, the items blocking something, top N) rather than grinding through unprompted.

## 4. Triage and resolve

Classify every item (the `grill.md` triage):
- **Discoverable** — answerable by a **targeted lookup** scoped to the item (the cited source, the code, a search of the specific channel/issue/thread in the tool that holds it). Look it up, cite it in the domain's style, close it. Targeted means scoped to the item — "what happened recently everywhere" is `update`'s job, not this.
- **Conventional / low-risk** — covered by a convention or a reversible default. Decide, batch into a numbered veto list.
- **Human judgment** — taste, history, product intent, risk, a genuine trade-off. Ask one question at a time per `grill.md` (evidence, recommended answer, what changes if different). When a lookup contradicts the human's answer, challenge once, substantively; a contested claim enters attributed ("per <curator>, despite X"), never as plain fact.

## 5. Write

Synthesize into each target file in that file's existing style — read before writing. **Supersede, don't accumulate** — update text in place (domains hold current truth); if the domain keeps history files, move the replaced state there. **Never resolve a conflict silently** — record which source is now canonical and why in `sources.md`; materially unresolved tension goes to open-questions, attributed. Cite the input or lookup on every claim it backs.

## 6. Consistency pass

The fact you changed may be restated — or contradicted — elsewhere. Grep the domain for the terms the session touched; update every file that restates a changed fact, or collapse the duplication into one canonical location and cross-link (authoring.md "Don't duplicate drift-prone facts"). Don't leave the domain internally disagreeing.

## 7. Record and land

Close answered open-questions (with answer + citation); add new gaps under `## Flagged YYYY-MM-DD`; update `sources.md`; append one `TIMELINE.md` row for the whole session if `timeline: true`. Leave any `Last synthesis:` marker untouched — it tracks sweep coverage. Persist (shared foundation), the PR body naming items resolved (by lookup / by convention / by the human) and the conflicts found.

## Edge cases

- **Input already incorporated** — report where it landed and stop, no PR.
- **Input contradicts the domain on nearly every point** — stop and surface it; the input may belong to a different domain, or the domain may need a full re-synthesis ([`create`](create.md) / [`distill`](distill.md)), not a curate session.
- **User unavailable mid-session** — park unresolved human-judgment items in open-questions (attributed, with evidence gathered so far) and deliver the rest; don't block the PR on an absent human.
