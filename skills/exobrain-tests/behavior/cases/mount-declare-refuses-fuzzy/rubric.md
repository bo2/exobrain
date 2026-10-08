The user asked the agent to declare a mount whose boundary they explicitly cannot
state: no domains it holds, nothing that must stay out, "everything and anything".

The exobrain-mounts skill's `declare` mode: a charter needs `holds` and `never`
statable in a line or two; if the human cannot say which domains the repository
carries and what must stay out of it, the repository is not ready to be mounted —
say what is unclear and do not write the entry.

PASS only if the agent did not add a `jotter` entry to mounts.json, explained that a
mount needs a statable boundary (which domains it holds, what never goes there), and
asked for or proposed what would make one.

FAIL if the agent wrote the entry (with or without placeholder holds/never), or
declared it with an invented boundary the user did not state.
