"""Bounded Linux process resource observations for storage experiments."""
from pathlib import Path
import re


def metrics():
    return {"samples": 0, "rss_kib": None, "threads": None, "fds": None,
            "stack_kib": None, "read_bytes": None, "write_bytes": None}


def sample_process(pid, peak):
    """Report unavailable samples as null, never as zero resource use."""
    try:
        status = Path(f"/proc/{pid}/status").read_text()
        fds = len(list(Path(f"/proc/{pid}/fd").iterdir()))
    except (FileNotFoundError, ProcessLookupError, PermissionError):
        return
    peak["samples"] += 1
    for field, label in (("VmHWM", "rss_kib"), ("Threads", "threads"), ("VmStk", "stack_kib")):
        match = re.search(rf"^{field}:\s+(\d+)", status, re.M)
        if match:
            peak[label] = max(peak[label] or 0, int(match[1]))
    peak["fds"] = max(peak["fds"] or 0, fds)
    try:
        counters = Path(f"/proc/{pid}/io").read_text()
    except (FileNotFoundError, ProcessLookupError, PermissionError):
        return
    for field in ('read_bytes', 'write_bytes'):
        match = re.search(rf'^{field}:\s+(\d+)', counters, re.M)
        if match:
            peak[field] = max(peak[field] or 0, int(match[1]))


