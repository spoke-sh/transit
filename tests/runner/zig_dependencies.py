"""Fetch pinned Zig dependencies before compilation, retrying transport failures only."""
from pathlib import Path
import re
import signal
import threading
import time

from capture import directory, provenance, run, write_json

ROOT = Path(__file__).resolve().parents[2]
DELAYS = (5, 15, 30)
ATTEMPT_SECONDS = 120
TRANSPORT_ERRORS = {
    "NameServerFailure", "TemporaryNameServerFailure", "UnknownHostName",
    "ConnectionTimedOut", "ConnectionResetByPeer", "ConnectionRefused",
    "NetworkUnreachable",
}


def transient(diagnostics):
    errors = re.findall(r"\berror: ([^\n]+)", diagnostics)
    # A mixed manifest/hash and network failure must still fail immediately.
    return bool(errors) and all(error.rsplit(": ", 1)[-1] in TRANSPORT_ERRORS for error in errors)


def prepare(root=ROOT, *, delays=DELAYS, attempt_seconds=ATTEMPT_SECONDS):
    destination = root / ".cache/ci/zig-dependencies.json"
    artifacts = directory(destination)
    report = {"version": 1, **provenance(root), "completed": False,
              "run_directory": str(artifacts.relative_to(destination.parent)), "attempts": []}

    def checkpoint():
        write_json(artifacts / "preparation.json", report)
        write_json(destination, report)

    for attempt in range(len(delays) + 1):
        entry = {"attempt": attempt + 1, "timeout_seconds": attempt_seconds,
                 "completed": False, "exit_code": None}
        report["attempts"].append(entry)
        checkpoint()
        log = artifacts / f"{attempt + 1:03d}.log"
        expired = threading.Event()
        timer = threading.Timer(attempt_seconds, expired.set)
        started = time.monotonic()
        print(f"Fetch pinned Zig dependencies: attempt {attempt + 1}/{len(delays) + 1}", flush=True)
        timer.start()
        try:
            # --fetch=all exits before compiling/running build.zig or any tests.
            result = run(["zig", "build", "--fetch=all", "--color", "off"],
                         cwd=root, log=log, result=entry, cancelled=expired)
            code = result.returncode
            retry = (code > 0 and not entry["diagnostics"]["omitted_bytes"]
                     and transient(log.read_text(errors="replace")))
        except InterruptedError:
            code, retry = 124, True
            entry["timed_out"] = True
            print("Zig dependency fetch exceeded its attempt deadline.", flush=True)
        finally:
            timer.cancel()
            timer.join()
            entry["seconds"] = round(time.monotonic() - started, 3)
            checkpoint()
        if code == 0:
            report["completed"] = True
            checkpoint()
            return 0
        if not retry or attempt == len(delays):
            return code
        print(f"Transient dependency transport failure; retrying fetch in {delays[attempt]}s.", flush=True)
        time.sleep(delays[attempt])
    raise AssertionError("unreachable")


if __name__ == "__main__":
    def interrupt(signum, frame):
        raise KeyboardInterrupt

    signal.signal(signal.SIGTERM, interrupt)
    try:
        raise SystemExit(prepare())
    except KeyboardInterrupt:
        raise SystemExit(130)
