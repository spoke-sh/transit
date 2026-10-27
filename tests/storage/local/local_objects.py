"""Independent, separate-process oracle for local object publication races."""
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile


def run(binary):
    binary = str(Path(binary).resolve())
    with tempfile.TemporaryDirectory(prefix="transit-local-objects-") as directory:
        def call(mode, key, expected="-", value="-"):
            result = subprocess.run(
                [binary, directory, mode, key, expected, value],
                check=True, capture_output=True, text=True, timeout=30,
            )
            assert not result.stderr, result.stderr
            return json.loads(result.stdout)

        def race(mode, key, expected="-"):
            values = [f"{mode}-{i}" for i in range(12)]
            with ThreadPoolExecutor(max_workers=len(values)) as pool:
                results = list(pool.map(lambda value: call(mode, key, expected, value), values))
            winners = [value for value, result in zip(values, results) if result["accepted"]]
            assert len(winners) == 1, results
            winner = winners[0]
            assert bytes.fromhex(call("read", key)["hex"]).decode() == winner
            return winner

        first = race("create", "manifest/concurrent.tman")
        expected = hashlib.sha256(first.encode()).hexdigest()
        second = race("replace", "manifest/concurrent.tman", expected)
        assert not call("replace", "manifest/concurrent.tman", expected, "stale")["accepted"]
        assert bytes.fromhex(call("read", "manifest/concurrent.tman")["hex"]).decode() == second
        immutable = race("immutable", "segments/concurrent.tseg")
        assert call("immutable", "segments/concurrent.tseg", value=immutable)["accepted"]
    print("Local objects: three 12-process publication races, exact immutable retry, stale CAS and fresh-process reads passed.")


if __name__ == "__main__":
    run(sys.argv[1])
