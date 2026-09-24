#!/usr/bin/env python3
"""Deploy the M1 slice on the owned reference cluster and kill real workers."""
import json
from wire_values import encode_command, decode_view
import os
from pathlib import Path
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid

import reference as ref
from storage import free_port


def run():
    s = ref.state()
    images = json.loads((ref.CACHE / "images.json").read_text())
    directory = ref.CACHE / ("proof-" + uuid.uuid4().hex[:8])
    directory.mkdir(mode=0o700)
    namespace = "rey-" + directory.name
    http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    cli = ref.CACHE / "bin/bin/rey-cli"
    controller_bin = ref.CACHE / "bin/bin/transit-runtime-controller"
    children = []
    logs = []

    def start(argv, name):
        log = (directory / (name + ".log")).open("w+")
        logs.append(log)
        child = subprocess.Popen(list(map(str, argv)), stdout=log, stderr=subprocess.STDOUT)
        children.append(child)
        return child, log

    def key(name):
        path = directory / (name + ".key")
        path.write_text(os.urandom(32).hex())
        path.chmod(0o600)
        return path, json.loads(ref.run([cli, "public-key", path], capture=True))

    root_key, root_public = key("root")
    controller_key, controller_public = key("controller")
    maintenance_key, maintenance_public = key("maintenance")
    _, worker_public = key("initial-worker")
    port = free_port()
    url = f"http://127.0.0.1:{port}"
    authority_host = f"transit.{namespace}.svc.cluster.local"
    authority_url = f"http://{authority_host}:8080"
    sequence = 0

    def post(path, command, seq):
        revision = view(command["turn"]["pid"])["process"]["revision"] if "turn" in command else 0
        command = encode_command(command, revision)
        request_file = directory / "request.json"
        request_file.write_text(json.dumps({"realm": 49, "principal": 0, "sequence": seq, "command": command}))
        signed = ref.run([cli, "sign", root_key, request_file], capture=True).encode()
        for attempt in range(20):
            try:
                with http.open(urllib.request.Request(url + path, signed, {"Content-Type": "application/json"}), timeout=8) as response:
                    return decode_view(json.load(response))
            except urllib.error.HTTPError as error:
                if error.code not in (409, 503):
                    raise RuntimeError((error.code, error.read().decode())) from error
            except (urllib.error.URLError, TimeoutError, ConnectionError):
                pass
            time.sleep(0.2)
        raise TimeoutError("Authority unavailable")

    def command(value):
        nonlocal sequence
        sequence += 1
        return post("/v2/command", value, sequence)["position"]

    def view(pid):
        return post("/v2/view", {"inspect": pid}, 0)

    def apply(value):
        ref.kube(s, ["apply", "-f", "-"], input=json.dumps(value))

    def await_state(pid, expected, limit=240):
        deadline = time.monotonic() + limit
        while time.monotonic() < deadline:
            try:
                value = view(pid)
                if value["process"]["state"] == expected:
                    return value
            except (RuntimeError, TimeoutError):
                pass
            time.sleep(0.5)
        raise TimeoutError(f"Process did not reach state {expected}")

    def actor():
        return json.loads(ref.ate(s, ["get", "actor", actor_name, "-a", namespace, "-o", "json"], capture=True))

    def pod_spec(image, args, app, storage=False):
        result = {
            "automountServiceAccountToken": False,
            "securityContext": {"runAsNonRoot": True, "runAsUser": 65532, "runAsGroup": 65532, "fsGroup": 65532},
            "containers": [{"name": app, "image": image, "args": args,
                            "securityContext": {"allowPrivilegeEscalation": False, "readOnlyRootFilesystem": True, "capabilities": {"drop": ["ALL"]}},
                            "resources": {"requests": {"cpu": "100m", "memory": "128Mi"}, "limits": {"cpu": "2", "memory": "1Gi"}},
                            "volumeMounts": [{"name": "config", "mountPath": "/config", "readOnly": True}]}],
            "volumes": [{"name": "config", "configMap": {"name": "config"}}],
        }
        if storage:
            result["containers"][0]["env"] = [{"name": "RUST_LOG", "value": "warn"}, {"name": "TOKIO_WORKER_THREADS", "value": "2"}]
            result["containers"][0]["volumeMounts"].append({"name": "data", "mountPath": "/data"})
            result["volumes"].append({"name": "data", "persistentVolumeClaim": {"claimName": "ursula"}})
        return result

    def deployment(app, spec):
        spec["containers"][0]["readinessProbe"] = {"httpGet": {"path": "/__ursula/ready" if app == "ursula" else "/health", "port": 8080}, "periodSeconds": 2}
        return {"apiVersion": "apps/v1", "kind": "Deployment", "metadata": {"name": app, "namespace": namespace},
                "spec": {"replicas": 1, "strategy": {"type": "Recreate"}, "selector": {"matchLabels": {"app": app}},
                         "template": {"metadata": {"labels": {"app": app}}, "spec": spec}}}

    config = {"genesis": {"realm": 49, "root_key": root_public, "retry_policy": "last_per_principal", "max_clock_error_ms": 2000}, "ursula_url": f"http://ursula.{namespace}.svc.cluster.local:8080",
              "bucket": "rey-reference", "journal": "authority", "listen": "0.0.0.0", "port": 8080, "request_timeout_ms": 3000}
    maintenance_config = dict(config, maintenance={"principal": 3, "seed_file": "/secrets/seed", "interval_ms": 200,
                                                  "operation_timeout_ms": 5000, "checkpoint_every_records": 16})
    wal = '''[server]
listen = "0.0.0.0:8080"
admin_listen = "0.0.0.0:8081"
[runtime]
core_count = 2
[raft]
node_id = 1
group_count = 1
[raft.wal]
backend = "disk"
path = "/data/wal"
[storage.cold]
backend = "none"
[storage.snapshot]
backend = "inline"
'''
    try:
        apply({"apiVersion": "v1", "kind": "Namespace", "metadata": {"name": namespace}})
        apply({"apiVersion": "v1", "kind": "ConfigMap", "metadata": {"name": "config", "namespace": namespace}, "data": {
            "node.json": json.dumps(config), "maintenance.json": json.dumps(maintenance_config), "ursula.toml": wal}})
        apply({"apiVersion": "v1", "kind": "PersistentVolumeClaim", "metadata": {"name": "ursula", "namespace": namespace}, "spec": {"accessModes": ["ReadWriteOnce"], "resources": {"requests": {"storage": "1Gi"}}}})
        for app in ("ursula", "transit"):
            apply({"apiVersion": "v1", "kind": "Service", "metadata": {"name": app, "namespace": namespace},
                   "spec": {"selector": {"app": app}, "ports": [{"name": "http", "port": 8080, "targetPort": 8080}]}})
        apply(deployment("ursula", pod_spec(images["ursula"], ["server", "--config", "/config/ursula.toml"], "ursula", True)))
        ref.kube(s, ["-n", namespace, "rollout", "status", "deployment/ursula", "--timeout=120s"])
        boot = pod_spec(images["transit-node"], ["/config/node.json", "--initialize"], "initialize")
        boot["restartPolicy"] = "Never"
        apply({"apiVersion": "batch/v1", "kind": "Job", "metadata": {"name": "initialize", "namespace": namespace},
               "spec": {"backoffLimit": 0, "template": {"spec": boot}}})
        ref.kube(s, ["-n", namespace, "wait", "--for=condition=complete", "job/initialize", "--timeout=120s"])
        # Ordinary pod restarts never create a missing realm.
        apply(deployment("transit", pod_spec(images["transit-node"], ["/config/node.json"], "transit")))
        ref.kube(s, ["-n", namespace, "rollout", "status", "deployment/transit", "--timeout=120s"])
        forward, _ = start(["kubectl", "--kubeconfig", ref.CACHE / "kubeconfig", "--context", "kind-" + s["cluster"],
                            "-n", namespace, "port-forward", "service/transit", f"{port}:8080"], "port-forward")
        time.sleep(1)
        pid = command({"spawn": {"allow_trim": True}})
        command({"grant": {"subject": 1, "public_key": worker_public, "permissions": 24, "pid": pid}})
        command({"grant": {"subject": 2, "public_key": controller_public, "permissions": 17, "pid": pid}})
        for value in range(1, 18):
            command({"send": {"pid": pid, "value": value}})
        apply({"apiVersion": "ate.dev/v1alpha1", "kind": "WorkerPool", "metadata": {"name": "counter", "namespace": namespace, "labels": {"workload": namespace}},
               "spec": {"replicas": 3, "workerImage": images["ateom"], "template": {"nodeSelector": {"ate.dev/substrate-version": ref.PINS["substrate"][:7]},
                        "resources": {"requests": {"cpu": "100m", "memory": "512Mi"}, "limits": {"cpu": "1", "memory": "1Gi"}}}}})
        ref.ate(s, ["create", "atespace", namespace])
        template = {"metadata": {"atespace": namespace, "name": "counter"}, "workerSelector": {"matchLabels": {"workload": namespace}},
                    "containers": [{"name": "counter", "image": images["example-counter"], "command": ["/example-counter", "--bootstrap-json",
                                     json.dumps({"url": authority_url, "realm": 49, "principal": 1, "pid": pid})],
                                    "volumeMounts": [{"name": "runtime-data", "mountPath": "/runtime-data"}]}],
                    "volumes": [{"name": "runtime-data", "durableDir": {}}],
                    "resources": {"limits": [{"name": "cpu", "quantity": "1"}, {"name": "memory", "quantity": "512Mi"}]},
                    "snapshotsConfig": {"storageLocation": f"gs://ate-snapshots/{namespace}/", "onPause": "SNAPSHOT_CONTENT_SCOPE_DATA", "onCommit": "SNAPSHOT_CONTENT_SCOPE_DATA", "onResume": {"fromData": "RESUME_SOURCE_COLD_BOOT"}},
                    "sandboxConfig": {"sandboxClass": "SANDBOX_CLASS_GVISOR", "configName": "gvisor-default"}}
        template_file = directory / "template.json"
        template_file.write_text(json.dumps(template))
        created = json.loads(ref.ate(s, ["create", "actor-template", "-f", template_file, "-o", "json"], capture=True))
        template_uid = created["metadata"]["uid"]
        policy = directory / "egress.json"
        policy.write_text(json.dumps({"rules": [{"hostnames": {"patterns": [authority_host]}}]}))
        actor_name = f"realm-49-pid-{pid}"
        controller_config = directory / "controller.json"
        controller_config.write_text(json.dumps({"url": url, "realm": 49, "principal": 2, "seed_file": str(controller_key), "pid": pid, "worker": 1,
            "provider": {"cli": str(ref.CACHE / "kubectl-ate"), "kubeconfig": str(ref.CACHE / "kubeconfig"), "context": "kind-" + s["cluster"],
                         "instance": list(uuid.uuid4().bytes), "atespace": namespace, "actor": actor_name, "template": "counter",
                         "template_uid": list(uuid.UUID(template_uid).bytes), "image": images["example-counter"],
                         "egress_policy_file": str(policy), "authority_host": authority_host}}))
        first, first_log = start([controller_bin, controller_config], "first-controller")
        deadline = time.monotonic() + 60
        while True:
            if "created\n" in Path(first_log.name).read_text():
                first.kill()
                first.wait(timeout=10)
                break
            if first.poll() is not None or time.monotonic() > deadline:
                raise RuntimeError("Controller did not create the recorded Actor")
            time.sleep(0.02)
        first_actor_uid = actor()["metadata"]["uid"]
        assert view(pid)["process"]["binding"]["phase"] == "pending"
        assert view(pid)["process"]["owner"] is None
        second, _ = start([controller_bin, controller_config], "replacement-controller")
        completed = await_state(pid, 153)
        live = actor()
        assert live["metadata"]["uid"] == first_actor_uid
        from reference_board import Board
        board = Board(s, directory, namespace, images, pid, command, key, apply, start)
        board_before = board.process(pid)
        assert board_before["generation"] == completed["process"]["generation"]
        old_worker = live["status"]["workerAssignment"]
        ref.kube(s, ["-n", old_worker["workerNamespace"], "delete", "pod", old_worker["workerPod"], "--grace-period=0", "--force"])
        command({"send": {"pid": pid, "value": 1000}})
        recovered = await_state(pid, 1153)
        replacement = actor()
        assert replacement["metadata"]["uid"] == first_actor_uid
        assert replacement["status"]["workerAssignment"]["workerPodUid"] != old_worker["workerPodUid"]
        assert recovered["process"]["generation"] > completed["process"]["generation"]
        board_after = board.process(pid)
        assert board_after["pid"] == board_before["pid"]
        assert board_after["generation"] > board_before["generation"]
        assert board_after["binding"]["activation"]["worker_incarnation"] != board_before["binding"]["activation"]["worker_incarnation"]
        ref.kube(s, ["-n", namespace, "delete", "pod", "-l", "app=ursula", "--grace-period=0", "--force"])
        ref.kube(s, ["-n", namespace, "rollout", "status", "deployment/ursula", "--timeout=120s"])
        assert await_state(pid, 1153)["process"]["pid"] == pid
        # Independent maintenance survives lack of incoming requests and trims
        # while the original authority stays running. No key reaches workers.
        command({"grant": {"subject": 3, "public_key": maintenance_public, "permissions": 33}})
        deadline = int(time.time() * 1000) + 5000
        finite_pid = command({"spawn": {"allow_trim": True, "deadline_ms": deadline, "settle_before_ms": deadline + 1000}})
        command({"send": {"pid": finite_pid, "value": 99}})
        apply({"apiVersion": "v1", "kind": "Secret", "metadata": {"name": "maintenance", "namespace": namespace},
               "stringData": {"seed": maintenance_key.read_text()}})
        maintenance_spec = pod_spec(images["transit-node"], ["/config/maintenance.json", "--maintain"], "maintenance")
        maintenance_spec["containers"][0]["volumeMounts"].append({"name": "seed", "mountPath": "/secrets", "readOnly": True})
        maintenance_spec["volumes"].append({"name": "seed", "secret": {"secretName": "maintenance", "defaultMode": 0o440}})
        maintenance_deployment = deployment("maintenance", maintenance_spec)
        del maintenance_deployment["spec"]["template"]["spec"]["containers"][0]["readinessProbe"]
        apply(maintenance_deployment)
        limit = time.monotonic() + 60
        while view(finite_pid)["process"]["lifecycle"] != "expired":
            assert time.monotonic() < limit, "Finite process did not expire"
            time.sleep(0.2)
        # Authority recovery is independent of its HTTP connection and cache.
        forward.kill()
        forward.wait(timeout=10)
        ref.kube(s, ["-n", namespace, "delete", "pod", "-l", "app=transit", "--grace-period=0", "--force"])
        ref.kube(s, ["-n", namespace, "rollout", "status", "deployment/transit", "--timeout=120s"])
        forward, _ = start(["kubectl", "--kubeconfig", ref.CACHE / "kubeconfig", "--context", "kind-" + s["cluster"],
                            "-n", namespace, "port-forward", "service/transit", f"{port}:8080"], "replacement-forward")
        assert await_state(pid, 1153)["process"]["pid"] == pid
        assert view(finite_pid)["process"]["lifecycle"] == "expired"
        assert board.process(finite_pid)["lifecycle"] == "expired"
        assert board.process(pid)["state"] == b"1153".hex()
        from reference_isolation import run as isolation
        isolation_evidence = isolation(s, directory, namespace, authority_host, images, template)
        # A deterministic poison input must stop replacement, not turn worker
        # exits into an endless Substrate activation loop.
        failed_input = command({"send": {"pid": pid, "value": 9223372036854775807}})
        limit = time.monotonic() + 60
        while True:
            blocked = view(pid)["process"]
            if blocked["failure"] is not None and blocked["binding"]["phase"] == "stopped":
                break
            assert time.monotonic() < limit, "Handler failure was not durably blocked/stopped"
            time.sleep(0.2)
        assert blocked["failure"]["input"] == failed_input and blocked["state"] == 1153
        time.sleep(2)
        assert view(pid)["process"]["generation"] == blocked["generation"]
        command({"terminate": pid})
        assert view(pid)["process"]["lifecycle"] == "terminated"
        limit = time.monotonic() + 60
        while view(pid)["process"]["binding"]["phase"] != "stopped":
            assert time.monotonic() < limit, "Runtime shutdown did not reconcile"
            time.sleep(0.2)
        assert board.process(pid)["lifecycle"] == "terminated"
        board_history = board.read(f"processes/{pid}/history")["observation"]
        board.evidence["retained_history"] = {key: board_history[key] for key in ("cut", "history", "complete")}
        evidence = {"board": board.evidence, "namespace": namespace, "pid": pid, "actor_uid": first_actor_uid,
                    "first_worker_uid": old_worker["workerPodUid"], "replacement_worker_uid": replacement["status"]["workerAssignment"]["workerPodUid"],
                    "state": 1153, "expired_pid": finite_pid, "isolation": isolation_evidence, "images": images, "pins": ref.PINS}
        (directory / "evidence.json").write_text(json.dumps(evidence, indent=2))
        print("Substrate controller crash, same-PID/Actor worker recovery, persistent Ursula/authority restart and background expiry passed.")
        print("Evidence:", directory / "evidence.json")
    except BaseException:
        for log in logs:
            sys.stderr.write(Path(log.name).read_text()[-6000:])
        ref.kube(s, ["get", "pods", "-n", namespace])
        raise
    finally:
        for child in children:
            if child.poll() is None:
                child.kill()
            child.wait(timeout=10)
        for log in logs:
            log.close()


if __name__ == "__main__":
    import sys
    run()
