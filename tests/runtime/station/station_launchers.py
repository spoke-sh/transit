"""Persistent Station example through the same local/Compose/reference entry point."""
from runner.paths import ROOT
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

sys.path.insert(0, str(ROOT / "launchers"))
from common import HTTP, run, write
from station_example import StationInstallation
from interfaces.deployment.launchers import ports
from runtime.station.station_ledger import audit_total


def exercise(profile, name=None, base=None, existing=False):
    from local import Local
    from compose import Compose
    from station_reference import StationReference
    installation = StationInstallation(profile, name or "station-" + secrets.token_hex(3), base or ports())
    launcher = {"local": Local, "compose": Compose, "reference": StationReference}[profile](installation)
    env = {key: value for key, value in os.environ.items() if not key.startswith("TRANSIT_") and key not in ("LOG_LEVEL", "LOG_FORMAT")}

    def invoke(action, *arguments):
        command = [sys.executable, "-B", ROOT / "launchers/main.py", profile, action, "--name", installation.name, *arguments]
        result = subprocess.run(list(map(str, command)), env=env, capture_output=True, text=True, timeout=1200)
        if result.returncode: raise RuntimeError(result.stdout[-2000:] + result.stderr[-3000:])
        return result.stdout

    def entry(role, key):
        page = installation.native_query({"read_entries": {
            "resource": installation.records()[role]["resource"],
            "keys": [key.hex()] + [None] * 7}})
        value = page["body"]["read_entries"]["entries"][0]
        return bytes.fromhex(value["value"]) if value else None

    def total():
        resource = installation.records()['ledger']['resource']
        snapshot = installation.native_query({'open_snapshot': {
            'resource': resource, 'nonce': list(secrets.token_bytes(16))}})['body']['open_snapshot']
        def captured(kind):
            if 'resource' in kind:
                assert kind['resource'] == resource
                return {'body': {'resource': snapshot['resource']}}
            page = installation.native_query({'snapshot_entries': {
                'id': snapshot['id'], 'after': kind['entries']['after']}})['body']['snapshot_entries']
            assert page['snapshot']['id'] == snapshot['id'] and page['snapshot']['resource'] == snapshot['resource']
            return {'body': {'entries': {'page': page['page']}}}
        try:
            return audit_total(captured, resource)
        finally:
            installation.native_query({'close_snapshot': snapshot['id']})

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
                    if page["next_key"] is None: return kinds
                    response = board(path + "?" + urllib.parse.urlencode({
                        "after_key": page["next_key"], "revision": page["resources"][0]["revision"], **page["cut"]}))
            except CutExpired:
                # Concurrent controller/output progress invalidates the whole
                # snapshot. Never retry one old cursor or stitch different cuts.
                time.sleep(.2)
        raise AssertionError("No stable bounded framework observation")

    def query_evidence(record):
        path = f'resources/{record["resource"]}/records'
        for _ in range(30):
            kinds = set()
            try:
                response = board(path)
                while True:
                    for lens in response['queries']:
                        if lens:
                            assert lens['source']['pid'] == record['pid'] and lens['source']['resource'] == record['resource']
                            kinds.update(lens['declaration'])
                    after = response['page']['next']
                    if after is None: return kinds
                    response = board(path + '?' + urllib.parse.urlencode({
                        'after': after, 'revision': response['resource']['revision']}))
            except CutExpired:
                time.sleep(.2)
        raise AssertionError('No stable bounded query observation')

    try:
        if not existing:
            invoke("up", "--example", "station", "--base-port", str(installation.base_port), "--detach")
        await_value(lambda: total() == 12, "Initial direct Table operations did not complete")
        records = installation.records()
        before = {role: installation.process(role) for role in installation.workloads}
        lookup = json.loads(invoke("send", "lookup", "--request-id", "proof-lookup"))["admitted_at"]
        resolved_key = b"\x00r" + lookup.to_bytes(8, "little") + b"\x00"
        await_value(lambda: entry("requester", resolved_key) is not None, "Registry route did not resolve the ledger PID")
        assert int.from_bytes(entry("requester", resolved_key)[24:32], "little") == records["ledger"]["pid"]
        invoke("send", "-2", "--request-id", "proof-delta")
        invoke("send", "-2", "--request-id", "proof-delta")
        await_value(lambda: total() == 10 and entry("requester", b"answer") == b"10", "Original delta/retry did not settle its audit and reply")
        if profile == "local":
            from runtime.delivery.courier_readiness import ReadinessOutage
            fault = ReadinessOutage(installation, launcher)
            started_reply = None
            reply_seconds = None
            passed = False
            try:
                with fault:
                    invoke("send", "query", "--request-id", "proof-query")
                    started_reply = time.monotonic()
                    deadline = started_reply + 60
                    recovery = fault.recover(deadline)
                    # Readiness replacement deliberately consumes about 30 seconds
                    # in failed probes. Bound resumed query progress separately;
                    # no phase can renew its own deadline after an unavailable read.
                    assert time.monotonic() < deadline, "Courier replacement exceeded its original deadline"
                    resumed = time.monotonic()
                    completion_deadline = resumed + 60
                    await_value(lambda: entry("requester", b"last-query") is not None,
                                "Arrow reply did not complete", seconds=max(0, completion_deadline-time.monotonic()))
                    reply_seconds = time.monotonic() - started_reply
                    assert time.monotonic() < completion_deadline, "Arrow reply exceeded its completion deadline"
                    assert fault.commands > 0
                    recovery['query_completion_seconds'] = round(time.monotonic()-resumed, 3)
                    passed = True
            finally:
                # Record only after the timed schedule and cleanup. A reply
                # observed after cleanup's restart cannot turn failure into a pass.
                readiness = {"version": 1, "profile": profile, "installation": installation.name,
                             "artifact_provenance": installation.artifacts.read("selected")["provenance"],
                             "replacement_deadline_seconds": 60, "completion_deadline_seconds": 60,
                             "query_submitted": started_reply is not None,
                             "reply_seconds": reply_seconds, "passed_before_cleanup": passed,
                             "recovery": fault.recovery, "refused_reads": fault.refusals,
                             "forwarded_commands": fault.commands,
                             "cleanup_restart_started": fault.cleanup_restart_started,
                             "cleanup_restart_completed": fault.cleanup_restart_completed}
                write(ROOT / ".cache/m9/station-local-readiness.json", readiness)
                print("Station courier readiness recovery: " + json.dumps(readiness), flush=True)
        else:
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
        from interfaces.deployment.launcher_updates import candidate
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
        assert {"behavior", "wait", "registry_scope", "registry_binding", "child"} <= kinds, kinds
        assert "table" not in kinds, "Direct Table rows leaked into actor Table storage"
        queries = query_evidence(records['ledger']) | query_evidence(records['requester'])
        assert {'execution', 'request'} <= queries, queries
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
                         "recovered": recovered, "upgraded": upgraded, "framework_kinds": sorted(kinds),
                         "query_kinds": sorted(queries), "total": 14})
        invoke("down")
        invoke("reset")
    except BaseException:
        print("Station launcher evidence retained at " + str(installation.path), file=sys.stderr)
        raise
    print(f"Station {profile}: registry/call/Arrow exchange, same-PID recovery and upgrades across three workers, Board provenance and persistent stop/start passed")


if __name__ == "__main__":
    exercise(*sys.argv[1:])
