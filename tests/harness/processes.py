"""Linux process discovery and bounded joining for owned fault fixtures."""
import os
from pathlib import Path
import time


def children(pid):
    result = set()
    for path in Path(f"/proc/{pid}/task").glob("*/children"):
        try:
            result.update(map(int, path.read_text().split()))
        except FileNotFoundError:
            pass
    return result


def command(pid):
    try:
        return Path(f"/proc/{pid}/cmdline").read_bytes().replace(b"\0", b" ").decode()
    except FileNotFoundError:
        return ""


def joined(pids, timeout=10):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        remaining = []
        for pid in pids:
            try:
                os.waitpid(pid, os.WNOHANG)  # Test subreaper joins children after manager SIGKILL.
            except ChildProcessError:
                pass
            if Path(f"/proc/{pid}").exists():
                remaining.append(pid)
        if not remaining:
            return
        time.sleep(0.05)
    raise AssertionError(f"Unjoined children: {remaining}")
