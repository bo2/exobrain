#!/usr/bin/env python3
"""Reconcile the repo's declared scheduled jobs into the OpenClaw cron scheduler.

Jobs are declared in per-scope crons.json registries, discovered at the repo
root and in every scope directory (any dir carrying an AGENTS.md, the
gitignored local/ scope included); job names must be unique across all of them.
The registries are the source of truth: this script owns every OpenClaw cron
job whose declarationKey starts with "exobrain." and reconciles that set to
match them — missing jobs are added, drifted jobs are patched, jobs no longer
declared are removed. Jobs without the prefix (OpenClaw-native jobs, one-shot
reminders) are never touched.

Drift is judged only on the fields a registry entry declares, so gateway
defaults (stagger, delivery details a job doesn't set) never fight the sync.

Modes:
  sync (default)   reconcile the gateway to the registries
  --dry-run        print the add/edit/rm plan without executing it
  --check          validate the registries and exit — reads no gateway and
                   needs no openclaw binary (validate-exobrain.sh runs this)

crons.json shape:
  {"jobs": [{
    "name": "daily-brief",               kebab-case, unique across registries;
                                         the OpenClaw declarationKey is
                                         "exobrain.<name>"
    "displayName": "Daily brief",        optional OpenClaw job name (default: name)
    "description": "...",                optional
    "enabled": true,                     optional, default true
    "schedule": {"cron": "0 12 * * *", "tz": "Europe/Berlin", "stagger": "5m"},
                                         or {"every": "1h"} or {"at": "<ISO>"};
                                         stagger optional — "0s" pins the exact minute
    "payload": {"kind": "agent", "message": "...", "thinking": "high",
                "timeoutSeconds": 900},
                                         or {"kind": "command", "argv": ["..."],
                                             "timeoutSeconds": 3600}
    "agent": "main",                     optional agent id, agent jobs only
    "delivery": {"mode": "announce", "channel": "telegram", "to": "<chat id>",
                 "bestEffort": false},   or {"mode": "none"} (the default)
    "failureAlert": {"after": 1, "channel": "telegram", "to": "<chat id>",
                     "cooldown": "6h"}   optional
  }]}

"{ROOT}" in message and argv entries expands to the repo root at sync time, so
registries stay machine-neutral. Agent jobs run in isolated sessions. A model
is deliberately not declarable — model routing stays with OpenClaw's defaults.
"""

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
KEY_PREFIX = "exobrain."
THINKING_LEVELS = {"off", "minimal", "low", "medium", "high", "xhigh", "adaptive", "max", "ultra"}
NAME_RE = re.compile(r"^[a-z0-9][a-z0-9-]*$")
DURATION_RE = re.compile(r"^\d+[smh]$")

PRUNE_DIRS = {".git", ".worktrees", ".agent-worktrees", ".agents", ".claude",
              "src", "tmp", "node_modules", "__pycache__", "knowledge", "workspaces"}


def fail(errors):
    for e in errors:
        print(f"crons: {e}", file=sys.stderr)
    sys.exit(1)


def discover_registries():
    """crons.json at the repo root plus one in any scope directory — a dir
    carrying an AGENTS.md, the repo's scope flag."""
    found = [REPO_ROOT / "crons.json"]
    for root, dirs, files in os.walk(REPO_ROOT):
        dirs[:] = sorted(d for d in dirs if d not in PRUNE_DIRS)
        if "AGENTS.md" in files and "crons.json" in files and Path(root) != REPO_ROOT:
            found.append(Path(root) / "crons.json")
    return [p for p in found if p.exists()]


def duration_ms(text):
    return int(text[:-1]) * {"s": 1000, "m": 60000, "h": 3600000}[text[-1]]


def validate_job(raw, source, errors):
    name = raw.get("name")
    ctx = f"{source}: job {name!r}"
    if not name or not NAME_RE.match(str(name)):
        errors.append(f"{ctx}: name must be non-empty kebab-case")
        return
    schedule = raw.get("schedule") or {}
    kinds = [k for k in ("cron", "every", "at") if k in schedule]
    if len(kinds) != 1:
        errors.append(f"{ctx}: schedule needs exactly one of cron/every/at")
    if "stagger" in schedule and not DURATION_RE.match(str(schedule["stagger"])):
        errors.append(f'{ctx}: schedule.stagger must look like "30s"/"5m"/"1h"')
    if "cron" in schedule and not schedule.get("tz"):
        errors.append(f"{ctx}: a cron schedule needs an IANA tz")
    payload = raw.get("payload") or {}
    kind = payload.get("kind")
    if kind == "agent":
        if not payload.get("message"):
            errors.append(f"{ctx}: agent payload needs a message")
        if "model" in payload:
            errors.append(f"{ctx}: model is not declarable — routing stays with OpenClaw")
        thinking = payload.get("thinking")
        if thinking is not None and thinking not in THINKING_LEVELS:
            errors.append(f"{ctx}: bad thinking level {thinking!r}")
    elif kind == "command":
        argv = payload.get("argv")
        if not isinstance(argv, list) or not argv or not all(isinstance(a, str) for a in argv):
            errors.append(f"{ctx}: command payload needs argv as a non-empty list of strings")
    else:
        errors.append(f'{ctx}: payload.kind must be "agent" or "command"')
    timeout = payload.get("timeoutSeconds")
    if timeout is not None and (not isinstance(timeout, int) or timeout <= 0):
        errors.append(f"{ctx}: payload.timeoutSeconds must be a positive integer")
    delivery = raw.get("delivery") or {"mode": "none"}
    if delivery.get("mode") not in ("announce", "none"):
        errors.append(f'{ctx}: delivery.mode must be "announce" or "none"')
    elif delivery["mode"] == "announce" and not (delivery.get("channel") and delivery.get("to")):
        errors.append(f"{ctx}: announce delivery needs channel and to")
    alert = raw.get("failureAlert")
    if alert is not None:
        if not (alert.get("channel") and alert.get("to")):
            errors.append(f"{ctx}: failureAlert needs channel and to")
        if not isinstance(alert.get("after", 1), int):
            errors.append(f"{ctx}: failureAlert.after must be an integer")
        if "cooldown" in alert and not DURATION_RE.match(str(alert["cooldown"])):
            errors.append(f'{ctx}: failureAlert.cooldown must look like "30m"/"6h"')


