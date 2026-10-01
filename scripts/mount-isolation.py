#!/usr/bin/env python3
"""mount-isolation.py — the leak gate between this instance and its mounts.

Information from a root belongs to that root's audience, and landing it in
another root exposes it to that root's audience. A mount whose audience is
strictly narrower than the instance's is the private party: it gates every land
into the instance. Any other mount is the shared party — its people's writing is
what the instance's people chose to read by mounting it — and it is gated on every
land into it, against the instance and against every other mount whose audience
does not include all of its own. Equal audiences gate nothing. The gate scans what
the land adds — the added lines of every changed
file in the worktree (committed or not, _raw/ included), the branch's commit
messages, and any extra text handed in (a PR body, a session handover) — and exits
non-zero on a hit. Charters come from mounts.json (knowledge/exobrain/mounts.md § The
charter) merged with the gitignored local/mounts.json overlay of the main checkout.

  scripts/mount-isolation.py --worktree <dir> [--base <ref>] [--text <file>]... [--quiet]
  scripts/mount-isolation.py --worktree <dir> --lens      # the audience lens for the authoring review
  scripts/mount-isolation.py --worktree <dir> --plan      # which roots gate this land, and why

The target root is the repository the worktree belongs to: this instance, or the
mount whose checkout it was made from; --target <mount-name|instance> names it
instead. What a land into a mount may not carry:

  - a file under knowledge/<domain>/ where the charter does not hold <domain>, or a
    framework file (a mount is a content-only repository);
  - a term or pattern from a gated source's never list, or a card number or IBAN
    (checksum-validated, so an arbitrary digit run is not a hit). National
    identifiers, emails, and phone numbers are not built in: a charter lists the
    shapes that must stay out under never.patterns;
  - a reference into a gated source: its repository, its checkout path, a mount's
    name as a <mount>:<path> citation — and, in a mount, any <name>:<path> citation
    at all, since a mount has no mounts. The instance's own name is not matched:
    list it under never.terms when it must stay out.

A land into the instance is gated the same way against every private mount.

Exit: 0 clean · 1 the land carries what it may not · 2 usage or a charter that
cannot be read · 3 the worktree belongs to no root of this instance.
"""

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

INSTANCE = Path(__file__).resolve().parent.parent
MOUNT_NAME = re.compile(r"^[a-z0-9][a-z0-9-]*$")
FRAMEWORK_TOP = {"AGENTS.md", "CLAUDE.md", "CODEX.md", "OPENCLAW.md", "AGENTS.override.md",
                 "scripts", "skills", "people", "tools", "skills.json", "scopes.json",
                 "skills.schema.json", "mounts.json", "mounts.schema.json"}


def die(msg, code=2):
    print(f"mount-isolation: {msg}", file=sys.stderr)
    sys.exit(code)


def git(cwd, *args, check=True):
    r = subprocess.run(["git", "-C", str(cwd), *args], capture_output=True, text=True,
                       errors="replace")
    if check and r.returncode != 0:
        raise RuntimeError(r.stderr.strip() or f"git {' '.join(args)} failed")
    return r.stdout


def main_checkout(repo):
    """The checkout a worktree was made from — the parent of the shared git dir."""
    try:
        common = Path(git(repo, "rev-parse", "--git-common-dir").strip())
    except RuntimeError:
        return Path(repo).resolve()
    return (common if common.is_absolute() else Path(repo) / common).resolve().parent


def url_key(url):
    """A repository URL reduced to host/path, so its spellings compare equal."""
    u = url.strip()
    for p in ("file://", "ssh://", "https://", "http://", "git://"):
        if u.startswith(p):
            u = u[len(p):]
    if "@" in u:
        u = u.split("@", 1)[1]
    if not u.startswith("/"):
        u = u.replace(":", "/", 1)
    u = u.rstrip("/")
    if u.endswith(".git"):
        u = u[:-4]
    return u.lower()


# ---------------------------------------------------------------------------
# Charters
# ---------------------------------------------------------------------------

def never_merge(a, b):
    a, b = a or {}, b or {}
    return {k: list(a.get(k) or []) + list(b.get(k) or []) for k in ("topics", "terms", "patterns")}


