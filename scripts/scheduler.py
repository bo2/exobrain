#!/usr/bin/env python3
"""Exobrain scheduler — one entry point for the repo's periodic jobs.

Jobs are declared in per-scope schedule.json registries, discovered at the repo
root and in every scope directory (any dir carrying an AGENTS.md — group,
person, host, or the gitignored local/ scope for private jobs); job names must
be unique across all of them. --config <file> bypasses discovery and reads one
file. State (last run per job) and logs live under <repo>/tmp/scheduler/ —
per-machine and gitignored, so it never syncs between hosts.

Scheduling is period-based, not wall-clock-based: a job declares `every` (the
minimum period between run starts), and a tick runs it when now - last start >=
that period. Periods have 1-minute resolution — `every` must be >= 1m, and the
loop polls once a minute by default.

Modes:
  tick            run every enabled job that is due, then exit (cron entry point)
  loop            tick forever (tmux entry point); --tick-interval sets the poll cadence;
                  re-reads the registries each tick, so schedule changes deploy without a restart
  run <job>       run one job now, regardless of schedule
  status          show each job's period, last result, and next due time

Due jobs start in parallel (a thread per job, a subprocess per run) with cwd =
the repo root; one job never blocks another. A per-job flock
(tmp/scheduler/locks/<job>.lock) makes runs of the same job mutually exclusive:
if a run outlives its period, the next start waits for the first tick after it
finishes. `loop` additionally takes a scheduler-wide lock so only one loop runs
per host; overlapping `tick`s (e.g. cron pileup) are safe. stdout+stderr are
appended to tmp/scheduler/logs/<job>.log.

schedule.json shape:
  {"jobs": [{"name": "...", "every": "15m", "command": ["python3", "path/script.py", "--flag"],
             "timeout": "1h", "enabled": true}]}
  - every: period between run starts — "<n>m" | "<n>h" (unit required), minimum "1m"
  - timeout: max run time before the job is killed — "<n>s" | "<n>m" | "<n>h", default "1h"
  - command: argv list, run from the repo root; "{ROOT}" in an arg expands to the repo root
  - enabled: defaults to true
"""

import argparse
import fcntl
import json
import os
import signal
import subprocess
import sys
import threading
import time
from datetime import datetime, timezone
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
STATE_DIR = REPO_ROOT / "tmp" / "scheduler"
STATE_FILE = STATE_DIR / "state.json"
STATE_LOCK_FILE = STATE_DIR / "state.lock"
LOG_DIR = STATE_DIR / "logs"
LOCK_FILE = STATE_DIR / "scheduler.lock"
JOB_LOCK_DIR = STATE_DIR / "locks"
DEFAULT_TIMEOUT = 3600
LOG_ROTATE_BYTES = 10 * 1024 * 1024


def parse_duration(value, field, job, units):
    factors = {"s": 1, "m": 60, "h": 3600}
    text = str(value).strip().lower()
    if text and text[-1] in units:
        try:
            return int(float(text[:-1]) * factors[text[-1]])
        except ValueError:
            pass
    expected = " | ".join(f'"<n>{u}"' for u in units)
    sys.exit(f"job {job!r}: bad {field} {value!r} (unit required: {expected})")


PRUNE_DIRS = {".git", ".worktrees", ".agent-worktrees", ".agents", ".claude",
              "src", "tmp", "node_modules", "__pycache__", "domains", "workspaces"}


def discover_configs(explicit):
    """schedule.json at the repo root plus one in any scope directory — a dir
    carrying an AGENTS.md, which is the repo's scope flag. Content trees and
    generated/clone dirs are pruned, mirroring validate-exobrain.sh's walk."""
    if explicit:
        return [explicit]
    candidates = [REPO_ROOT / "schedule.json"]
    for root, dirs, files in os.walk(REPO_ROOT):
        dirs[:] = sorted(d for d in dirs if d not in PRUNE_DIRS)
        if "AGENTS.md" in files and "schedule.json" in files and Path(root) != REPO_ROOT:
            candidates.append(Path(root) / "schedule.json")
    found = [path for path in candidates if path.exists()]
    if not found:
        sys.exit("no schedule.json found (looked at the repo root and in every scope dir)")
    return found