def load_jobs():
    jobs, seen, errors = [], {}, []
    for path in discover_registries():
        try:
            config = json.loads(path.read_text())
        except json.JSONDecodeError as e:
            errors.append(f"{path}: not valid JSON: {e}")
            continue
        source = str(path.resolve().relative_to(REPO_ROOT))
        for raw in config.get("jobs", []):
            validate_job(raw, source, errors)
            name = raw.get("name")
            if name in seen:
                errors.append(f"{source}: job {name!r} is already declared in {seen[name]}")
            seen[name] = source
            jobs.append({**raw, "source": source})
    if errors:
        fail(errors)
    return jobs


def expand_root(text):
    return text.replace("{ROOT}", str(REPO_ROOT))


def desired_state(job):
    """The gateway-side field values a registry entry pins, as a flat dict of
    JSON-path -> value. Only these paths are compared, so everything a job
    doesn't declare is left to gateway defaults."""
    want = {
        "name": job.get("displayName", job["name"]),
        "enabled": job.get("enabled", True),
        "delivery.mode": (job.get("delivery") or {}).get("mode", "none"),
    }
    if job.get("description"):
        want["description"] = job["description"]
    schedule = job["schedule"]
    if "cron" in schedule:
        want["schedule.kind"] = "cron"
        want["schedule.expr"] = schedule["cron"]
        want["schedule.tz"] = schedule["tz"]
    elif "every" in schedule:
        want["schedule.kind"] = "every"
        want["schedule.everyMs"] = duration_ms(schedule["every"])
    else:
        want["schedule.kind"] = "at"
    if "stagger" in schedule:
        want["schedule.staggerMs"] = duration_ms(schedule["stagger"])
    payload = job["payload"]
    if payload["kind"] == "agent":
        want["payload.kind"] = "agentTurn"
        want["payload.message"] = expand_root(payload["message"])
        want["sessionTarget"] = "isolated"
        if "thinking" in payload:
            want["payload.thinking"] = payload["thinking"]
        if job.get("agent"):
            want["agentId"] = job["agent"]
    else:
        want["payload.kind"] = "command"
        want["payload.argv"] = [expand_root(a) for a in payload["argv"]]
    if "timeoutSeconds" in payload:
        want["payload.timeoutSeconds"] = payload["timeoutSeconds"]
    delivery = job.get("delivery") or {}
    if delivery.get("mode") == "announce":
        want["delivery.channel"] = delivery["channel"]
        want["delivery.to"] = str(delivery["to"])
        if "bestEffort" in delivery:
            want["delivery.bestEffort"] = delivery["bestEffort"]
    alert = job.get("failureAlert")
    if alert:
        want["failureAlert.after"] = alert.get("after", 1)
        want["failureAlert.channel"] = alert["channel"]
        want["failureAlert.to"] = str(alert["to"])
        want["failureAlert.mode"] = "announce"
        if "cooldown" in alert:
            want["failureAlert.cooldownMs"] = duration_ms(alert["cooldown"])
    return want


def actual_value(actual, path):
    node = actual
    for part in path.split("."):
        if not isinstance(node, dict) or part not in node:
            return None
        node = node[part]
    return node


def drifted_paths(want, actual):
    return sorted(path for path, value in want.items()
                  if actual_value(actual, path) != value)


