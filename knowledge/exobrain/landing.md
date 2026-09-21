# How a change lands

Every exobrain change reaches the default branch the same way: a branch in its own worktree, one pull request, a squash-merge. `scripts/persist.sh` runs that path end to end, and the `exobrain-persist` skill tells an agent when to call it and in which form. This page is what the person on the other end sees, and how to check on a land.

## Two ways to land

| | Attended | Detached |
|---|---|---|
| Used by | A terminal session or a scheduled job | A chat turn (the reply goes to a chat channel) |
| Command | `scripts/persist.sh` | `scripts/persist.sh --detach` |
| The agent replies | After the merge, naming the PR | Right after the commit, naming no PR |
| Authoring-review findings | Block the land until fixed | Go into the PR body; the land carries on |
| A step that fails | Stops the land; the session fixes it and re-runs | Retried by the sweep |

Push, review, PR and merge take minutes, so a chat reply doesn't wait for them. When the agent says it saved something, the change is committed on its branch and reaches the default branch a few minutes later. Until then, only the turn that made the change can read it back, so a follow-up question asked in that gap can miss it.

## After a detached reply

1. The script commits, then hands the rest to a background process that logs to `.git/persist-logs/<branch>.log` in the main checkout.
2. That process runs the same steps as an attended land (`exobrain-persist` step 4).
3. The validator and the new-shared-skill proof gate block as usual. A land they stop, or that dies or hits a conflict, stays claimed on its branch, and the next sweep retries it.
4. The authoring review does not block. Its findings go into the PR under **Authoring review (unattended land, not blocking)**, and the PR merges anyway, so the flagged text sits on the default branch until it is repaired.

## The sweep

`scripts/persist.sh --sweep`, a scheduled job on the host that runs the chat agent, lands whatever a land left behind: a claimed land that stopped, or a committed branch nobody landed. It never lands uncommitted edits, or a shared-machinery change whose claim carries no `--machinery-verified` assertion — that one waits for an agent's behavioral verification. It reports those as stale once they have waited too long, and the report fails the job and sends its alert. The exact rules are in `exobrain-persist` § Landing later.

## Who fixes the findings

A scheduled job on that host runs the `exobrain-repair-findings` skill: one agent session for each PR with unrepaired findings. The session fixes wording and placement, never a recorded fact, lands any repair as its own PR, and labels the source PR `findings-repaired`. The skill has the full procedure.

## Checking on a land

| Question | Where to look |
|---|---|
| Did a chat change land? | The forge's PR list, or `.git/persist-logs/<branch>.log` in the host's main checkout |
| Is a change stuck? | `git worktree list` in the main checkout; the sweep's alert names stale ones |
| Which findings are waiting for repair? | `skills/exobrain-repair-findings/scripts/findings-pending.sh` |
| What has been repaired? | `gh pr list --state merged --label findings-repaired` |
| When do the sweep and the repair run? | Their entries in the `crons.json` of the host that runs the chat agent |
| Did they run? | The scheduler's run history on that host (`openclaw cron runs` under OpenClaw) |
