#!/usr/bin/env python3
"""Render the deployable Transit chart and check its authority/storage boundaries."""
import copy
import json
from pathlib import Path
import subprocess
import tempfile
import yaml

ROOT = Path(__file__).resolve().parents[1]
CHART = ROOT / "charts/transit"
VALUES = {
    "node": {"image": "example.invalid/transit-node:proof", "config": {
        "genesis": {"realm": 49, "root_key": [1] * 32, "retry_policy": "last_per_principal", "max_clock_error_ms": 2000},
        "bucket": "proof", "journal": "authority", "request_timeout_ms": 3000}},
    "board": {"enabled": True, "image": "example.invalid/transit-board:proof", "existingSecret": "board-credentials",
              "config": {"realm": 49, "principal": 4, "public_origin": "https://board.example.invalid:8443"}},
    "maintenance": {"enabled": True, "existingSecret": "maintenance-credentials"},
}


def run():
    with tempfile.TemporaryDirectory(prefix="transit-chart-") as directory:
        values_file = Path(directory) / "values.json"

        def render(values, error=None):
            values_file.write_text(json.dumps(values))
            result = subprocess.run(["helm", "template", "test-runtime", CHART, "--namespace", "proof", "-f", values_file],
                                    text=True, capture_output=True, check=False)
            if error:
                assert result.returncode != 0 and error in result.stderr, result.stderr
                return
            assert result.returncode == 0, result.stderr
            return {(doc["kind"], doc["metadata"]["name"]): doc
                    for doc in yaml.safe_load_all(result.stdout) if doc}

        manifests = render(VALUES)
        subprocess.run(["helm", "lint", "--strict", CHART, "-f", values_file], check=True)
        defaults = yaml.safe_load((CHART / "values.yaml").read_text())
        pins = json.loads((ROOT / "deploy/reference/versions.json").read_text())
        assert defaults["ursula"]["image"] == pins["ursula"]
        assert not any(kind in ("Secret", "Job", "RoleBinding", "ClusterRoleBinding") for kind, _ in manifests)
        pvc = manifests["PersistentVolumeClaim", "test-runtime-ursula"]
        assert pvc["metadata"]["annotations"]["helm.sh/resource-policy"] == "keep"
        for component in ("node", "ursula", "board", "maintenance"):
            deployment = manifests["Deployment", "test-runtime-" + component]
            assert deployment["spec"]["replicas"] == 1 and deployment["spec"]["strategy"]["type"] == "Recreate"
            spec = deployment["spec"]["template"]["spec"]
            assert spec["automountServiceAccountToken"] is False
            assert spec["securityContext"]["runAsNonRoot"] is True
            assert spec["containers"][0]["securityContext"]["capabilities"]["drop"] == ["ALL"]
            assert "--initialize" not in spec["containers"][0]["args"]
            secrets = [v["secret"]["secretName"] for v in spec["volumes"] if "secret" in v]
            assert secrets == ([component + "-credentials"] if component in ("board", "maintenance") else [])
        board = manifests["Deployment", "test-runtime-board"]["spec"]["template"]["spec"]
        assert {v["name"] for v in board["volumes"]} == {"config", "secrets"}
        assert board["containers"][0]["readinessProbe"]["httpGet"]["httpHeaders"] == [{"name": "Host", "value": "board.example.invalid:8443"}]
        config = json.loads(manifests["ConfigMap", "test-runtime-board"]["data"]["config.json"])
        assert config["upstream"] == "http://test-runtime-node:8080"
        assert config["seed_file"] == "/secrets/seed"
        assert "credential_file" not in config and "session_seconds" not in config
        egress = manifests["NetworkPolicy", "test-runtime-board"]["spec"]["egress"]
        assert egress[0]["to"][0]["podSelector"]["matchLabels"]["app"] == "test-runtime-node"
        assert all("ipBlock" not in to for rule in egress for to in rule["to"])
        ingress = manifests["NetworkPolicy", "test-runtime-ursula"]["spec"]["ingress"]
        assert {source["podSelector"]["matchLabels"]["app.kubernetes.io/component"] for source in ingress[0]["from"]} == {"node", "maintenance", "initialize"}

        controlled = copy.deepcopy(VALUES)
        controlled["controller"] = {"enabled": True, "image": "example.invalid/controller:proof", "existingSecret": "controller-key",
            "config": {"realm": 49, "principal": 4, "pid": 1, "worker": 1, "provider": {"authority_host": "transit.proof.svc.cluster.local"}}}
        controlled["workerPools"] = [{"name": "counter-v2", "labels": {"transit.dev/workload": "v2"}, "spec": {"replicas": 1}}]
        rendered = render(controlled)
        controller = rendered["Deployment", "test-runtime-controller"]["spec"]["template"]["spec"]
        assert controller["serviceAccountName"] == "test-runtime-controller"
        assert controller["automountServiceAccountToken"] is False
        projected = next(v["projected"] for v in controller["volumes"] if v["name"] == "provider")
        assert projected["sources"][0]["serviceAccountToken"]["audience"] == "api.ate-system.svc"
        assert rendered["Role", "test-runtime-controller"]["rules"] == [{"apiGroups": [""], "resources": ["pods/log"], "verbs": ["get"]}]
        assert rendered["ClusterRole", "proof-test-runtime-controller"]["rules"] == [{"apiGroups": ["certificates.k8s.io"], "resources": ["clustertrustbundles"], "verbs": ["list"]}]
        config = json.loads(rendered["ConfigMap", "test-runtime-controller"]["data"]["config.json"])
        assert config["provider"]["token_file"] == "/provider/token" and config["seed_file"] == "/secrets/seed"
        assert ("WorkerPool", "counter-v2") in rendered
        controlled["running"] = False
        rendered = render(controlled)
        assert all(d["spec"]["replicas"] == 0 for (kind, _), d in rendered.items() if kind == "Deployment")
        assert ("PersistentVolumeClaim", "test-runtime-ursula") in rendered

        minimal = copy.deepcopy(VALUES)
        minimal["board"]["enabled"] = minimal["maintenance"]["enabled"] = False
        boot = copy.deepcopy(minimal)
        boot["node"]["enabled"] = False
        boot["initialize"] = {"enabled": True}
        rendered = render(boot)
        job = rendered["Job", "test-runtime-initialize"]
        assert "helm.sh/hook" not in job["metadata"].get("annotations", {})
        assert job["spec"]["backoffLimit"] == 0
        assert job["spec"]["template"]["spec"]["containers"][0]["args"][-1] == "--initialize"
        assert ("Deployment", "test-runtime-node") not in rendered
        boot["node"]["enabled"] = True
        render(boot, "disable node while initialize.enabled")
        external = copy.deepcopy(minimal)
        external["ursula"] = {"enabled": False}
        render(external, "node.config.ursula_url is required")
        external["node"]["config"]["ursula_url"] = "http://storage.example.invalid:8080"
        rendered = render(external)
        assert not any(kind == "PersistentVolumeClaim" for kind, _ in rendered)
        assert json.loads(rendered["ConfigMap", "test-runtime-node"]["data"]["config.json"])["ursula_url"] == "http://storage.example.invalid:8080"
        existing = copy.deepcopy(minimal)
        existing["ursula"] = {"persistence": {"existingClaim": "retained-data"}}
        rendered = render(existing)
        assert not any(kind == "PersistentVolumeClaim" for kind, _ in rendered)
        assert rendered["Deployment", "test-runtime-ursula"]["spec"]["template"]["spec"]["volumes"][1]["persistentVolumeClaim"]["claimName"] == "retained-data"
        for component in ("board", "maintenance"):
            invalid = copy.deepcopy(VALUES)
            invalid[component]["existingSecret"] = ""
            render(invalid, component + ".existingSecret is required")
        invalid = copy.deepcopy(VALUES)
        invalid["node"]["image"] = ""
        render(invalid, "node image is required")
        invalid = copy.deepcopy(VALUES)
        invalid["board"]["logging"] = {"level": "verbose"}
        render(invalid, "/board/logging/level")
        invalid = copy.deepcopy(VALUES)
        invalid["node"]["replicas"] = 3
        render(invalid, "replicas")
        pool = copy.deepcopy(minimal)
        pool["workerPool"] = {"enabled": True, "spec": {"replicas": 3, "workerImage": "example.invalid/ateom:proof"}}
        assert ("WorkerPool", "test-runtime-worker-pool") in render(pool)
    print("Transit chart: explicit bootstrap, private credentials, retained storage and network boundaries passed.")


if __name__ == "__main__":
    run()
