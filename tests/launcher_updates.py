"""Exercise artifact selection through actual launchers, without editing sources."""
import hashlib
import json
from pathlib import Path
import secrets
import shutil
import subprocess


def candidate(installation, artifact):
    """A distinct deployable build with identical application/state semantics."""
    from common import write, run
    artifacts = installation.artifacts
    values = artifacts.read("candidates")
    value = dict(artifacts.read("selected")[artifact])
    if installation.profile == "local":
        # Build a genuine Debug binary instead of the selected ReleaseSafe one.
        prefix = artifacts.path / "proof-debug"
        from common import ROOT
        run(["zig", "build", artifact, "-Doptimize=Debug", "--prefix", prefix], cwd=ROOT, timeout=600)
        source = prefix / "bin" / artifact
        with source.open("rb") as stream:
            sha = hashlib.file_digest(stream, "sha256").hexdigest()
        target = artifacts.path / "objects" / sha / artifact
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        target.chmod(0o555)
        value.update(path=str(target), sha256=sha)
    else:
        # A new immutable image exercises the provider's code-assignment
        # boundary without asserting that arbitrary new code is compatible.
        context = artifacts.path / "proof-image"
        context.mkdir(exist_ok=True)
        tag = "transit-update-proof:" + secrets.token_hex(12)
        run(["docker", "tag", value["image"], tag])
        write(context / "Dockerfile", f'FROM {tag}\nLABEL transit.proof="{secrets.token_hex(8)}"\n')
        iid = context / "id"
        run(["docker", "build", "--iidfile", iid, context], timeout=120)
        value["image"] = iid.read_text().strip()
    values[artifact] = value
    write(artifacts.path / "candidates.json", values)
    return value


def exercise(installation, launcher, invoke, observe):
    from updates import update
    from unittest.mock import patch
    first = observe(12)
    if installation.profile == "compose":
        from common import write
        file = installation.path / "compose.env.json"
        current = json.loads(file.read_text())
        legacy = {key: value for key, value in current.items() if key not in ("REY_COMPOSE_NODE_IMAGE", "REY_COMPOSE_BOARD_IMAGE", "REY_COMPOSE_COUNTER_IMAGE")}
        legacy["REY_COMPOSE_IMAGE_PREFIX"] = installation.load()["project"]
        try:
            write(file, legacy)
            assert launcher.services(), "pre-update installations must remain stoppable"
            rendered = json.loads(launcher.docker("config", "--format", "json", capture=True))
            assert rendered["services"]["node"]["image"] == legacy["REY_COMPOSE_IMAGE_PREFIX"] + "/transit-node"
        finally:
            write(file, current)

    def instances():
        return {row.get("name", row.get("Service")): row.get("pid", row.get("ID")) for row in launcher.services()}

    before = instances()
    invoke("build", "board")
    assert instances() == before, "build changed running services"
    assert "no changes" in invoke("update", "board", "--no-build")
    assert instances() == before, "no-op update restarted services"
    selected = installation.artifacts.read("selected")
    candidate(installation, "transit-board")
    invoke("restart", "board")
    assert installation.artifacts.read("selected") == selected, "restart selected a candidate"
    before = instances()
    # Preserve a pending operation before any service replacement, then resume
    # it via a fresh CLI process. New builds cannot overwrite that target.
    with patch.object(launcher, "apply_update", side_effect=RuntimeError("interrupted deployment")):
        try:
            update(launcher, ["board"], no_build=True)
        except RuntimeError as error:
            assert str(error) == "interrupted deployment"
    assert (installation.path / "update.json").exists()
    invoke("update", "board", "--no-build")
    after = instances()
    assert before["node"] == after["node"] and before["counter"] == after["counter"] and before["ursula"] == after["ursula"]
    assert before["board"] != after["board"]
    assert observe(12)["generation"] == first["generation"]
    assert "no changes" in invoke("update", "board", "--no-build")
    # Updating the same owned port from loopback to wildcard must not reject
    # the current listener as somebody else's process. It is replaced below.
    for host in ("0.0.0.0", "127.0.0.1"):
        invoke("update", "board", "--no-build", settings={"REY_BOARD_HOST": host})
        assert installation.board["host"] == host
        assert observe(12)["generation"] == first["generation"]
    candidate(installation, "example-counter")
    invoke("update", "counter", "--no-build")
    upgraded = observe(12)
    assert upgraded["pid"] == first["pid"] and upgraded["generation"] > first["generation"]
    assert upgraded["consumed"] == first["consumed"] and upgraded["revision"] == first["revision"]
    print(installation.profile + ": isolated candidates, no-op update, saved selection, interrupted apply and same-PID replacement passed.")
