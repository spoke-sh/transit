#!/usr/bin/env python3
"""Disk-backed Ursula conformance and SIGKILL recovery schedules."""
from pathlib import Path
import signal
import subprocess
import sys
import time

from harness.ursula import Fixture


PROOFS = ("storage", "kernel", "effects", "lifetime", "outbox", "runtime", "deletion", "state", "readiness")


def run(binaries):
    commands = (
        [(f"transit-{name}-proof", [str(binaries[0]), name]) for name in PROOFS]
        if len(binaries) == 1
        else [(binary.name, [str(binary)]) for binary in binaries]
    )
    with Fixture() as fixture:
        for index, phase in enumerate(("write", "recover", "checkpoint", "trim_recover")):
            if index:
                fixture.start()
            for label, prefix in commands:
                # These phases include hundreds of durable paged transactions:
                # reclamation and draining recovered input both exceed the old
                # bounded-profile budget on physical disk. Keep a finite cap
                # and record each phase's actual cost.
                budget = 600
                started = time.monotonic()
                subprocess.run([*prefix, fixture.url, phase], env=fixture.env, check=True, timeout=budget)
                print(f"Disk {label}/{phase}: {time.monotonic()-started:.2f}s", flush=True)
            # SIGKILL tests the WAL boundary, not graceful shutdown flushes.
            fixture.stop()
    print("Disk WAL survives SIGKILL; one conditional successor and bounded replay verified.")


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *_: (_ for _ in ()).throw(KeyboardInterrupt()))
    run([Path(arg).resolve(strict=True) for arg in sys.argv[1:]])
