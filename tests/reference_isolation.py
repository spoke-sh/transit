"""Run explicit bypass attempts inside a pinned gVisor Substrate Actor."""
import copy
import json
import time

import reference as ref


def run(s, directory, namespace, authority_host, images, template):
    ursula = json.loads(ref.kube(s, ["-n", namespace, "get", "pods", "-l", "app=ursula", "-o", "json"], capture=True))["items"][0]
    ursula_ip = ursula["status"]["podIP"]
    dns = f"ursula.{namespace}.svc.cluster.local"
    raw_path = "/rey-reference/authority?record=0&max_records=1"
    checks = [
        {"label": "raw-read", "url": f"http://{dns}:8080{raw_path}"},
        # A separate nonexistent stream tests the write route without corrupting
        # the control journal if the isolation proof fails.
        {"label": "raw-write", "url": f"http://{dns}:8080/isolation-probe/denied", "method": "POST"},
        {"label": "raw-admin", "url": f"http://{ursula_ip}:8081/metrics"},
        {"label": "raw-ip", "url": f"http://{ursula_ip}:8080{raw_path}"},
        {"label": "spoof-host", "url": f"http://{ursula_ip}:8080{raw_path}", "host": authority_host + ":8080"},
        {"label": "connect-tunnel", "url": f"http://{dns}:8080", "method": "CONNECT", "host": authority_host + ":8080"},
        {"label": "substrate-api", "url": "http://api.ate-system.svc.cluster.local:443/"},
        {"label": "kubernetes-api", "url": "http://kubernetes.default.svc.cluster.local:443/"},
    ]
    value = copy.deepcopy(template)
    value["metadata"] = {"atespace": namespace, "name": "isolation-probe"}
    value["containers"] = [{"name": "probe", "image": images["isolation-probe"],
        "command": ["/isolation-probe", json.dumps({"authority": f"http://{authority_host}:8080/health", "checks": checks})],
        "volumeMounts": [{"name": "runtime-data", "mountPath": "/runtime-data"}]}]
    path = directory / "isolation-template.json"
    path.write_text(json.dumps(value))
    ref.ate(s, ["create", "actor-template", "-f", path])
    name = "isolation-probe"
    ref.ate(s, ["create", "actor", name, "-a", namespace, "--template", namespace + "/isolation-probe"])
    ref.ate(s, ["create", "egress-policy", name, "-a", namespace, "-f", directory / "egress.json"])
    limit = time.monotonic() + 120
    while True:
        pool = json.loads(ref.kube(s, ["-n", namespace, "get", "workerpool", "counter", "-o", "json"], capture=True))
        if pool.get("status", {}).get("readyReplicas", 0) >= 3:
            break
        assert time.monotonic() < limit, "Probe worker capacity unavailable"
        time.sleep(1)
    ref.ate(s, ["resume", "actor", name, "-a", namespace])
    limit = time.monotonic() + 180
    transcript = ""
    while time.monotonic() < limit:
        actor = json.loads(ref.ate(s, ["get", "actor", name, "-a", namespace, "-o", "json"], capture=True))
        if actor["status"]["state"] == "ACTOR_STATE_RUNNING":
            transcript = ref.ate(s, ["logs", "actor", name, "-a", namespace, "-c", "probe"], capture=True)
            messages = [json.loads(line).get("message", "") for line in transcript.splitlines() if line.startswith("{")]
            transcript = "\n".join(m for m in messages if m.startswith(("probe ", "ISOLATION_", "error:")))
            (directory / "isolation.log").write_text(transcript)
            if "ISOLATION_PROOF_PASSED" in transcript:
                ref.ate(s, ["suspend", "actor", name, "-a", namespace])
                return {"actor_uid": actor["metadata"]["uid"], "checks": checks, "transcript": transcript}
            if "error:" in transcript or "denied=false" in transcript:
                raise RuntimeError("Isolation probe failed: " + transcript)
        time.sleep(1)
    raise TimeoutError("Isolation probe did not finish: " + transcript)