def load_charters():
    """mounts.json merged with the main checkout's local/mounts.json overlay: never
    lists concatenate; everything else comes from the tracked file."""
    tracked = INSTANCE / "mounts.json"
    if not tracked.exists():
        die("this instance declares no mounts (no mounts.json)")
    try:
        data = json.load(open(tracked, encoding="utf-8"))
    except (OSError, ValueError) as e:
        die(f"cannot read mounts.json: {e}")
    overlay = {}
    local = main_checkout(INSTANCE) / "local" / "mounts.json"
    if local.exists():
        try:
            overlay = json.load(open(local, encoding="utf-8"))
        except (OSError, ValueError) as e:
            die(f"cannot read the local overlay {local}: {e}")
    inst = dict(data.get("instance") or {})
    inst["never"] = never_merge(inst.get("never"), (overlay.get("instance") or {}).get("never"))
    inst["audience"] = list(inst.get("audience") or [])
    mounts = []
    over_by_name = {m.get("name"): m for m in (overlay.get("mounts") or []) if isinstance(m, dict)}
    for m in data.get("mounts") or []:
        if not isinstance(m, dict) or not MOUNT_NAME.match(m.get("name", "")):
            continue
        m = dict(m)
        m["never"] = never_merge(m.get("never"), (over_by_name.get(m["name"]) or {}).get("never"))
        m["audience"] = list(m.get("audience") or [])
        m["holds"] = m.get("holds") if isinstance(m.get("holds"), dict) else {}
        mounts.append(m)
    return inst, mounts


def mount_state():
    """{name: checkout dir} for each mount this machine enabled, resolved as
    scripts/skills-registry.sh § Mounts does."""
    main = main_checkout(INSTANCE)
    cfg = INSTANCE / ".exobrain.json"
    if not cfg.exists():
        cfg = main / ".exobrain.json"
    try:
        state = json.load(open(cfg, encoding="utf-8")).get("mounts", {}) if cfg.exists() else {}
    except (OSError, ValueError):
        state = {}
    out = {}
    for name, entry in (state or {}).items():
        if not MOUNT_NAME.match(name) or not isinstance(entry, dict) or entry.get("enabled") is not True:
            continue
        path = entry.get("path") or ""
        if not path:
            checkout = main / "src" / name
        elif path == "~" or path.startswith("~/"):
            checkout = Path(os.path.expanduser(path))
        else:
            checkout = Path(path) if os.path.isabs(path) else main / path
        out[name] = checkout.resolve() if checkout.exists() else checkout
    return out


def instance_refs():
    """How this instance can be named from elsewhere: its repository, its checkout."""
    main = main_checkout(INSTANCE)
    refs = {"names": [], "urls": [], "paths": [str(main)]}
    try:
        url = git(main, "remote", "get-url", "origin").strip()
        if url:
            refs["urls"].append(url_key(url))
    except RuntimeError:
        pass
    return refs


# ---------------------------------------------------------------------------
# Roots and the plan
# ---------------------------------------------------------------------------

class Root:
    def __init__(self, label, audience, never, purpose="", holds=None, is_mount=False,
                 cite_names=(), urls=(), paths=()):
        self.label = label
        self.audience = list(audience)
        self.never = never or {"topics": [], "terms": [], "patterns": []}
        self.purpose = purpose
        self.holds = holds or {}
        self.is_mount = is_mount
        self.cite_names = list(cite_names)
        self.urls = list(urls)
        self.paths = list(paths)


def build_roots(inst, mounts):
    state = mount_state()
    iref = instance_refs()
    roots = {"instance": Root("this instance", inst["audience"], inst["never"],
                              purpose="this instance's own knowledge and workspaces",
                              urls=iref["urls"], paths=iref["paths"], cite_names=iref["names"])}
    for m in mounts:
        urls = [url_key(m.get("repo", ""))] if m.get("repo") else []
        paths = [str(state[m["name"]])] if m["name"] in state else []
        roots[m["name"]] = Root(m["name"], m["audience"], m["never"], purpose=m.get("purpose", ""),
                                holds=m["holds"], is_mount=True, cite_names=[m["name"]],
                                urls=urls, paths=paths)
    return roots


