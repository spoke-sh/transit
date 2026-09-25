"""Real authority/controller recovery with a faultable provider CLI boundary."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import uuid

from inspection import System


def run(node, cli, controller):
    with System(node, cli) as s:
        actor_uid = str(uuid.uuid4())
        old_uid, new_uid = uuid.uuid4(), uuid.uuid4()
        image = "example@sha256:" + "a" * 64
        provider = s.root / "provider.json"
        fake = s.root / "kubectl-ate"
        fake.write_text('''#!/usr/bin/env python3
import json, sys
from pathlib import Path
p = Path(__file__).with_name("provider.json")
v = json.loads(p.read_text())
a = sys.argv[7:]
if a == ["--version"]:
    print("kubectl-ate version transit-upgrade-v1 commit=d277088bc1d081ef716d81dd7986d05d0a36ad3a built=unknown")
elif a[:2] == ["get", "actor-template"]:
    print(json.dumps(v["templates"][a[2]]))
elif a[:2] == ["get", "actor"]:
    print(json.dumps(v["actor"]))
elif a[:2] == ["update", "actor"]:
    assert a[6] == v["actor"]["metadata"]["uid"]
    assert a[8] == v["actor"]["actorTemplate"]["name"]
    v["actor"]["actorTemplate"]["name"] = a[10]
    v["switches"] += 1
    p.write_text(json.dumps(v))
    # Mutation succeeded; response was lost. No local acknowledgement exists.
    sys.exit(1)
else:
    raise RuntimeError(a)
''')
        fake.chmod(0o755)
        def template(uid):
            return {"metadata": {"uid": str(uid)}, "containers": [{"name": "counter", "image": image, "volumeMounts": [{"name": "runtime-data", "mountPath": "/runtime-data"}]}],
                    "volumes": [{"name": "runtime-data", "durableDir": {}}],
                    "snapshotsConfig": {"onPause": "SNAPSHOT_CONTENT_SCOPE_DATA", "onCommit": "SNAPSHOT_CONTENT_SCOPE_DATA", "onResume": {"fromData": "RESUME_SOURCE_COLD_BOOT"}}}
        data = {"templates": {"old": template(old_uid), "new": template(new_uid)}, "switches": 0,
                "actor": {"metadata": {"name": "counter", "atespace": "proof", "uid": actor_uid}, "actorTemplate": {"atespace": "proof", "name": "old"}, "status": {"state": "ACTOR_STATE_SUSPENDED"}}}
        provider.write_text(json.dumps(data))
        key, public = s.key("controller")
        pid = s.command({"spawn": {}})
        s.command({"grant": {"subject": 2, "public_key": public, "permissions": 17, "pid": pid}})
        resource = list(hashlib.sha256(b"rey.substrate.resource.v1\0proof/counter").digest())
        def workload(uid):
            return list(hashlib.sha256(b"rey.substrate.workload.v1\0" + uid.bytes + image.encode()).digest())
        stop = s.command({"runtime_intent": {"pid": pid, "expected_revision": 0, "instance": [1]*16, "resource": resource, "workload": workload(old_uid), "desired": "stopped"}})
        s.command({"runtime_observe": {"pid": pid, "revision": 1, "operation": stop, "incarnation": list(uuid.UUID(actor_uid).bytes), "outcome": "stopped"}})
        s.command({"runtime_upgrade": {"pid": pid, "expected_revision": 1, "expected_workload": workload(old_uid), "workload": workload(new_uid), "expected_code": 1, "expected_state_revision": 0}})
        config = {"url": s.url, "realm": 72, "principal": 2, "seed_file": str(key), "pid": pid, "worker": 1,
                  "provider": {"cli": str(fake), "kubeconfig": "explicit", "context": "proof", "instance": [1]*16, "atespace": "proof", "actor": "counter", "template": "old", "template_uid": list(old_uid.bytes), "image": image, "egress_policy_file": "unused", "authority_host": "authority"}}
        path = s.root / "controller.json"
        def scan(error=None, mode="--once"):
            path.write_text(json.dumps(config))
            result = subprocess.run([controller, path, mode], capture_output=True, text=True, timeout=40)
            if error:
                assert result.returncode != 0 and error in result.stderr, result
            else:
                assert result.returncode == 0, result.stderr
            return result.stdout
        config["provider"]["container"] = "station"
        scan("TemplateMismatch")  # Bootstrap evidence must come from the reviewed container.
        config["provider"]["container"] = "counter"
        scan("BindingMismatch")  # Old controller cannot mutate the new binding.
        config["provider"].update(template="new", template_uid=list(new_uid.bytes), previous_workload={"template": "old", "template_uid": list(old_uid.bytes), "image": image})
        cut = s.inspect("process", pid)["cut"]
        scan(mode="--check")
        assert s.inspect("process", pid)["cut"] == cut
        assert json.loads(provider.read_text())["switches"] == 0
        data["actor"]["metadata"]["uid"] = str(uuid.uuid4())
        provider.write_text(json.dumps(data))
        scan("ProviderIncarnationMismatch")
        data["actor"]["metadata"]["uid"] = actor_uid
        provider.write_text(json.dumps(data))
        scan("ProviderUnavailable")
        assert json.loads(provider.read_text())["switches"] == 1
        assert s.inspect("process", pid)["processes"][0]["binding"]["upgrade_from"] == workload(old_uid)
        assert scan().strip() == "observed"
        binding = s.inspect("process", pid)["processes"][0]["binding"]
        assert binding["phase"] == "stopped" and binding.get("upgrade_from") is None
        assert binding["incarnation"] == list(uuid.UUID(actor_uid).bytes)
        assert scan().strip() == "idle"
        assert json.loads(provider.read_text())["switches"] == 1
        # Cold boot is not a new pod incarnation. Reject before reading logs,
        # whose earlier bootstrap lines can no longer identify a unique boot.
        _, worker_public = s.key("worker")
        _, active_public = s.key("active-worker")
        s.command({"grant": {"subject": 1, "public_key": worker_public, "permissions": 24, "pid": pid}})
        intent = {"pid": pid, "expected_revision": binding["revision"], "instance": [1]*16,
                  "resource": resource, "workload": workload(new_uid), "desired": "running"}
        running = s.command({"runtime_intent": intent})
        revision = intent["expected_revision"] + 1
        s.command({"runtime_observe": {"pid": pid, "revision": revision, "operation": running,
                  "incarnation": list(uuid.UUID(actor_uid).bytes), "outcome": "ready"}})
        process = s.inspect("process", pid)["processes"][0]
        worker_uid = uuid.uuid4()
        s.command({"activate": {"pid": pid, "revision": revision, "expected_generation": process["generation"],
                  "worker": 1, "public_key": active_public, "worker_incarnation": list(worker_uid.bytes)}})
        intent.update(expected_revision=revision, desired="stopped")
        stop = s.command({"runtime_intent": intent})
        revision += 1
        s.command({"runtime_observe": {"pid": pid, "revision": revision, "operation": stop,
                  "incarnation": list(uuid.UUID(actor_uid).bytes), "outcome": "stopped"}})
        intent.update(expected_revision=revision, desired="running")
        running = s.command({"runtime_intent": intent})
        revision += 1
        s.command({"runtime_observe": {"pid": pid, "revision": revision, "operation": running,
                  "incarnation": list(uuid.UUID(actor_uid).bytes), "outcome": "ready"}})
        data = json.loads(provider.read_text())
        data["actor"]["status"] = {"state": "ACTOR_STATE_RUNNING", "currentActorTemplateUid": str(new_uid),
                                  "workerAssignment": {"workerPodUid": str(worker_uid)}}
        provider.write_text(json.dumps(data))
        scan("StaleWorkerIncarnation")  # The fake rejects any unexpected log call.
        assert s.inspect("process", pid)["processes"][0]["owner"] is None
    print("Runtime upgrade: stale controller/Actor rejection and lost provider response recovery and cold-boot pod reuse rejection passed.")


if __name__ == "__main__":
    run(*[Path(p).resolve() for p in sys.argv[1:]])