def edit_args(job):
    """The full field set as `cron edit` (and mostly `cron add`) flags —
    patching every declared field keeps one builder for add-follow-up and
    drift repair alike."""
    args = ["--name", job.get("displayName", job["name"])]
    if job.get("description"):
        args += ["--description", job["description"]]
    schedule = job["schedule"]
    if "cron" in schedule:
        args += ["--cron", schedule["cron"], "--tz", schedule["tz"]]
    elif "every" in schedule:
        args += ["--every", schedule["every"]]
    else:
        args += ["--at", schedule["at"]]
    if "stagger" in schedule:
        stagger = schedule["stagger"]
        args += ["--exact"] if duration_ms(stagger) == 0 else ["--stagger", stagger]
    payload = job["payload"]
    if payload["kind"] == "agent":
        args += ["--message", expand_root(payload["message"]), "--session", "isolated"]
        if "thinking" in payload:
            args += ["--thinking", payload["thinking"]]
        if job.get("agent"):
            args += ["--agent", job["agent"]]
    else:
        args += ["--command-argv", json.dumps([expand_root(a) for a in payload["argv"]])]
    if "timeoutSeconds" in payload:
        args += ["--timeout-seconds", str(payload["timeoutSeconds"])]
    delivery = job.get("delivery") or {}
    if delivery.get("mode") == "announce":
        args += ["--announce", "--channel", delivery["channel"], "--to", str(delivery["to"])]
        if "bestEffort" in delivery:
            args += ["--best-effort-deliver"] if delivery["bestEffort"] \
                else ["--no-best-effort-deliver"]
    else:
        args += ["--no-deliver"]
    alert = job.get("failureAlert")
    if alert:
        args += ["--failure-alert",
                 "--failure-alert-after", str(alert.get("after", 1)),
                 "--failure-alert-channel", alert["channel"],
                 "--failure-alert-to", str(alert["to"]),
                 "--failure-alert-mode", "announce"]
        if "cooldown" in alert:
            args += ["--failure-alert-cooldown", alert["cooldown"]]
    else:
        args += ["--no-failure-alert"]
    args += ["--enable"] if job.get("enabled", True) else ["--disable"]
    return args


def openclaw(*args, capture=False):
    result = subprocess.run(["openclaw", *args], text=True,
                            capture_output=capture, check=False)
    if result.returncode != 0:
        detail = (result.stderr or "").strip() if capture else f"exit {result.returncode}"
        sys.exit(f"openclaw {' '.join(args[:2])} failed: {detail}")
    return result.stdout if capture else None


def gateway_jobs():
    listing = json.loads(openclaw("cron", "list", "--json", capture=True))
    return {j["declarationKey"]: j for j in listing.get("jobs", [])
            if str(j.get("declarationKey") or "").startswith(KEY_PREFIX)}


def sync(jobs, dry_run):
    existing = gateway_jobs()
    desired_keys = {KEY_PREFIX + j["name"]: j for j in jobs}
    actions = 0

    for key, job in desired_keys.items():
        actual = existing.get(key)
        if actual is None:
            actions += 1
            print(f"add  {key}  ({job['source']})")
            if not dry_run:
                schedule = job["schedule"]
                base = ["cron", "add", "--declaration-key", key,
                        "--name", job.get("displayName", job["name"])]
                if "cron" in schedule:
                    base += ["--cron", schedule["cron"], "--tz", schedule["tz"]]
                elif "every" in schedule:
                    base += ["--every", schedule["every"]]
                else:
                    base += ["--at", schedule["at"]]
                if job["payload"]["kind"] == "agent":
                    base += ["--message", expand_root(job["payload"]["message"])]
                else:
                    base += ["--command-argv",
                             json.dumps([expand_root(a) for a in job["payload"]["argv"]])]
                openclaw(*base)
                job_id = job_id_for(key)
                openclaw("cron", "edit", job_id, *edit_args(job))
        else:
            drift = drifted_paths(desired_state(job), actual)
            if drift:
                actions += 1
                print(f"edit {key}  ({', '.join(drift)})")
                if not dry_run:
                    openclaw("cron", "edit", actual["id"], *edit_args(job))

    for key, actual in existing.items():
        if key not in desired_keys:
            actions += 1
            print(f"rm   {key}  ({actual.get('name', '?')})")
            if not dry_run:
                openclaw("cron", "rm", actual["id"])

    if actions == 0:
        print(f"in sync: {len(jobs)} declared jobs match the gateway")
    elif dry_run:
        print(f"dry-run: {actions} action(s) planned")


def job_id_for(key):
    job = gateway_jobs().get(key)
    if job is None:
        sys.exit(f"job {key} not found on the gateway after add")
    return job["id"]


def main():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true",
                        help="validate the registries and exit; no gateway access")
    parser.add_argument("--dry-run", action="store_true",
                        help="print the reconciliation plan without executing it")
    args = parser.parse_args()

    jobs = load_jobs()
    if args.check:
        registries = sorted({j['source'] for j in jobs})
        print(f"crons: {len(jobs)} job(s) valid across "
              f"{len(registries)} registr{'y' if len(registries) == 1 else 'ies'}")
        return
    # {ROOT} must expand to a path that outlives the sync — a linked worktree's
    # doesn't, so reconciliation (and its plan preview) runs from the main
    # checkout only.
    if (REPO_ROOT / ".git").is_file():
        sys.exit(f"{REPO_ROOT} is a linked worktree; run the sync from the main "
                 "checkout so {ROOT} expands to stable paths")
    sync(jobs, args.dry_run)


if __name__ == "__main__":
    main()
