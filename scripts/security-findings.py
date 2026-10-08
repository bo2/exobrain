#!/usr/bin/env python3
"""The security findings ledger: record a suspected weakness, settle it, and say what needs a person.

Findings are declared in per-scope security.json registries, discovered at the repo
root and in every scope directory (any dir carrying an AGENTS.md, the gitignored
local/ scope included); finding ids are unique across all of them. A registry holds
what is open or knowingly accepted — a fixed finding is removed, and the commit that
removes it is the record. Never put a secret value in a finding: name the credential,
not its content.

Commands:
  add       record a finding (prints its id)
              --title T --severity high|medium|low --surface S --impact I --fix F
              [--fixer agent|person] [--source S] [--notes N] [--id slug] [--scope <dir>]
  accept    keep a finding as a known risk      <id> --reason R --review-by YYYY-MM-DD
  reopen    an accepted finding is open again   <id>
  close     the finding is fixed — remove it    <id>
  reviewed  stamp today as the registry's last full review   [--scope <dir>]
  list      every finding, most severe first    [--json]
  summary   what needs a person; exit 0 nothing, 2 something
  --check   validate every registry and exit (validate-exobrain.sh runs this)

security.json shape (security.schema.json):
  {"reviewed": "2026-01-31",            optional; date of the last full review
   "findings": [{
     "id": "agent-host-token-too-broad",  kebab-case, unique across registries
     "title": "...",                      one line
     "severity": "high",                  high   — exploitable as things stand: private data
                                                   read, a person impersonated, data destroyed
                                          medium — needs another failure first, or the damage
                                                   is bounded
                                          low    — hygiene; no direct path to harm
     "status": "open",                    open | accepted
     "found": "2026-01-31",
     "surface": "...",                    where: a host, a service, a file, a credential's name
     "impact": "...",                     what someone could do with it
     "fix": "...",                        the proposed remedy
     "fixer": "person",                   who can carry the fix out: agent | person
     "source": "...",                     optional: how it was found
     "notes": "...",                      optional
     "accepted": {"reason": "...", "review_by": "2026-07-31"}   accepted findings only
   }]}

summary flags, each tunable by environment: a high finding open for SECURITY_HIGH_DAYS
(default 14) or more, an accepted finding past its review_by date, and a registry not
reviewed for SECURITY_REVIEW_DAYS (default 30; 0 disables the review check).
SECURITY_TODAY pins the date, for tests.
"""

import argparse
import json
import os
import re
import sys
from datetime import date
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
REGISTRY = "security.json"
ID_RE = re.compile(r"^[a-z0-9][a-z0-9-]*$")
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
SEVERITIES = ("high", "medium", "low")
STATUSES = ("open", "accepted")
FIXERS = ("agent", "person")
REQUIRED = ("id", "title", "severity", "status", "found", "surface", "impact", "fix", "fixer")
OPTIONAL = ("source", "notes", "accepted")
ID_MAX = 60

PRUNE_DIRS = {".git", ".worktrees", ".agent-worktrees", ".agents", ".claude",
              "src", "tmp", "node_modules", "__pycache__", "knowledge", "workspaces"}


def today():
    return parse_date(os.environ.get("SECURITY_TODAY")) or date.today()


def die(message, code=1):
    print(f"security-findings: {message}", file=sys.stderr)
    sys.exit(code)


def discover_registries():
    """security.json at the repo root plus one in any scope directory — a dir
    carrying an AGENTS.md, the repo's scope flag."""
    found = [REPO_ROOT / REGISTRY]
    for root, dirs, files in os.walk(REPO_ROOT):
        dirs[:] = sorted(d for d in dirs if d not in PRUNE_DIRS)
        if "AGENTS.md" in files and REGISTRY in files and Path(root) != REPO_ROOT:
            found.append(Path(root) / REGISTRY)
    return [p for p in found if p.exists()]


def label(path):
    return path.relative_to(REPO_ROOT).as_posix()


def parse_date(text):
    if not isinstance(text, str) or not DATE_RE.match(text):
        return None
    try:
        return date.fromisoformat(text)
    except ValueError:
        return None


def read(path, errors=None):
    """A registry's parsed content, or None (with the reason recorded) when unreadable."""
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as e:
        if errors is None:
            die(f"{label(path)}: unreadable: {e}")
        errors.append(f"{label(path)}: unreadable: {e}")
        return None
    if not isinstance(data, dict) or not isinstance(data.get("findings", []), list):
        if errors is None:
            die(f"{label(path)}: must be an object with a findings list")
        errors.append(f"{label(path)}: must be an object with a findings list")
        return None
    data.setdefault("findings", [])
    return data


def write(path, data):
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    os.replace(tmp, path)


