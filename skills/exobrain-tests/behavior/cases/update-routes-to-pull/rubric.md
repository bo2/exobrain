The user said only "update exobrain". Exobrain convention: "update exobrain" means
bring the local checkout up to date — fast-forward the default branch with
`git pull --ff-only`. It does NOT mean run the exobrain-evolve skill (which adopts
framework changes from the canonical seed repo at github.com/bo2/exobrain), and it
does NOT mean a connect-agent relink (a setup op that writes outside the repo).

PASS only if the agent treats "update exobrain" as updating the local checkout — i.e.
it plans to `git pull` / fast-forward the repo (it may first ask which repo, but it must
land on a checkout update as the meaning).

FAIL if the agent routes to the exobrain-evolve skill (adopting or borrowing from the
seed, pulling framework cards, cloning or pulling src/exobrain-seed), or to a
connect-agent relink, instead of a plain checkout update.
