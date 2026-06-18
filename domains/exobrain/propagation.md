# Propagation

How exobrains share improvements **without** a fork-and-merge relationship.

Three words, kept distinct: **propagation** is the whole exchange between seed and instances; **adoption** (verb *adopt*) is the seed→instance direction — an instance taking in the seed's changes, run via the `exobrain-evolve` skill; **publishing** is the reverse — an instance contributing a pattern back as a feed card. The wiring-refresh op (`connect-agent.sh --relink`) is a separate concern and is deliberately not called "update", so the two never collide.

The template era assumed a human running `git merge upstream` against a fork. That breaks the moment two exobrains diverge — different durable-content dir names, with/without groups, restructured scripts. The agentic era assumes something the template era couldn't: **a competent adapter sits at every node.** So an exobrain has no upstream remote and never merges. Instead, an agent reads the seed's **feed**, **copies** the files an instance hasn't diverged, and **re-synthesizes** the rest into local names and structure.

## The model: read target, not merge source

The canonical exobrain (`github.com/bo2/exobrain`) is a **read target + a generator**, not a fork parent. It is itself an exobrain — its `domains/exobrain/` meta-domain *is* the concept. Downstream exobrains:

- **Are independent.** Each owns its own tree. No upstream remote, no merge, no conflicts — `exobrain-evolve` caches the seed in a gitignored `src/exobrain-seed/` (pull if present, else clone) and reads it from there. A local cache, not a tracked remote: nothing to merge, nothing that pulls framework code in automatically.
- **May diverge freely.** Different names, layout, scripts. Where an instance diverged, changes re-synthesize; where it didn't, they copy cleanly.
- **Take improvements, adapting as needed.** Framework files an instance never touched can be copied directly; anything it changed locally is reconciled from the pattern.

This is a deliberate hybrid: **copy** is exact and cheap for the framework code (which arrived as a copy in the first place); **re-synthesis** crosses structural divergence that a line-level merge can't.

## The feed is the changelog

Every change worth propagating is **published** as a dated **pattern-card** under `domains/exobrain/feed/` — a problem, a pattern, optionally the files it touches, and adapt notes. The feed is the changelog an instance reads to adopt. Format + ledger: [`feed/README.md`](feed/README.md). Each card carries a stable ID so provenance survives even across divergence.

## The adoption workflow

The `exobrain-evolve` skill is the single way an instance moves forward — there is no `git pull` of framework code:

1. **Fetch** the seed into `src/exobrain-seed/` (pull if the cache exists, else clone) from the seed URL recorded in the adoption-ledger header — not a tracked remote.
2. **Diff** the feed's card IDs against this instance's adoption ledger; the unadopted cards are the changes since last adoption.
3. **Triage** — permissive by default; the human can veto a card that doesn't fit this setup.
4. **Apply each card** — *copy* the seed's files where this instance is undiverged; *re-synthesize* where it diverged or where structure differs. Preserve invariants exactly.
5. **Validate** and re-link.
6. **Record** the adopted card IDs in the ledger.

## Invariants — adapt around, never reinterpret

A few things tolerate no drift. These are **invariants**: preserved *semantically exactly*, even while names and structure change around them.

- **Security** — the credential-handling rules in `AGENTS.md` § Security. Never weakened by an adaptation.
- **Scope-resolution semantics** — the chain resolves shallow→deep with the deepest scope winning. Names and shape may change; the resolution contract may not.
- **The validation contract** — what `validate-exobrain.sh` guarantees about naming, JSON integrity, and registry consistency. An adaptation may extend it; it must not silently drop a check.

A card that touches an invariant flags it (`touches_invariant: true`). If applying it would alter an invariant's meaning, stop and surface it to the human rather than reinterpreting.

## Provenance hygiene — keep shared scopes generic

The seed and its feed are public; downstream instances are mostly private. When a change is backported up into the seed, the feed, or any shared scope, **re-synthesize it free of the source instance's identity** — strip org or company names, internal hostnames, ticket prefixes, usernames, and private repo or tool names. A card describes the *pattern*, never where it came from. This is a hard publishing rule: a card or shared-scope file that names a downstream's specifics has leaked private provenance, and must be genericized before it lands.

## Instantiating a new exobrain

When an agent builds a fresh exobrain by reading this concept (`create-instance`):

1. Read this meta-domain. It describes *principles*, not a rigid layout.
2. Choose names and structure that fit the principal — durable-content dir name, whether groups exist, which scopes are populated. Divergence is expected.
3. Preserve the **invariants** above. Carry the framework scripts, adapting them to your structure.
4. Seed the minimum: `AGENTS.md`, a `domains/exobrain/` meta-domain, one person scope, an empty `workspaces/`, and the `exobrain-evolve` skill.
5. Seed the adoption ledger with the cards the seed currently publishes — you built from them — so `exobrain-evolve` carries you forward from there.

The proof of the model is that the exobrain you're reading this in was built exactly this way.