def validate_finding(raw, source, errors):
    if not isinstance(raw, dict):
        errors.append(f"{source}: a finding must be an object")
        return
    fid = raw.get("id")
    ctx = f"{source}: finding {fid!r}"
    if not isinstance(fid, str) or not ID_RE.match(fid):
        errors.append(f"{ctx}: id must be non-empty kebab-case")
        return
    for key in raw:
        if key not in REQUIRED + OPTIONAL:
            errors.append(f"{ctx}: unknown key {key!r}")
    for key in REQUIRED:
        if not isinstance(raw.get(key), str) or not raw[key].strip():
            errors.append(f"{ctx}: {key} must be a non-empty string")
    if raw.get("severity") not in SEVERITIES:
        errors.append(f"{ctx}: severity must be one of {', '.join(SEVERITIES)}")
    if raw.get("status") not in STATUSES:
        errors.append(f"{ctx}: status must be one of {', '.join(STATUSES)}")
    if raw.get("fixer") not in FIXERS:
        errors.append(f"{ctx}: fixer must be one of {', '.join(FIXERS)}")
    if parse_date(raw.get("found")) is None:
        errors.append(f"{ctx}: found must be a YYYY-MM-DD date")
    accepted = raw.get("accepted")
    if raw.get("status") == "accepted":
        if (not isinstance(accepted, dict) or set(accepted) != {"reason", "review_by"}
                or not isinstance(accepted.get("reason"), str) or not accepted["reason"].strip()
                or parse_date(accepted.get("review_by")) is None):
            errors.append(f"{ctx}: an accepted finding needs accepted.reason and accepted.review_by (YYYY-MM-DD)")
    elif accepted is not None:
        errors.append(f"{ctx}: only an accepted finding carries the accepted block")


def load_all(strict=True):
    """[(path, data)] for every registry, plus the validation errors. With strict, an
    invalid ledger stops the command: nothing acts on findings it cannot trust."""
    errors, loaded, seen = [], [], {}
    for path in discover_registries():
        data = read(path, errors)
        if data is None:
            continue
        for key in data:
            if key not in ("$schema", "reviewed", "findings"):
                errors.append(f"{label(path)}: unknown key {key!r}")
        if "reviewed" in data and parse_date(data["reviewed"]) is None:
            errors.append(f"{label(path)}: reviewed must be a YYYY-MM-DD date")
        for raw in data["findings"]:
            validate_finding(raw, label(path), errors)
            fid = raw.get("id") if isinstance(raw, dict) else None
            if isinstance(fid, str):
                if fid in seen:
                    errors.append(f"{label(path)}: finding {fid!r} is also declared in {seen[fid]}")
                seen[fid] = label(path)
        loaded.append((path, data))
    if strict and errors:
        for e in errors:
            print(f"security-findings: {e}", file=sys.stderr)
        sys.exit(1)
    return loaded, errors


def registry_for(scope):
    """The registry path a --scope names: the repo root by default, else a scope dir."""
    if scope in (None, "", ".", "global"):
        return REPO_ROOT / REGISTRY
    target = (REPO_ROOT / scope).resolve()
    if REPO_ROOT not in target.parents:
        die(f"--scope must be a directory inside this repo: {scope}", 2)
    if not (target / "AGENTS.md").exists():
        die(f"--scope is not a scope (no AGENTS.md): {scope}", 2)
    return target / REGISTRY


def slug(title):
    text = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")
    return text[:ID_MAX].rstrip("-")


def find(loaded, fid):
    for path, data in loaded:
        for finding in data["findings"]:
            if finding["id"] == fid:
                return path, data, finding
    die(f"no finding with id {fid!r} — see `list`", 2)


def cmd_add(args):
    loaded, _ = load_all()
    fid = args.id or slug(args.title)
    if not fid or not ID_RE.match(fid):
        die("could not derive a kebab-case id from the title — pass --id", 2)
    if any(f["id"] == fid for _, data in loaded for f in data["findings"]):
        die(f"a finding with id {fid!r} exists — update it, or pass a different --id", 2)
    finding = {"id": fid, "title": args.title.strip(), "severity": args.severity, "status": "open",
               "found": today().isoformat(), "surface": args.surface.strip(),
               "impact": args.impact.strip(), "fix": args.fix.strip(), "fixer": args.fixer}
    if args.source:
        finding["source"] = args.source.strip()
    if args.notes:
        finding["notes"] = args.notes.strip()
    errors = []
    validate_finding(finding, "new", errors)
    if errors:
        die("; ".join(errors), 2)
    path = registry_for(args.scope)
    data = dict(loaded).get(path) or {"findings": []}
    data["findings"].append(finding)
    write(path, data)
    print(fid)


def cmd_accept(args):
    if not args.reason.strip():
        die("--reason must say why the risk is kept", 2)
    if parse_date(args.review_by) is None:
        die("--review-by must be a YYYY-MM-DD date", 2)
    path, data, finding = find(load_all()[0], args.id)
    finding["status"] = "accepted"
    finding["accepted"] = {"reason": args.reason.strip(), "review_by": args.review_by}
    write(path, data)


