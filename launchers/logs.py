"""Bound the pinned manager's append-only internal log separately from child logs."""
import os
from pathlib import Path
import time

LIMIT = 5 * 1024 * 1024


def rotate(path, force=False):
    if not path.exists() or not path.stat().st_size or (not force and path.stat().st_size < LIMIT):
        return False
    # Process Compose v1.110.0 opens this file with O_APPEND but offers no
    # internal-log rotation. Preserve its inode and retain a bounded tail.
    # Writes racing copy/truncate can be lost: these are diagnostic files.
    with path.open("r+b") as source:
        source.seek(max(0, os.fstat(source.fileno()).st_size - LIMIT))
        remaining = LIMIT
        temporary = path.with_name(path.name + ".rotating")
        with temporary.open("wb") as destination:
            while remaining:
                chunk = source.read(min(65536, remaining))
                if not chunk:
                    break
                destination.write(chunk)
                remaining -= len(chunk)
        first = path.with_name(path.name + ".1")
        if first.exists():
            first.replace(path.with_name(path.name + ".2"))
        temporary.replace(first)
        source.truncate(0)
    return True


def maintain(directory):
    while True:
        for name in ("manager.log", "manager-client.log"):
            if rotate(directory / name):
                print(f"Rotated {name}; retained two bounded backups", flush=True)
        time.sleep(1)
