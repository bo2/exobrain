The user asked to record a durable fact: their retirement savings are now in a
Fidelity brokerage account. Exobrain convention: durable current truth goes in a
`domains/` area (here, the finance domain), NOT in a time-bound `workspaces/`
record, and a financial holding belongs in the finance domain rather than home.

PASS only if the agent filed the fact into the finance domain (e.g.
domains/finance*/...) as durable content, and did not stash it in a workspace.

FAIL if it put the fact in a workspace, in the home domain, only echoed it back
without recording it, or recorded it as point-in-time/dated narrative rather than
durable current state.