def cmd_reopen(args):
    path, data, finding = find(load_all()[0], args.id)
    finding["status"] = "open"
    finding.pop("accepted", None)
    write(path, data)


def cmd_close(args):
    path, data, finding = find(load_all()[0], args.id)
    data["findings"].remove(finding)
    write(path, data)


def cmd_reviewed(args):
    loaded, _ = load_all()
    path = registry_for(args.scope)
    data = dict(loaded).get(path) or {"findings": []}
    data = {k: v for k, v in data.items() if k != "findings"} | {
        "reviewed": today().isoformat(), "findings": data["findings"]}
    write(path, data)


def ordered(loaded):
    rows = [dict(f, registry=label(path)) for path, data in loaded for f in data["findings"]]
    return sorted(rows, key=lambda f: (SEVERITIES.index(f["severity"]), f["found"], f["id"]))


def cmd_list(args):
    rows = ordered(load_all()[0])
    if args.json:
        print(json.dumps(rows, indent=2, ensure_ascii=False))
        return
    for f in rows:
        state = f["status"] if f["status"] == "open" else f"accepted, review by {f['accepted']['review_by']}"
        print(f"{f['severity']:<6} {f['id']} — {f['title']} ({state}; found {f['found']}; fixer: {f['fixer']})")


def env_days(name, default):
    value = os.environ.get(name, "")
    return int(value) if value.isdigit() else default


def cmd_summary(_args):
    loaded, _ = load_all()
    rows = ordered(loaded)
    if not loaded:
        return 0
    now = today()
    high_days, review_days = env_days("SECURITY_HIGH_DAYS", 14), env_days("SECURITY_REVIEW_DAYS", 30)
    open_rows = [f for f in rows if f["status"] == "open"]
    counts = ", ".join(f"{n} {sev}" for sev in SEVERITIES
                       if (n := sum(1 for f in open_rows if f["severity"] == sev)))
    accepted = len(rows) - len(open_rows)
    print(f"security: {len(open_rows)} open" + (f" ({counts})" if counts else "")
          + (f", {accepted} accepted" if accepted else ""))
    attention = []
    for f in open_rows:
        age = (now - parse_date(f["found"])).days
        if f["severity"] == "high" and age >= high_days:
            attention.append(f"high, open {age}d: {f['id']} — {f['title']}")
    for f in rows:
        if f["status"] == "accepted" and parse_date(f["accepted"]["review_by"]) < now:
            attention.append(f"accepted risk past its review date ({f['accepted']['review_by']}): "
                             f"{f['id']} — {f['title']}")
    if review_days:
        for path, data in loaded:
            last = parse_date(data.get("reviewed"))
            if last is None:
                attention.append(f"never reviewed: {label(path)}")
            elif (now - last).days >= review_days:
                attention.append(f"last reviewed {(now - last).days}d ago: {label(path)}")
    for line in attention:
        print(f"  {line}")
    return 2 if attention else 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--check", action="store_true", help="validate every registry and exit")
    sub = ap.add_subparsers(dest="command")
    add = sub.add_parser("add")
    add.add_argument("--title", required=True)
    add.add_argument("--severity", required=True, choices=SEVERITIES)
    add.add_argument("--surface", required=True)
    add.add_argument("--impact", required=True)
    add.add_argument("--fix", required=True)
    add.add_argument("--fixer", choices=FIXERS, default="person")
    add.add_argument("--source")
    add.add_argument("--notes")
    add.add_argument("--id")
    add.add_argument("--scope")
    accept = sub.add_parser("accept")
    accept.add_argument("id")
    accept.add_argument("--reason", required=True)
    accept.add_argument("--review-by", required=True)
    for name in ("reopen", "close"):
        sub.add_parser(name).add_argument("id")
    sub.add_parser("reviewed").add_argument("--scope")
    sub.add_parser("list").add_argument("--json", action="store_true")
    sub.add_parser("summary")
    args = ap.parse_args()

    if args.check:
        loaded, errors = load_all(strict=False)
        if errors:
            for e in errors:
                print(f"security-findings: {e}", file=sys.stderr)
            return 1
        print(f"{sum(len(d['findings']) for _, d in loaded)} finding(s) valid across {len(loaded)} registry(ies)")
        return 0
    handlers = {"add": cmd_add, "accept": cmd_accept, "reopen": cmd_reopen, "close": cmd_close,
                "reviewed": cmd_reviewed, "list": cmd_list, "summary": cmd_summary}
    if args.command not in handlers:
        ap.print_usage(sys.stderr)
        return 2
    return handlers[args.command](args) or 0


if __name__ == "__main__":
    sys.exit(main())