def resolve_target(worktree, roots, named):
    if named:
        if named not in roots:
            die(f"'{named}' is neither 'instance' nor a declared mount")
        return named
    wt_main = main_checkout(worktree)
    if wt_main == main_checkout(INSTANCE):
        return "instance"
    for name, root in roots.items():
        if root.is_mount and root.paths and Path(root.paths[0]).resolve() == wt_main:
            return name
    die(f"{worktree} belongs to neither this instance nor one of its enabled mounts", 3)


def is_private(mount, inst):
    """A mount whose audience is strictly inside the instance's is the private party."""
    return set(mount.audience) < set(inst.audience)


def gated_sources(target, roots):
    """The roots a land into <target> is gated against: for the instance, its private
    mounts; for a mount, the instance when the mount is the shared party, plus every
    other mount whose audience does not include all of the target's."""
    t, inst = roots[target], roots["instance"]
    out = []
    for name, r in roots.items():
        if name == target:
            continue
        if not t.is_mount:
            if is_private(r, inst):
                out.append(r)
        elif not r.is_mount:
            if not set(t.audience) <= set(inst.audience):
                out.append(r)
        elif set(t.audience) != set(r.audience) and any(p not in r.audience for p in t.audience):
            out.append(r)
    return out


# ---------------------------------------------------------------------------
# What the land adds
# ---------------------------------------------------------------------------

def changed_paths(worktree, base):
    paths = set()
    if base:
        paths.update(p for p in git(worktree, "diff", "--name-only", f"{base}...HEAD", check=False).split("\n") if p)
    for line in git(worktree, "status", "--porcelain", "--untracked-files=all").split("\n"):
        if not line:
            continue
        p = line[3:]
        if " -> " in p:
            p = p.split(" -> ", 1)[1]
        paths.add(p)
    return sorted(paths)


def is_text(data):
    if b"\0" in data:
        return False
    try:
        data.decode("utf-8")
    except UnicodeDecodeError:
        return False
    return True


def added_lines(worktree, base, path):
    """[(line number, text)] this land adds to <path>, against <base>'s version."""
    full = Path(worktree) / path
    if not full.is_file() or full.is_symlink():
        return []
    data = full.read_bytes()
    if not is_text(data):
        return []
    tracked_at_base = False
    if base:
        r = subprocess.run(["git", "-C", str(worktree), "cat-file", "-e", f"{base}:{path}"],
                           capture_output=True)
        tracked_at_base = r.returncode == 0
    if not tracked_at_base:
        return list(enumerate(data.decode("utf-8").split("\n"), 1))
    diff = git(worktree, "diff", "-U0", "--no-color", base, "--", path, check=False)
    out, lineno = [], 0
    for line in diff.split("\n"):
        if line.startswith("@@"):
            m = re.search(r"\+(\d+)", line)
            lineno = int(m.group(1)) if m else 0
        elif line.startswith("+") and not line.startswith("+++"):
            out.append((lineno, line[1:]))
            lineno += 1
    return out


def commit_messages(worktree, base):
    if not base:
        return ""
    return git(worktree, "log", "--format=%B", f"{base}..HEAD", check=False)


# ---------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------

def luhn_ok(digits):
    total, alt = 0, False
    for d in reversed(digits):
        n = int(d)
        if alt:
            n *= 2
            if n > 9:
                n -= 9
        total += n
        alt = not alt
    return total % 10 == 0


def iban_ok(s):
    s = s.upper()
    if not (15 <= len(s) <= 34):
        return False
    rearranged = s[4:] + s[:4]
    try:
        n = int("".join(str(int(c, 36)) for c in rearranged))
    except ValueError:
        return False
    return n % 97 == 1


CARD_RE = re.compile(r"(?<![\w-])(?:\d[ -]?){12,18}\d(?![\w-])")
IBAN_RE = re.compile(r"(?<![A-Za-z0-9])[A-Z]{2}\d{2}[A-Z0-9]{11,30}(?![A-Za-z0-9])")


def builtin_hits(text):
    hits = []
    for m in CARD_RE.finditer(text):
        digits = re.sub(r"[ -]", "", m.group(0))
        if 13 <= len(digits) <= 19 and luhn_ok(digits):
            hits.append(("card number", m.group(0)))
    for m in IBAN_RE.finditer(text):
        if iban_ok(m.group(0)):
            hits.append(("IBAN", m.group(0)))
    return hits


