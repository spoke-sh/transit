"""Automatic, nested timings for test preparation and owned fixture lifetimes."""
import argparse
from contextlib import ExitStack, contextmanager
from contextvars import ContextVar
from functools import lru_cache
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time

from runner.capture import provenance, run, write_json
from runner.paths import ROOT


class Recorder:
    def __init__(self, root=ROOT):
        destination = root / ".cache/checks/phases"
        destination.mkdir(parents=True, exist_ok=True)
        self.directory = Path(tempfile.mkdtemp(prefix=f"process-{os.getpid()}-", dir=destination))
        self.parents = ContextVar("phase_parents", default=())
        write_json(self.directory / "source.json", {"version": 1, **provenance(root),
                                                   "pid": os.getpid(), "parent_pid": os.getppid(),
                                                   "task": os.getenv("CI_FEEDBACK_TASK")})

    @contextmanager
    def phase(self, kind, owner):
        # Labels describe code boundaries, never arguments, credentials or data.
        assert all(re.fullmatch(r"[a-z0-9][a-z0-9_.-]*", value) for value in (kind, owner))
        handle, name = tempfile.mkstemp(prefix=f"{kind}-{owner}-", suffix=".json", dir=self.directory)
        os.close(handle)
        path = Path(name)
        parents = self.parents.get()
        row = {"version": 1, "kind": kind, "owner": owner, "parent": parents[-1] if parents else None,
               "started_unix": time.time(), "completed": False, "outcome": "incomplete"}
        started = time.monotonic()
        write_json(path, row)
        token = self.parents.set((*parents, path.name))
        try:
            yield row
        except BaseException as error:
            row.update(completed=False, outcome="failed", error=type(error).__name__)
            raise
        else:
            row.update(completed=True, outcome="passed")
        finally:
            self.parents.reset(token)
            row["seconds"] = time.monotonic() - started
            try:
                write_json(path, row)
            except OSError as error:
                recording_error(kind, owner, error)


@lru_cache(maxsize=1)
def recorder():
    return Recorder()


def recording_error(kind, owner, error):
    print(f"Incomplete phase evidence: {kind}/{owner} ({type(error).__name__}); "
          "timing qualification is unavailable.", file=sys.stderr, flush=True)


@contextmanager
def phase(kind, owner):
    # Timing is observation: failure cannot skip cleanup or turn a successful
    # __enter__ into an exception that leaves its new resources unowned. Preserve
    # the original scenario outcome and explicitly mark timing as unavailable.
    with ExitStack() as stack:
        try:
            row = stack.enter_context(recorder().phase(kind, owner))
        except OSError as error:
            recording_error(kind, owner, error)
            row = {}
        yield row


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("kind")
    parser.add_argument("owner")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command:
        parser.error("a command is required after --")
    try:
        with phase(args.kind, args.owner) as row:
            run(command, cwd=ROOT, log=recorder().directory / "command.log", result=row).check_returncode()
    except subprocess.CalledProcessError as error:
        raise SystemExit(error.returncode if error.returncode > 0 else 128 - error.returncode)


if __name__ == "__main__":
    main()
