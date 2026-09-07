---
id: 0124
title: A sandbox is its own repo before the diff is applied, and identical arms refuse to run
date: 2026-09-07
tags: [exobrain-ab, eval, scripts, portability]
touches_invariant: false
files: [skills/exobrain-ab/scripts/run.sh, skills/exobrain-ab/scripts/run_one.sh, skills/exobrain-ab/SKILL.md]
---

## Problem

`exobrain-ab` builds each arm by extracting trunk into a directory under the
checkout's gitignored `tmp/`, applying the treatment diff there, wiring it, and
only then running `git init` so the agent sees a clean tree. Until that `git
init`, the sandbox is a subdirectory of the enclosing checkout — and `git apply`
run from a subdirectory of a repo treats the diff's paths (`AGENTS.md`,
`skills/…`) as lying outside the current directory, skips every one of them, and
exits 0. The build reported success; the treatment arm was trunk. Every A/B run
was an A/A, and a "no behavioral delta" verdict was the only verdict the harness
could reach.

Nothing downstream could see it: a treatment arm that equals control is a
legitimate mode (the noise-floor run), so equal results read as "the change does
nothing" rather than "the change was never applied". Two smaller faults sat
beside it: each run was bounded with `timeout`, which macOS does not ship, so the
run failed outright on a stock machine; and the prose still called the wiring
step "render" after the flag became `--wire-sandbox` (card 0118).

## Pattern

**Make the sandbox its own repository before anything touches its contents**, so
every later git command — the apply, the wiring's own checks, the init commit —
resolves paths against the sandbox and not the checkout it happens to sit under.

**Refuse to measure an A/A that was not asked for.** After both arms are built,
compare their trees; when a diff was supplied and the trees match, exit with an
error naming the diff. The harness then forces the report the author would
otherwise have to remember to make (`harness-engineering/failure-modes.md` §
Silent coverage loss). The deliberate noise-floor run — no diff given — is
unaffected.

**Bound runs with what the machine has.** Use `timeout` or `gtimeout` when one
exists; without either, run unbounded rather than fail — the behavior suite makes
the same choice.

## Reference (illustration only)

```bash
git -C "$REPO" archive "$BASE_REF" | tar -x -C "$d"
( cd "$d" && git init -q && git config user.email e@e.co && git config user.name e )
[ "$arm" = treatment ] && [ -n "$DIFF" ] && ( cd "$d" && git apply "$DIFF" )
…
if [ -n "$DIFF" ] && [ "$(git -C control rev-parse 'HEAD^{tree}')" = "$(git -C treatment rev-parse 'HEAD^{tree}')" ]; then
  echo "ERROR: control and treatment sandboxes are identical" >&2; exit 1
fi
```

## Adapt notes

- Reproduce before fixing: extract trunk under `tmp/`, `git apply` a real
  `git diff` there, and grep for the change — it reports "Skipped patch" only
  with `-v`. A hand-written patch without the `diff --git` header applies, which
  is why a quick check can miss it.
- Any past verdict from this harness that read "no delta" is unmeasured, not
  negative. Re-run the ones that decided something.
- The tree comparison assumes the wiring step is deterministic across arms; a
  wiring that stamps a timestamp or the sandbox's absolute path into a generated
  file will never match, and needs that file excluded from the comparison.
