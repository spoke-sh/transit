"""Persistent Station example through the same local/Compose/reference entry point."""
import json
import os
from pathlib import Path
import secrets
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "launchers"))
from common import HTTP, run, write
from station_example import StationInstallation
from launchers import ports


def exercise(profile, name=None, base=None, existing=False):
    from local import Local
    from compose import Compose
    from station_reference import StationReference
    installation = StationInstallation(profile, name or "station-" + secrets.token_hex(3), base or ports())
    launcher = {"local": Local, "compose": Compose, "reference": StationReference}[profile](installation)
    env = {key: value for key, value in os.environ.items() if not key.startswith("REY_") and key not in ("LOG_LEVEL", "LOG_FORMAT")}

    def invoke(action, *arguments):
        command = [sys.executable, "-B", ROOT / "launchers/main.py", profile, action, "--name", installation.name, *arguments]
        result = subprocess.run(list(map(str, command)), env=env, capture_output=True, text=True, timeout=1200)
        if result.returncode: raise RuntimeError(result.stdout[-2000:] + result.stderr[-3000:])
        return result.stdout

    def entry(role, key):
        query = installation.path / "operator/proof-state.json"
        write(query, {"realm": installation.load()["realm"], "principal": 0, "kind": "entries",
                      "resource": installation.records()[role]["resource"], "key": key.hex()})
        page = json.loads(run([installation.cli, "state", installation.path / "operator/root.key", query, installation.url], capture=True))
        value = page["entries"][0]
        return bytes.fromhex(value["value"]) if value else None

    def total():
        value = entry("ledger", b"\x00r" + (1).to_bytes(4, "little") + ((1 << 63) + 1).to_bytes(8, "big"))
        return int.from_bytes(value[2:], "little", signed=True) if value else 0

    def await_value(predicate, description, seconds=60):
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            if predicate(): return
            time.sleep(.2)
        raise AssertionError(description)

    def board(path):
        for _ in range(60):
            try:
                with HTTP.open(urllib.request.Request(installation.board_url + "/api/v1/" + path, headers=installation.board_headers), timeout=8) as response:
                    return json.load(response)
            except urllib.error.HTTPError as error:
                if error.code == 409: raise CutExpired() from error
                if error.code not in (409, 429, 503): raise
                time.sleep(.2)
        raise AssertionError("Board observation did not settle")

    class CutExpired(Exception):
        pass

    def framework(record):
        path = f'resources/{record["resource"]}/entries'
        for _ in range(30):
            kinds = set()
            try:
                response = board(path)
                while True:
                    for lens in response["framework"]:
                        if lens:
                            assert lens["source"]["pid"] == record["pid"] and lens["source"]["resource"] == record["resource"]
                            kinds.update(lens["declaration"])
                    page = response["observation"]
                    if page["next"] is None: return kinds
                    response = board(path + "?" + urllib.parse.urlencode({"after": page["next"], **page["cut"]}))
            except CutExpired:
                # Concurrent controller/output progress invalidates the whole
                # snapshot. Never retry one old cursor or stitch different cuts.
                time.sleep(.2)
        raise AssertionError("No stable bounded framework observation")

    try:
        if not existing:
            invoke("up", "--example", "station", "--base-port", str(installation.base_port), "--detach")
        await_value(lambda: total() == 12, "Initial Station Tables did not materialize")
        records = installation.records()
        before = {role: installation.process(role) for role in installation.workloads}
        lookup = json.loads(invoke("send", "lookup", "--request-id", "proof-lookup"))["admitted_at"]
        resolved_key = b"\x00r" + lookup.to_bytes(8, "little") + b"\x00"
        await_value(lambda: entry("requester", resolved_key) is not None, "Registry route did not resolve the ledger PID")
        assert int.from_bytes(entry("requester", resolved_key)[24:32], "little") == records["ledger"]["pid"]
        invoke("send", "-2", "--request-id", "proof-delta")
        invoke("send", "-2", "--request-id", "proof-delta")
        await_value(lambda: total() == 10 and entry("requester", b"answer") == b"10", "Correlated delta/retry was not atomic")
        invoke("send", "query", "--request-id", "proof-query")
        await_value(lambda: entry("requester", b"last-query") is not None, "Arrow reply did not complete")
        if profile == "reference":
            process = installation.process("ledger")
            worker = process["binding"]["activation"]["worker_incarnation"]
            pods = json.loads(launcher.kube("get", "pods", "-o", "json", capture=True))["items"]
            pod = next(p for p in pods if list(uuid.UUID(p["metadata"]["uid"]).bytes) == worker)
            launcher.kube("delete", "pod", pod["metadata"]["name"], "--grace-period=0", "--force")
            invoke("send", "3", "--request-id", "proof-after-loss")
            await_value(lambda: total() == 13, "Substrate Station worker did not recover", seconds=240)
            replacement = installation.process("ledger")
            assert replacement["binding"]["incarnation"] == process["binding"]["incarnation"]
            assert replacement["binding"]["activation"]["worker_incarnation"] != worker
        else:
            invoke("restart", "ledger")
            invoke("send", "3", "--request-id", "proof-after-loss")
            await_value(lambda: total() == 13, "Station replacement did not recover")
        recovered = installation.process("ledger")
        assert recovered["pid"] == before["ledger"]["pid"] and recovered["generation"] > before["ledger"]["generation"]
        from launcher_updates import candidate
        before_upgrade = {role: installation.process(role) for role in installation.workloads}
        candidate(installation, "example-station-ledger")
        invoke("update", "ledger", "--no-build")
        upgraded = {role: installation.process(role) for role in installation.workloads}
        for role, previous in before_upgrade.items():
            current = upgraded[role]
            assert current["pid"] == previous["pid"] and current["generation"] > previous["generation"]
            if profile == "reference":
                assert current["binding"]["workload"] != previous["binding"]["workload"]
                assert current["binding"]["incarnation"] == previous["binding"]["incarnation"]
        assert "no changes" in invoke("update", "ledger", "--no-build")
        invoke("send", "1", "--request-id", "proof-after-upgrade")
        await_value(lambda: total() == 14 and entry("requester", b"answer") == b"14", "Upgraded workers did not preserve Tables/calls")
        recovered = installation.process("ledger")
        kinds = set()
        for role, record in records.items():
            kinds.update(framework(record))
        assert {"behavior", "table", "query", "wait", "registry_scope", "registry_binding", "child"} <= kinds, kinds
        assert board(f'processes/{recovered["pid"]}')["observation"]["processes"][0]["generation"] == recovered["generation"]
        # A stopped installation starts with fresh ownership while retaining its
        # PIDs, associated resources, Table rows, registry and captured result.
        invoke("down")
        invoke("up", "--detach")
        assert installation.records() == records
        await_value(lambda: total() == 14, "Station state lost on stop/start")
        assert entry("requester", b"last-query") is not None
        evidence = ROOT / ".cache/m9" / ("station-" + profile + "-evidence.json")
        write(evidence, {"profile": profile, "processes": records, "before": before,
                         "recovered": recovered, "upgraded": upgraded, "framework_kinds": sorted(kinds), "total": 14})
        invoke("down")
        invoke("reset")
    except BaseException:
        print("Station launcher evidence retained at " + str(installation.path), file=sys.stderr)
        raise
    print(f"Station {profile}: registry/call/Arrow exchange, same-PID recovery and upgrades across three workers, Board provenance and persistent stop/start passed")


if __name__ == "__main__":
    exercise(*sys.argv[1:])