def load_jobs(config_paths):
    jobs = []
    seen = {}
    for config_path in config_paths:
        try:
            config = json.loads(config_path.read_text())
        except FileNotFoundError:
            sys.exit(f"config not found: {config_path}")
        except json.JSONDecodeError as e:
            sys.exit(f"config is not valid JSON: {config_path}: {e}")
        try:
            source = str(config_path.resolve().relative_to(REPO_ROOT))
        except ValueError:
            source = str(config_path)
        for raw in config.get("jobs", []):
            name = raw.get("name")
            if not name:
                sys.exit(f"{source}: every job needs a name")
            if name in seen:
                sys.exit(f"{source}: job {name!r} is already declared in {seen[name]}")
            seen[name] = source
            command = raw.get("command")
            if not isinstance(command, list) or not command:
                sys.exit(f"{source}: job {name!r}: command must be a non-empty argv list")
            every = parse_duration(raw.get("every", "15m"), "every", name, units="mh")
            if every < 60:
                sys.exit(f"{source}: job {name!r}: every {raw.get('every')!r} is below "
                         "the 1-minute resolution")
            jobs.append({
                "name": name,
                "source": source,
                "every": every,
                "command": [arg.replace("{ROOT}", str(REPO_ROOT)) for arg in command],
                "timeout": parse_duration(raw.get("timeout", f"{DEFAULT_TIMEOUT}s"), "timeout",
                                          name, units="smh"),
                "enabled": raw.get("enabled", True),
            })
    return jobs


