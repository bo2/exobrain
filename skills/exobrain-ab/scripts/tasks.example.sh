#!/usr/bin/env bash
# Example task set for exobrain-ab. Sourced by run.sh; must define TASKS=().
# Copy and adapt for your own change — replace the prompts, regexes, and stub name with
# ones that discriminate the tool/command your change is meant to surface.
#
# FORMAT — one pipe-delimited entry per task (no field may contain '|'):
#   id | set | grade | correct_re | wrong_re | prompt
#     set:     dev (iterate treatment variants here) | holdout (run once, report)
#     grade:   match         -> correct iff correct_re matches a stublog line; wrong iff wrong_re
#              no_tool       -> correct iff NO stub fired (a negative — catches over-triggering)
#              output        -> grade the agent's own stdout, not the stub log: correct iff
#                               correct_re matches it; else wrong iff wrong_re does
#              output_absent -> stdout negative: correct iff wrong_re is ABSENT from stdout
#     *_re:    extended-regex; matched per stublog line for tool modes (match/no_tool), or
#              against the agent's whole stdout for output modes. No field may contain '|',
#              so a regex cannot use alternation — pick single-branch patterns.
#     prompt:  the task. MUST NOT name the target tool — that is what we are measuring.
#
# DISCRIMINATOR CONSTRAINT — a task only measures the change if its target tool is
#   (a) change-only: not discoverable any other way (absent from the rest of auto-loaded
#       context AND not found on the filesystem by control), and
#   (b) stub-gradable: a *bare* command a PATH stub can shadow (scripts/stubs/ holds the
#       shadows; the stub filename is the bare command).
# Tools invoked via MCP or by full path are not stub-gradable and need a transcript
# capture this harness doesn't have.
#
# The discriminator constraint applies to *tool* modes. For `output` / `output_absent`
# the target is the agent's authored text, not a command, so (b) does not apply and no
# stub is needed — but (a) change-only still holds: the behaviour must be attributable to
# the change alone, or the task measures nothing.
#
# The entries below are illustrative scaffolding for a hypothetical change that adds, to
# auto-loaded context, "to list the widgets, run `example-tool list`". They will not show
# a real delta until you point them at an actual change + matching stub.

TASKS=(
# --- DEV SET (iterate treatment variants against these) ---
"D1_list|dev|match|^example-tool .*list|^example-tool .*(create|delete)|You need a list of the project's widgets. Run the command that lists them and report what it returns."
"D2_neg_count|dev|no_tool|||How many Markdown (.md) files are in the domains/ directory of this repository? Run a command to count them and report the number."

# --- HELD-OUT SET (different framing; run ONCE to report) ---
"H1_list_alt|holdout|match|^example-tool .*list|^example-tool .*(create|delete)|Show me the widgets currently configured in this project. Run the appropriate command."

# --- OUTPUT-GRADED (score the agent's authored text, not a tool — no stub needed) ---
# Hypothetical change: auto-loaded context now says "report a count as a bare integer, no
# prose." Grades stdout directly — correct = a lone number, wrong = prose around it.
"O1_bare_count|dev|output|^[0-9]+$|widget|How many widgets are configured in this project? Reply with only the number."
)
