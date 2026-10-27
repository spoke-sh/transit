"""The same real Zig caller and generic Board proof on each deployment waypoint."""
import json
import subprocess
import time
import urllib.error
import urllib.request
from common import ROOT, HTTP, read_json, run, write


def exercise(installation, launcher):
    if installation.profile == "reference":
        # Logical suspension and physical provider stop are distinct evidence.
        # Queue work while suspended and require a new activation of the same PID.
        before = installation.view()
        value = installation.counter_value()
        installation.command("readiness-suspend", {"suspend": {
            "pid": before["pid"], "expected_generation": before["generation"],
            "resume_before_ms": int(time.time() * 1000) + 240000}})
        stopped = launcher.await_process(lambda p: p["binding"]["desired"] == "stopped" and p["binding"]["phase"] == "stopped", "logical suspension provider stop")
        values = launcher.values()
        for pool in values["workerPools"]:
            pool["spec"]["replicas"] = 0
        launcher.deploy(values)
        launcher.await_worker_release(stopped["binding"]["last_worker_incarnation"])
        for pool in values["workerPools"]:
            pool["spec"]["replicas"] = 1
        launcher.deploy(values)
        installation.command("readiness-queued", {"send": {"pid": before["pid"], "value": b"2".hex()}})
        assert installation.view()["consumed"] == before["consumed"]
        installation.command("readiness-resume", {"resume": {
            "pid": before["pid"], "expected_generation": stopped["generation"]}})
        resumed = launcher.await_process(lambda p: p["binding"]["activation"] is not None and p["consumed"] == before["consumed"] + 1, "logical resumption and queued input")
        assert resumed["pid"] == before["pid"] and resumed["generation"] > stopped["generation"]
        assert resumed["binding"]["incarnation"] == before["binding"]["incarnation"]
        assert resumed["binding"]["activation"]["worker_incarnation"] != before["binding"]["activation"]["worker_incarnation"]
        assert installation.counter_value() == value + 2
        print("reference: bounded logical suspension, confirmed provider stop and same-PID fresh activation passed.")
    run(["zig", "build", "readiness-caller"], cwd=ROOT, timeout=300)
    key = "readiness/seed.key"
    installation.command("readiness-grant", {"grant": {"subject": 6,
        "public_key": installation.key(key), "permissions": 95}})
    path = installation.path / "readiness/caller.json"
    config = {"url": installation.url, "realm": installation.load()["realm"], "principal": 6,
              "seed_file": str(installation.path / key), "anchor": installation.view()["pid"]}
    write(path, config)
    binary = ROOT / "zig-out/bin/transit-readiness-caller"
    profile = installation.profile
    if profile == "local":
        launcher.pc("process", "stop", "delivery", capture=True)
    elif profile == "compose":
        launcher.docker("stop", "delivery", capture=True)
    else:
        launcher.kube("scale", "deployment/delivery", "--replicas=0")
        launcher.kube("wait", "--for=delete", "pods", "-l", "app.kubernetes.io/component=delivery", "--timeout=60s")
    pair = json.loads(run([binary, "prepare", path], capture=True, timeout=30))
    write(path, config | pair)

    def board(pid, resource):
        deadline = time.monotonic() + 30
        while True:
            try:
                request = urllib.request.Request(f"{installation.board_url}/api/v1/processes/{pid}/{resource}", headers=installation.board_headers)
                with HTTP.open(request, timeout=10) as response:
                    return read_json(response)["observation"]
            except urllib.error.HTTPError as error:
                if error.code not in (409, 429, 503) or time.monotonic() > deadline:
                    raise
                time.sleep(.2)

    pending = [entry for entry in board(pair["source"], "outbox")["outbox"] if entry]
    assert len(pending) == 1 and pending[0]["phase"] == "pending", pending
    if profile == "reference":
        launcher.kube("scale", "deployment/delivery", "--replicas=1")
        launcher.kube("rollout", "status", "deployment/delivery", "--timeout=90s")
    else:
        launcher.restart("delivery")
    deadline = time.monotonic() + 30
    while True:
        outputs = [entry for entry in board(pair["source"], "outbox")["outbox"] if entry]
        if outputs[0]["phase"] == "delivered":
            break
        assert time.monotonic() < deadline, outputs
        time.sleep(.2)
    launcher.restart("node")
    result = json.loads(run([binary, "finish", path], capture=True, timeout=45))
    assert result == {"accepted": True, "ignored_external": 1}, result
    events = [event for event in board(pair["destination"], "mailbox")["events"] if event]
    assert len(events) == 2 and all(event["mailbox_status"] == "consumed" for event in events), events
    # Read-only Board exposes kernel evidence; application interpretation stays
    # in the calling program, including rejection of the forged reply.
    print(f"{profile}: queued outbox, restarted courier/authority, authenticated Zig reply and Board evidence passed.")
