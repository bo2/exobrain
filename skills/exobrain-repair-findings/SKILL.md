---
name: exobrain-repair-findings
description: "Clear the authoring-review findings that unattended lands post as a review on merged PRs instead of blocking on. Repairs one PR per session, applying only the fix each finding prescribes, then labels the PR repaired. Use when asked to repair or clear recorded authoring findings, or as the payload of a scheduled repair job."
---

# Repair authoring findings

An unattended land — a chat turn's detached land, or one the sweep finishes — posts the authoring review's findings as a comment review on the PR rather than blocking on them (`exobrain-persist` § Land). This skill is what later acts on those findings.

**One PR per session.** The findings on one PR concern one change; carrying another PR's files and reasoning into the same session invites edits that belong to neither. Never widen a session to a second PR — report what's left and let the next session take it.

## Finding the work

`skills/exobrain-repair-findings/scripts/findings-pending.sh` lists merged PRs carrying unrepaired findings, oldest first, as `<number>\t<title>`. It is the only supported way to enumerate them — the forge is the system of record, and no ledger of repaired PRs lives in the repo.

## Repairing one PR

1. **Read the PR.** `gh pr view <number> --json title,body,files,reviews`. The findings are the review headed "Authoring review (unattended land, not blocking)". The body carries, when the session that made the change wrote one, a "Source context" section: what the person asked for, what that session decided, what it was unsure about. Read that section before touching anything — it is the only record of intent behind the diff, and a finding about a duplicated or misplaced fact is often decided by which file the person meant to own it.
2. **Check each finding against current truth.** Read the named files on the default branch. A finding goes stale: someone may have already fixed it, or later changes may have removed the text it names. Drop the ones that no longer apply and say so; repair only what is still there.
3. **Stop if nothing is left.** Label the PR (step 7) and finish. A repair PR with no change is noise.
4. **Worktree, then fix.** Branch off the current default branch (`AGENTS.md` § Git workflow) and apply what each finding prescribes — the reviewer states the fix, so apply that, not your own broader rewrite.
5. **Change wording and placement, never a fact.** These findings are about where a fact lives and how it reads: one fact written in two files, a summary restating a narrative another file owns. Moving a sentence, cutting a duplicate, and pointing at the file that owns it are all in scope. Changing what a record *claims* — a date, an amount, a measurement, a name — is not, however the finding is worded. If a finding can only be satisfied by altering a claim, leave it, and say why in the repair PR body.
6. **Land in the foreground** — `scripts/persist.sh -m "<message>"`, no `--detach`. This session is attending, so the review blocks and you fix what it says. Give it at most two correction passes; if it still flags something after that, leave the worktree in place (the sweep lands it and records the remainder) and report that in your summary rather than fighting the reviewer.
7. **Label the source PR** `findings-repaired` (`gh pr edit <number> --add-label findings-repaired`, creating the label once with `gh label create`), so the next run doesn't pick it up again. Add a comment naming the repair PR by full URL (`AGENTS.md` § Git workflow).
8. **Report one line**: the PR repaired, how many findings were applied, dropped as stale, or left as out-of-scope.

## Scheduled runs

A host that lands unattended registers a daily job in its `crons.json` whose payload lists the pending PRs and spawns one isolated session per PR, each repairing exactly one. Never ask questions during a scheduled run. When the list is empty, do nothing and return that.
