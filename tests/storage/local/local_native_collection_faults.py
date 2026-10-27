"""Kill the exclusive native collector; verify exact physical reclamation."""
from runner.paths import ROOT
import hashlib
import json
from pathlib import Path
import selectors
import shutil
import signal
import struct
import subprocess
import sys
import tempfile


def run(binary, profile="native"):
    binary = str(Path(binary).resolve())
    assert profile in ("native", "direct"), profile
    suffix = ["direct"] if profile == "direct" else []
    definition = bytes.fromhex(json.loads(
        (ROOT / "contracts/transit-v1.schema.json").read_text()
    )["x-transit"]["definition"])

    def call(directory, operation):
        result = subprocess.run([binary, str(directory), operation, "none", *suffix],
                                capture_output=True, text=True, timeout=120)
        assert result.returncode == 0, (operation, result.stderr)
        assert not result.stderr, result.stderr
        return json.loads(result.stdout)

    with tempfile.TemporaryDirectory(prefix="transit-native-collection-") as temporary:
        root = Path(temporary)
        original = root / "original"
        expected = call(original, "init")
        allocation_directory = "data-allocations" if profile == "direct" else "native-allocations"
        marker = (original / allocation_directory / expected["allocation"]).read_bytes()
        payload = (b"TNAT\x01b\0\0" + definition if profile == "native" else b"") + b"unaccepted bytes"
        assert marker[8:40] == definition and struct.unpack_from("<Q", marker, 40)[0] == 1
        if profile == "native":
            assert len(marker) == 160 and marker[:8] == b"TALLOC1\0"
            assert marker[48:56] == b"b" + bytes(7)
            assert marker[56:88].hex() == expected["key"].split("/")[-1]
            assert struct.unpack_from("<Q", marker, 88)[0] == len(payload)
            assert marker[96:128] == hashlib.sha256(payload).digest()
            assert marker[128:] == hashlib.sha256(marker[:128]).digest()
        else:
            assert len(marker) == 512 and marker[:8] == b"TDALLOC1"
            key = expected["key"].encode()
            assert struct.unpack_from("<H", marker, 48)[0] == len(key)
            assert marker[50:56] == bytes(6)
            assert struct.unpack_from("<Q", marker, 56)[0] == len(payload)
            assert marker[64:96] == hashlib.sha256(payload).digest()
            assert marker[96:96 + len(key)] == key
            assert marker[96 + len(key):480] == bytes(384 - len(key))
            assert marker[-32:] == hashlib.sha256(marker[:-32]).digest()
        probe = root / "probe"
        shutil.copytree(original, probe)
        counts = call(probe, "delete")
        assert counts["deletes"] == 4 and 5 <= counts["syncs"] <= 12, counts
        points = ([f"sync-{i}" for i in range(1, counts["syncs"] + 1)] +
                  [f"delete-{i}" for i in range(1, 5)] + ["publish", "state", "ack"])
        key_hash = hashlib.sha256(expected["key"].encode()).hexdigest()
        content = f'{key_hash}-{expected["digest"]}'
        extension = ".tseg" if profile == "direct" else ".data"
        physical_paths = [Path("keys") / key_hash,
                          Path("objects") / (content + extension),
                          Path("objects") / (content + ".checks"),
                          Path(allocation_directory) / expected["allocation"]]
        assert all((original / path).is_file() for path in physical_paths)
        for point in points:
            directory = root / point
            shutil.copytree(original, directory)
            with subprocess.Popen([binary, str(directory), "delete", point, *suffix],
                                  stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                  stderr=subprocess.PIPE, text=True) as child:
                try:
                    with selectors.DefaultSelector() as ready:
                        ready.register(child.stdout, selectors.EVENT_READ)
                        assert ready.select(60), (point, "boundary not reached")
                    assert child.stdout.readline() == '{"stopped":true}\n', point
                    assert child.poll() is None, (point, "not a process death")
                    child.kill()
                    assert child.wait(timeout=10) == -signal.SIGKILL
                    assert child.stdout.read() == "" and child.stderr.read() == ""
                finally:
                    if child.poll() is None:
                        child.kill()
                        child.wait(timeout=10)
            recovered = call(directory, "recover")
            assert recovered["position"] == expected["position"], (point, recovered)
            assert recovered["phase"] == "complete", (point, recovered)
            if profile == "native":
                assert recovered["reclaimed"] > expected["previous_reclaimed"], (point, recovered)
            # Direct counters count confirmed removal replies. A process death
            # can lose that observation; physical absence is the oracle below.
            for path in physical_paths:
                assert not (directory / path).exists(), (point, path)
            assert call(directory, "recover") == recovered, point
    print(f"Local {profile} collection: {len(points)} SIGKILL schedules preserve accepted "
          "roots and unrelated objects, resume exact deletion/FIFO progress, and "
          "remove the descriptor, payload, checksums and allocation marker.")


if __name__ == "__main__":
    run(*sys.argv[1:])
