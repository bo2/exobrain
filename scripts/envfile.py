"""envfile.py — read the instance's .env and update one key without ever leaving the
file half-written.

    import envfile
    env = envfile.load()                 # {KEY: VALUE} from KEY=VALUE lines
    envfile.save("SOME_TOKEN", value)    # replace or append the line

save() takes an exclusive lock on <path>.lock, re-reads the file under it, writes the
new content to a temporary file beside it (same mode, fsynced) and os.replace()s that
over .env, so a kill at any point leaves either the old file or the new one — never a
truncated one — and two scripts rotating tokens at once do not lose each other's
line. Other lines, comments and order are kept, and a symlinked .env (a worktree's)
is followed to the real file. Nothing here prints a value.

A script in this directory imports it directly: when run as `python3 scripts/x.py`,
sys.path[0] is scripts/. stdlib only.
"""

import fcntl
import os
import stat
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENV = os.path.join(ROOT, ".env")


def load(path=ENV):
    """KEY=VALUE lines as a dict; blank lines and # comments are ignored."""
    env = {}
    if os.path.exists(path):
        with open(path, encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    env[k.strip()] = v.strip()
    return env


def save(key, value, path=ENV):
    """Set KEY=VALUE in the file, atomically and under a lock."""
    # A worktree's .env is a symlink to the main checkout's: the lock, the temporary
    # file and the replace all go to the real file, or the link would become a copy.
    path = os.path.realpath(path)
    lock_path = path + ".lock"
    with open(lock_path, "a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            lines, mode = [], 0o600
            if os.path.exists(path):
                mode = stat.S_IMODE(os.stat(path).st_mode)
                with open(path, encoding="utf-8") as fh:
                    lines = fh.read().splitlines()
            for i, line in enumerate(lines):
                if line.startswith(key + "="):
                    lines[i] = f"{key}={value}"
                    break
            else:
                lines.append(f"{key}={value}")
            fd, tmp = tempfile.mkstemp(prefix=".env.", suffix=".tmp", dir=os.path.dirname(path) or ".")
            try:
                with os.fdopen(fd, "w", encoding="utf-8") as fh:
                    fh.write("\n".join(lines) + "\n")
                    fh.flush()
                    os.fsync(fh.fileno())
                os.chmod(tmp, mode)
                os.replace(tmp, path)
            except BaseException:
                try:
                    os.unlink(tmp)
                except OSError:
                    pass
                raise
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)
