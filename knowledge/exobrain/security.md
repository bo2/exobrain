# Security posture and the findings ledger

How an exobrain treats its own security as routine work: a stated posture, a ledger of what is known to be weak, and a channel that puts the ledger in front of a person. The rules an agent must never break are `AGENTS.md` § Security; this file is about the weaknesses that remain while those rules hold.

## Posture

An agent that reads untrusted text — mail, web pages, documents, another repository — can be talked into acting against its instructions. No filter or instruction makes that impossible, so the design assumes it will happen and works on what follows:

- **Limit what a hijacked agent can do.** A credential carries the narrowest scope its job needs. An agent that reads untrusted input holds as little power to act as its work allows — sending, pushing, scheduling, and privileged commands are each a reason to ask whether that agent needs them.
- **Make changes visible.** Everything an agent changes lands in git, and what it does outside git is reported to a person through a channel the agent does not control.
- **Keep recovery cheap.** History and off-machine backups make a bad change something to revert, not something to survive.
- **Hold less on disk.** A working copy in `tmp/` or a `_cache/` — a database dump, a scanned identity document, a mail export — is as exposed as the machine it sits on and is deleted with the work that needed it; the healthcheck names every scratch entry with no file touched inside the window `EXOBRAIN_SCRATCH_DAYS` sets, and deletes nothing itself.
- **Gates serve quality.** The landing gates (`landing.md`) catch mistakes; they are not a security boundary, because an agent that can run commands can act without landing anything.

## The ledger

A weakness that is noticed and not written down is noticed again by the next session, or by nobody. The ledger is where it goes: `security.json`, a registry at the repo root or in any scope directory, written through `scripts/security-findings.py` and validated against [`/security.schema.json`](../../security.schema.json).

| Field | Holds |
|---|---|
| `id` | Kebab-case, unique across every registry. |
| `title` | One line. |
| `severity` | `high` — exploitable as things stand: private data read, a person impersonated, data destroyed. `medium` — needs another failure first, or the damage is bounded. `low` — hygiene. |
| `status` | `open`, or `accepted` — a risk knowingly kept, with a reason and a date to look again. |
| `found` | The date it was recorded. |
| `surface` | Where: a host, a service, a file, a credential's name. |
| `impact` | What someone could do with it. |
| `fix` | The proposed remedy. |
| `fixer` | `agent` when a change in this repo fixes it; `person` when the fix is on a system the agent does not hold. |

A registry holds what is open or accepted. A fixed finding is removed — the commit that removes it is the record. A finding never holds a secret value: it names the credential, not its content.

**Which registry.** Every tracked scope is visible to everyone with repository access, and a ledger is a list of where the instance is weak. A finding that this audience may read goes in the root registry, or in the scope it concerns. One that it may not goes in the gitignored `local/` scope's registry, which the script discovers like any other.

## Recording one

```bash
scripts/security-findings.py add --title "…" --severity medium \
    --surface "…" --impact "…" --fix "…" --fixer person
```

An agent that notices a suspected weakness while doing something else records it and carries on with its task — it neither fixes it silently nor passes it by. A fix is a change of its own, with its own review; recording keeps the task in hand small and the weakness in view. When unsure whether something is a weakness, record it at `low` and say what is uncertain in `--notes`.

`accept <id> --reason … --review-by <date>` keeps a risk on purpose; `reopen <id>` undoes that; `close <id>` removes a fixed finding.

## Reaching a person

`scripts/security-findings.py summary` prints the counts and names what needs someone — a `high` finding open past the age threshold, an accepted risk past its review date, a registry past the review interval — and exits 2 when anything does. The thresholds and their defaults are environment settings named in the script's header.

The session-start healthcheck runs it and prints those lines, so every instance has one channel without building any. An instance with a better one — a scheduled digest, a chat message — calls `summary` or `list --json` from it.

## Reviewing

Noticing in passing finds little; most findings come from looking on purpose. A review walks what the instance exposes — each credential's scope against its use, what each agent can do against what its job needs, what leaves the machine and to whom, whether the backups restore — records what it finds, and settles what has been fixed. `scripts/security-findings.py reviewed` stamps the date, which is what the review-age check reads. What a review covers is the instance's own list: it depends on the tools and hosts that instance runs.

## Machinery

`scripts/security-findings.py --check` validates every registry — shape, vocabulary, dates, ids unique across registries — and `validate-exobrain.sh` runs it. Tests: `skills/exobrain-tests/unit/test-security-findings.sh`, and the behavior cases `security-finding-recorded` and its negative twin `neg-no-finding-for-scoped-credential`.