def load_state():
    try:
        return json.loads(STATE_FILE.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def update_state(name, **fields):
    # short blocking flock so parallel job threads/processes can't lose each
    # other's read-modify-write
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    with open(STATE_LOCK_FILE, "w") as guard:
        fcntl.flock(guard, fcntl.LOCK_EX)
        state = load_state()
        state.setdefault(name, {}).update(fields)
        tmp = STATE_FILE.with_suffix(".json.tmp")
        tmp.write_text(json.dumps(state, indent=2) + "\n")
        tmp.replace(STATE_FILE)


def now_utc():
    return datetime.now(timezone.utc)


def iso(ts=None):
    return (ts or now_utc()).strftime("%Y-%m-%dT%H:%M:%SZ")


def log_line(message):
    print(f"[{iso()}] {message}", flush=True)


def acquire_flock(path):
    path.parent.mkdir(parents=True, exist_ok=True)
    handle = open(path, "w")
    try:
        fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        handle.close()
        return None
    handle.write(str(os.getpid()))
    handle.flush()
    return handle  # a dropped handle releases the flock — keep it referenced


def job_lock_path(name):
    return JOB_LOCK_DIR / f"{name}.lock"


def job_running(name):
    # flock probe: conflicts even with a handle held by this same process
    path = job_lock_path(name)
    if not path.exists():
        return False
    with open(path) as handle:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
            return False
        except OSError:
            return True


def job_log_path(name):
    return LOG_DIR / f"{name}.log"


def rotate_log(path):
    if path.exists() and path.stat().st_size > LOG_ROTATE_BYTES:
        path.replace(path.with_suffix(".log.1"))


def run_job(job, trigger, no_lock=False):
    """Run one job to completion. Returns True/False for exit status, or None
    when skipped because a previous run still holds the job's lock."""
    name = job["name"]
    lock = None
    if not no_lock:
        lock = acquire_flock(job_lock_path(name))
        if lock is None:
            log_line(f"{name}: previous run still in progress; skipped ({trigger})")
            return None
    try:
        return _run_job_locked(job, trigger)
    finally:
        if lock:
            lock.close()


def _run_job_locked(job, trigger):
    name = job["name"]
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    log_path = job_log_path(name)
    rotate_log(log_path)

    started = now_utc()
    update_state(name, last_start=iso(started))
    log_line(f"{name}: start ({trigger})")

    with open(log_path, "a") as log:
        log.write(f"\n=== {iso(started)} start ({trigger}): {' '.join(job['command'])} ===\n")
        log.flush()
        try:
            proc = subprocess.Popen(
                job["command"], cwd=REPO_ROOT, stdout=log, stderr=subprocess.STDOUT,
                start_new_session=True,
            )
            try:
                exit_code = proc.wait(timeout=job["timeout"])
                result = str(exit_code)
            except subprocess.TimeoutExpired:
                os.killpg(proc.pid, signal.SIGTERM)
                try:
                    proc.wait(timeout=30)
                except subprocess.TimeoutExpired:
                    os.killpg(proc.pid, signal.SIGKILL)
                    proc.wait()
                exit_code, result = -1, f"timeout after {job['timeout']}s"
        except OSError as e:
            exit_code, result = -1, f"failed to launch: {e}"
        finished = now_utc()
        duration = int((finished - started).total_seconds())
        log.write(f"=== {iso(finished)} exit {result} ({duration}s) ===\n")

    update_state(name, last_finish=iso(finished), last_result=result)
    level = "" if exit_code == 0 else "  <-- FAILED"
    log_line(f"{name}: exit {result} ({duration}s){level}")
    return exit_code == 0


def seconds_since_start(entry):
    last = entry.get("last_start")
    if not last:
        return None
    started = datetime.strptime(last, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    return (now_utc() - started).total_seconds()


def due_jobs(jobs, state):
    due = []
    for job in jobs:
        if not job["enabled"]:
            continue
        elapsed = seconds_since_start(state.get(job["name"], {}))
        if elapsed is None or elapsed >= job["every"]:
            due.append(job)
    return due


def cmd_tick(jobs, dry_run, active=None):
    """Start every due job in its own thread. With active (loop mode), jobs
    this process is still running are excluded and threads are left to finish
    on their own; without it (cron tick), wait for all started jobs so the
    process outlives its children."""
    if active is not None:
        for name, thread in list(active.items()):
            if not thread.is_alive():
                del active[name]
    state = load_state()
    due = [j for j in due_jobs(jobs, state) if active is None or j["name"] not in active]
    if dry_run:
        log_line(f"tick (dry-run): would run {', '.join(j['name'] for j in due) or 'nothing'}")
        return
    threads = []
    for job in due:
        thread = threading.Thread(target=run_job, args=(job, "tick"), name=job["name"])
        thread.start()
        threads.append(thread)
        if active is not None:
            active[job["name"]] = thread
    if active is None:
        for thread in threads:
            thread.join()


def cmd_loop(explicit_config, jobs, tick_interval, dry_run):
    log_line(f"scheduler loop started: {len(jobs)} jobs, polling every {tick_interval}s "
             f"(jobs: {', '.join(j['name'] + ('' if j['enabled'] else ' [disabled]') for j in jobs)})")
    active = {}  # job name -> live thread, so a slow run is skipped, not restarted
    while True:
        # re-discover and re-read the registries each tick so a pulled schedule
        # change applies on the next cycle without a restart (same property job
        # scripts get from being re-invoked fresh); a bad config skips the tick
        try:
            jobs = load_jobs(discover_configs(explicit_config))
        except SystemExit as e:
            log_line(f"config error, skipping tick: {e}")
        else:
            cmd_tick(jobs, dry_run, active=active)
        time.sleep(tick_interval)


def cmd_run(jobs, name, dry_run, no_lock):
    matches = [j for j in jobs if j["name"] == name]
    if not matches:
        sys.exit(f"no job named {name!r} (jobs: {', '.join(j['name'] for j in jobs)})")
    job = matches[0]
    if dry_run:
        log_line(f"run (dry-run): would run {name}: {' '.join(job['command'])}")
        return
    ok = run_job(job, "manual", no_lock=no_lock)
    sys.exit(0 if ok else 1)


def fmt_period(seconds):
    return f"{seconds // 3600}h" if seconds % 3600 == 0 else f"{seconds // 60}m"


def cmd_status(jobs):
    state = load_state()
    rows = [("JOB", "ENABLED", "EVERY", "LAST START", "LAST RESULT", "NEXT DUE", "SOURCE")]
    for job in jobs:
        entry = state.get(job["name"], {})
        elapsed = seconds_since_start(entry)
        if job_running(job["name"]):
            next_due = "running now"
        elif not job["enabled"]:
            next_due = "-"
        elif elapsed is None or elapsed >= job["every"]:
            next_due = "due now"
        else:
            next_due = f"in {int(job['every'] - elapsed)}s"
        rows.append((
            job["name"],
            "yes" if job["enabled"] else "no",
            fmt_period(job["every"]),
            entry.get("last_start", "never"),
            entry.get("last_result", "-"),
            next_due,
            job["source"],
        ))
    widths = [max(len(row[i]) for row in rows) for i in range(len(rows[0]))]
    for row in rows:
        print("  ".join(cell.ljust(width) for cell, width in zip(row, widths)))
    print(f"\nstate: {STATE_FILE}\nlogs:  {LOG_DIR}/<job>.log")


def main():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--config", type=Path, default=None,
                        help="read one schedule file instead of discovering "
                             "schedule.json at the repo root and in every scope dir")
    parser.add_argument("--dry-run", action="store_true",
                        help="print what would run without running it")
    parser.add_argument("--no-lock", action="store_true",
                        help="skip the scheduler locks (one-loop-per-host and per-job)")
    sub = parser.add_subparsers(dest="mode", required=True)
    sub.add_parser("tick", help="run due jobs once and exit (for cron)")
    loop_parser = sub.add_parser("loop", help="tick forever (for tmux)")
    loop_parser.add_argument("--tick-interval", type=int, default=60,
                             help="seconds between ticks (default: 60)")
    run_parser = sub.add_parser("run", help="run one job now, regardless of schedule")
    run_parser.add_argument("job")
    sub.add_parser("status", help="show job state and next due times")
    args = parser.parse_args()

    jobs = load_jobs(discover_configs(args.config))
    if args.mode == "status":
        cmd_status(jobs)
        return

    if args.mode == "loop" and not args.no_lock and not args.dry_run:
        loop_lock = acquire_flock(LOCK_FILE)  # hold for the loop's lifetime
        if loop_lock is None:
            log_line("another scheduler loop is running on this host; exiting "
                     "(use --no-lock to override)")
            return

    if args.mode == "tick":
        cmd_tick(jobs, args.dry_run)
    elif args.mode == "loop":
        cmd_loop(args.config, jobs, args.tick_interval, args.dry_run)
    elif args.mode == "run":
        cmd_run(jobs, args.job, args.dry_run, args.no_lock)


if __name__ == "__main__":
    main()
