---
name: exobrain-persist
description: "The default way completed exobrain work lands: worktree → timeline updates → one commit per logical change → push → PR → squash-merge → update the main copy → worktree cleanup. Runs automatically at each completed logical change (standing authorization in AGENTS.md); also invokable by saying 'persist' / 'save' / 'land' / 'ship'."
---

# Persist

Land a completed logical change on the default branch in one shot, through a pull request. This is the **default** flow: `AGENTS.md` § Git workflow grants standing authorization to run it without being asked whenever a logical change is done; the user can also invoke it by name. Follow that git workflow throughout.

1. **Get onto a branch.** Normally you're already in the worktree you started the work in (`AGENTS.md` § Git workflow — worktree-first), so this is a no-op. Recovery only — if work wrongly began in-place on the default branch, move it to a branch first (`git stash -u` → `scripts/create-worktree.sh <branch>` → `cd` into it → `git stash pop`); worktree-first means this shouldn't happen.
2. **Update timelines.** For each workspace or domain touched by this persist, check its `README.md` frontmatter for `timeline: true`. If present, diff the folder against the default branch, summarize the changes in one line, and append a row (`| date | author | summary |`) to the `TIMELINE.md` beside that `README.md` — creating it with a header row if absent. See [`domains/exobrain/domains.md`](../../domains/exobrain/domains.md) → "Timeline tracking".
3. **Publish framework patterns to the feed.** If this persist improves the **shared framework** — the machinery in `scripts/`, the framework meta-docs in `domains/exobrain/`, or the framework skills in `skills/` — with a **durable pattern another exobrain instance (personal, family, company) could adopt**, add one pattern-card *per pattern* under `domains/exobrain/feed/` (next never-reused `NNNN`), per [`feed/README.md`](../../domains/exobrain/feed/README.md), committed in this PR. Skip for instance-specific content (a domain, a workspace, a person/group/host scope, a tool doc tied to one setup) and when nothing generalizes — a PR may warrant zero, one, or several cards.
4. **Commit** — one commit per logical change, imperative mood.
5. **Push** the branch to the remote.
6. **Open a PR** — repo template if present, else free-form: what changed and why.
7. **Squash-merge** the PR — `gh pr merge --squash` (no `--delete-branch`: from a worktree it fails trying to check out the default branch the main checkout already holds; delete the branch by hand in step 9).
8. **Update the main copy** — return to the main checkout and `git pull` so the local default branch reflects the squash-merge.
9. **Clean up the worktree and branch** — `git worktree remove <path>`, then delete the merged branch by hand: `git branch -D <branch>` and `git push origin --delete <branch>`.
10. **Continuing the same work?** Create a fresh worktree off the updated default branch before further edits. Ask if the intent isn't clear.

If you're already in a worktree, skip step 1 and start from the timeline update.

**No remote or no review** (a purely local instance): collapse steps 5–8 into a fast-forward merge of the branch into the local default branch.
