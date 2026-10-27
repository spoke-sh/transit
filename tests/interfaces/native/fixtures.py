"""A second language checks committed canonical request/signature vectors."""
from runner.paths import ROOT
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile


def run(cli):
    source = ROOT / "packages/zig/transit-protocol/src/fixtures/requests-v1.json"
    vectors = json.loads(source.read_text())
    assert vectors["version"] == 1
    with tempfile.TemporaryDirectory(prefix="transit-vectors-") as directory:
        root = Path(directory)
        seed = root / "test-seed"
        seed.write_text(vectors["seed_hex"])
        seed.chmod(0o600)
        for vector in vectors["cases"]:
            request = json.loads(vector["canonical"])
            canonical = json.dumps(request, separators=(",", ":"))
            assert canonical == vector["canonical"]
            assert hashlib.sha256(b"transit.request.v1\0" + canonical.encode()).hexdigest() == vector["sha256"]
            path = root / "request.json"
            path.write_text(canonical)
            signed = json.loads(subprocess.check_output([str(cli), "sign", str(seed), str(path)], timeout=10))
            assert signed == {"request": request, "signature": vector["signature"]}
    print("Shared JSON vectors: Python canonical bytes/hash and Zig signatures agree.")