class Gate:
    def __init__(self, target, roots, sources):
        self.target = target
        self.root = roots[target]
        self.sources = sources
        self.findings = []
        self.term_res = []      # (source, term, regex)
        self.pattern_res = []   # (source, pattern, regex)
        for s in sources:
            for t in s.never.get("terms", []):
                if t.strip():
                    self.term_res.append((s, t, re.compile(r"(?<!\w)" + re.escape(t) + r"(?!\w)", re.I)))
            for p in s.never.get("patterns", []):
                try:
                    self.pattern_res.append((s, p, re.compile(p, re.I)))
                except re.error as e:
                    die(f"charter of {s.label}: pattern {p!r} does not compile: {e}")
        self.ref_res = []       # (source, kind, regex)
        for s in sources:
            for n in s.cite_names:
                if s.is_mount:
                    self.ref_res.append((s, f"citation into {s.label}",
                                         re.compile(r"(?<![\w-])" + re.escape(n) + r":(knowledge|workspaces|README\.md)", re.I)))
                else:
                    self.ref_res.append((s, f"name of {s.label}",
                                         re.compile(r"(?<![\w-])" + re.escape(n) + r"(?![\w-])", re.I)))
            for u in s.urls:
                self.ref_res.append((s, f"repository of {s.label}", re.compile(re.escape(u), re.I)))
            for p in s.paths:
                self.ref_res.append((s, f"checkout of {s.label}", re.compile(re.escape(p))))
        self.any_cite_re = re.compile(r"(?<![\w-])[a-z0-9][a-z0-9-]*:(knowledge|workspaces)/") if self.root.is_mount else None

    def add(self, where, kind, detail, source=None):
        src = f" (source: {source.label})" if source else ""
        self.findings.append(f"{where} — {kind}: {detail}{src}")

    def check_path(self, path):
        if not self.root.is_mount:
            return
        top = path.split("/", 1)[0]
        if top in FRAMEWORK_TOP:
            self.add(path, "framework file", "a mount is a content-only repository")
            return
        if top == "knowledge":
            parts = path.split("/")
            if len(parts) >= 3:
                domain = parts[1]
                if domain not in self.root.holds:
                    self.add(path, "outside the charter",
                             f"knowledge/{domain} is not among the domains {self.root.label} holds ({', '.join(self.root.holds) or 'none'})")

    def check_lines(self, where_prefix, lines):
        for lineno, text in lines:
            if not text.strip():
                continue
            where = f"{where_prefix}:{lineno}" if lineno else where_prefix
            for s, term, rx in self.term_res:
                if rx.search(text):
                    self.add(where, "never term", repr(term), s)
            for s, pat, rx in self.pattern_res:
                if rx.search(text):
                    self.add(where, "never pattern", repr(pat), s)
            for kind, match in builtin_hits(text):
                self.add(where, kind, match)
            for s, kind, rx in self.ref_res:
                if rx.search(text):
                    self.add(where, kind, rx.search(text).group(0), s)
            if self.any_cite_re and self.any_cite_re.search(text):
                m = self.any_cite_re.search(text).group(0)
                if not any(rx.search(text) for _, k, rx in self.ref_res if k.startswith("citation")):
                    self.add(where, "citation form in a mount",
                             f"{m}… — a mount has no mounts and never references what mounts it")


# ---------------------------------------------------------------------------
# Lens
# ---------------------------------------------------------------------------

