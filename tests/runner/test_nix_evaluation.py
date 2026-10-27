"""Exercise the real flake evaluator while its private evaluation cache is locked."""
import os
from pathlib import Path
import sqlite3
import subprocess
import tempfile

def main():
    with tempfile.TemporaryDirectory(prefix="transit-nix-evaluation-") as directory:
        root = Path(directory)
        fixture = root / "fixture"
        fixture.mkdir()
        (fixture / "flake.nix").write_text(
            '{ outputs = { self }: { value = "transit-evaluation-control"; }; }\n'
        )
        cache = root / "cache"
        env = os.environ | {"XDG_CACHE_HOME": str(cache)}
        command = ["nix", "eval", "--raw", f"path:{fixture}#value", "--no-write-lock-file"]

        def evaluate(enabled, timeout=60):
            return subprocess.run(
                [*command, "--option", "eval-cache", str(enabled).lower()],
                cwd=root, env=env, capture_output=True, text=True, timeout=timeout,
            )

        initial = evaluate(True)
        initial.check_returncode()
        databases = sorted(cache.glob("nix/eval-cache-*/*.sqlite"))
        assert databases, "No isolated flake evaluation cache was created"
        locks = []
        try:
            # Lock only our private databases. Never disrupt contributor caches
            # or rely on another build happening to hold the original lock.
            for path in databases:
                connection = sqlite3.connect(path)
                connection.execute("BEGIN EXCLUSIVE")
                locks.append(connection)
            try:
                blocked = evaluate(True, timeout=2)
            except subprocess.TimeoutExpired:
                pass
            else:
                raise AssertionError(("Control did not encounter the held lock", blocked))
            independent = evaluate(False)
            independent.check_returncode()
            assert independent.stdout == initial.stdout == "transit-evaluation-control"
        finally:
            for connection in locks:
                connection.rollback()
                connection.close()
        released = evaluate(True)
        released.check_returncode()
        assert released.stdout == initial.stdout
    print("Nix evaluation: held private cache blocks cached evaluation; bypass and released cache preserve the evaluated value")


if __name__ == "__main__":
    main()
