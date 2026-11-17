#!/usr/bin/env python3
"""Native disk semantic proofs with explicit completion and SIGKILL recovery."""
from pathlib import Path
import signal
import select
import subprocess
import sys
import time

from harness.native import Fixture


PROOFS = ("storage", "kernel", "effects", "lifetime", "outbox", "runtime", "deletion", "state", "readiness")


def run(binaries):
    commands = (
        [(f"transit-{name}-proof", [str(binaries[0]), name]) for name in PROOFS]
        if len(binaries) == 1
        else [(binary.name, [str(binary)]) for binary in binaries]
    )
    with Fixture(retain_on_failure=True) as fixture:
        for index, phase in enumerate(("write", "recover", "checkpoint", "trim_recover")):
            for label, prefix in commands:
                # These phases include hundreds of durable paged transactions:
                # reclamation and draining recovered input both exceed the old
                # bounded-profile budget on physical disk. Keep a finite cap
                # and record each phase's actual cost.
                budget = 600
                started = time.monotonic()
                log = fixture.root / f'{label}-{phase}.log'
                with log.open('w+b') as stderr:
                    child = subprocess.Popen([*prefix, str(fixture.native_directory), phase], env=fixture.env,
                                             stdout=subprocess.PIPE, stderr=stderr)
                    try:
                        assert select.select([child.stdout], [], [], budget)[0], f'{label}/{phase} completion deadline'
                        marker = child.stdout.readline()
                        assert marker == b'native-proof-complete\n', (label, phase, marker, log.read_text()[-5000:])
                        child.kill()
                        assert child.wait(timeout=10) == -signal.SIGKILL
                    finally:
                        if child.poll() is None: child.kill()
                        child.wait(timeout=10)
                        child.stdout.close()
                print(f"Disk {label}/{phase}: {time.monotonic()-started:.2f}s", flush=True)
    print("Disk WAL survives SIGKILL; one conditional successor and bounded replay verified.")


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *_: (_ for _ in ()).throw(KeyboardInterrupt()))
    run([Path(arg).resolve(strict=True) for arg in sys.argv[1:]])