def lens_text(target, roots, sources):
    t = roots[target]
    out = [f"Audience lens: this diff lands in {t.label}, readable by {', '.join(t.audience) or 'nobody named'}.",
           "Judge every added line with that audience in mind."]
    if t.is_mount:
        out.append(f"The target's purpose: {t.purpose.rstrip('.')}. It holds: "
                   + "; ".join(f"{d} — {desc.rstrip('.')}" for d, desc in t.holds.items()) + ".")
        out.append("A changed line that falls outside that purpose does not belong there.")
    if sources:
        out.append("It must not state a fact whose home is one of these roots, whose audience "
                   "is not all of the target's:")
        for s in sources:
            topics = "; ".join(s.never.get("topics", [])) or "(no topics listed)"
            out.append(f"- {s.label} (readable by {', '.join(s.audience) or 'nobody named'}): {s.purpose}. Never in the target: {topics}")
        out.append("Flag such a line as: <path>: audience boundary -- <what to move or cut>.")
    wider = [r for name, r in roots.items() if name != target and r.is_mount and r not in sources]
    if wider and not t.is_mount:
        out.append("Facts whose home is a mounted domain are cited, never restated. Mounted domains: "
                   + "; ".join(f"{r.label} — {r.purpose} (holds {', '.join(r.holds)})" for r in wider)
                   + ". Flag a changed line that restates such a fact as: <path>: drift -- cite it as <mount>:<path> instead.")
    return "\n".join(out)


# ---------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(add_help=False)
    ap.add_argument("--worktree")
    ap.add_argument("--target")
    ap.add_argument("--base")
    ap.add_argument("--text", action="append", default=[])
    ap.add_argument("--lens", action="store_true")
    ap.add_argument("--plan", action="store_true")
    ap.add_argument("--quiet", action="store_true")
    ap.add_argument("-h", "--help", action="store_true")
    args = ap.parse_args()
    if args.help:
        print(__doc__.strip())
        return 0
    if not args.worktree and not args.target:
        die("--worktree <dir> (or --target) is required")
    worktree = Path(args.worktree).resolve() if args.worktree else None
    if worktree and not worktree.is_dir():
        die(f"not a directory: {worktree}")

    inst, mounts = load_charters()
    roots = build_roots(inst, mounts)
    target = resolve_target(worktree, roots, args.target) if (worktree or args.target) else "instance"
    sources = gated_sources(target, roots)

    if args.lens:
        print(lens_text(target, roots, sources))
        return 0
    if args.plan:
        t = roots[target]
        print(f"target: {t.label} (readable by {', '.join(t.audience) or 'nobody named'})")
        if sources:
            for s in sources:
                missing = [p for p in t.audience if p not in s.audience]
                print(f"gated against: {s.label} (readable by {', '.join(s.audience) or 'nobody named'}) — "
                      f"{', '.join(missing) or 'nobody'} may not read it; {len(s.never['terms'])} term(s), {len(s.never['patterns'])} pattern(s)")
        else:
            print("gated against: nothing — no root is private relative to the target")
        return 0

    if not worktree:
        die("--worktree <dir> is required to scan")
    base = args.base
    if base and subprocess.run(["git", "-C", str(worktree), "rev-parse", "--verify", "--quiet", base],
                               capture_output=True).returncode != 0:
        die(f"base ref {base!r} does not resolve in {worktree}")

    # Line-level checks (terms, patterns, checksummed numbers, references) run only
    # when some root gates this land: a land that crosses no audience boundary may
    # carry anything its own audience may read. The charter's path checks always
    # apply to a mount.
    gate = Gate(target, roots, sources)
    for path in changed_paths(worktree, base):
        gate.check_path(path)
        if sources:
            gate.check_lines(path, added_lines(worktree, base, path))
    if sources:
        msgs = commit_messages(worktree, base)
        if msgs.strip():
            gate.check_lines("commit message", list(enumerate(msgs.split("\n"), 1)))
        for tf in args.text:
            p = Path(tf)
            if p.is_file():
                gate.check_lines(f"text {p.name}", list(enumerate(p.read_text(encoding="utf-8", errors="replace").split("\n"), 1)))

    t = roots[target]
    if gate.findings:
        if not args.quiet:
            print(f"mount-isolation: {len(gate.findings)} finding(s) — this land into {t.label} "
                  f"(readable by {', '.join(t.audience)}) carries what it may not:")
            for f in gate.findings:
                print(f"  - {f}")
            print("Move the material to the root whose audience may read it, or cut it (knowledge/exobrain/mounts.md § Isolation).")
        return 1
    if not args.quiet:
        gated = ", ".join(s.label for s in sources) or "nothing (no narrower root)"
        print(f"mount-isolation: clean — target {t.label}, gated against {gated}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except RuntimeError as e:
        die(str(e))
