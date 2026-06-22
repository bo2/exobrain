---
name: exobrain-persist
description: "The default way completed exobrain work lands: worktree → timeline updates → one commit per logical change → push → PR → squash-merge → update the main copy → worktree cleanup. Runs automatically at each completed logical change (standing authorization in AGENTS.md); also invokable by saying 'persist' / 'save' / 'land' / 'ship'."
---

# Persist

Land a completed logical change on the default branch in one shot, through a pull request. This is the **default** flow: `AGENTS.md` § Git workflow grants standing authorization to run it without being asked once a logical change is genuinely done — when more edits or a correction are likely (mid-task, or the user is still iterating), hold and confirm first. The user can also invoke it by name. Follow that git workflow throughout.

1. **Get onto a branch.** Normally you're already in the worktree you started the work in (`AGENTS.md` § Git workflow — worktree-first), so this is a no-op. Recovery only — if work wrongly began in-place on the default branch, move it to a branch first (`git stash -u` → `scripts/create-worktree.sh <branch>` → `cd` into it → `git stash pop`); worktree-first means this shouldn't happen.
2. **Update timelines.** For each workspace or domain touched by this persist, check its `README.md` frontmatter for `timeline: true`. If present, diff the folder against the default branch, summarize the changes in one line, and append a row (`| date | author | summary |`) to the `TIMELINE.md` beside that `README.md` — creating it with a header row if absent. See [`domains/exobrain/domains.md`](../../domains/exobrain/domains.md) → "Timeline tracking".
3. **Commit** — one commit per logical change, imperative mood.
4. **Behaviorally verify shared-machinery changes.** When this change touches machinery that shapes how other agents behave — `scripts/`, the registries (`skills.json` / `scopes.json` / `skills.schema.json`), any skill, or a global-scope spec (`AGENTS.md` and the per-agent sidecars) — verify it before it lands; pure docs (`domains/`, `tools/`, `workspaces/`) and personal person/host-scope changes are exempt (skip to the authoring review). Run the behavioral suite (the `exobrain-tests` skill) over the cases this change could move — it snapshots HEAD, so the commit in step 3 is what gets tested. Fix any case below threshold, `git commit --amend` the unpushed commit, then re-run. For a change *meant to alter behavior* (a reworded rule, a new or edited skill), also run `exobrain-ab` to confirm it actually moves behavior — a spec edit that changes nothing isn't worth landing. You judge which cases are relevant and whether the change is behavior-altering: this gate is agent-run, not a script check.
5. **Authoring review** — run `scripts/authoring-review.sh`, the LLM judgment layer over the spec/domain `.md` files this change touched. It self-skips when none changed and degrades open when no agent CLI is installed, so running it unconditionally is cheap. If it flags violations, fix them and amend the still-unpushed commit before pushing; if it passes or degrades open, continue. (Skippable with `EXOBRAIN_SKIP_AUTHORING_REVIEW=1`.)
6. **Push** the branch to the remote.
7. **Open a PR** — repo template if present, else free-form: what changed and why.
8. **Squash-merge** the PR — `gh pr merge --squash` (no `--delete-branch`: from a worktree it fails trying to check out the default branch the main checkout already holds; delete the branch by hand in step 10).
9. **Update the main copy** — return to the main checkout and `git pull` so the local default branch reflects the squash-merge.
10. **Clean up the worktree and branch** — `git worktree remove <path>`, then delete the merged branch by hand: `git branch -D <branch>` and `git push origin --delete <branch>`.
11. **Continuing the same work?** Create a fresh worktree off the updated default branch before further edits. Ask if the intent isn't clear.

If you're already in a worktree, skip step 1 and start from the timeline update.

**No remote or no review** (a purely local instance): collapse steps 6–9 into a fast-forward merge of the branch into the local default branch.
