#!/usr/bin/env python3
"""Render the deployable Transit chart and check its authority/storage boundaries."""
from runner.paths import ROOT
import copy
import json
from pathlib import Path
import subprocess
import tempfile
import yaml

CHART = ROOT / "deploy/reference/chart"
VALUES = {
    "node": {"image": "example.invalid/transit:proof", "existingSecret": "node-credentials", "config": {
        "realm": 49, "applications": None, "sql": {"native": {"local": False}},
        "external": {"listen": "0.0.0.0"}}},
    "board": {"enabled": True, "image": "example.invalid/transit-board:proof", "existingSecret": "board-credentials",
              "config": {"realm": 49, "principal": 4, "public_origin": "https://board.example.invalid:8443"}},
}


def run():
    attachments = yaml.safe_load((ROOT / "deploy/reference/process-compose.yaml").read_text())["processes"]
    for process in attachments.values():
        assert all("deployment/" + retired not in process["command"]
                   for retired in ("delivery", "maintenance", "initialize"))
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
        cold = copy.deepcopy(VALUES)
        tier = dict(endpoint='https://objects.example.invalid', region='us-east-1', bucket='proof',
                    prefix='installation', credentials_file='/secrets/object-credentials.json',
                    ca_file='/secrets/object-ca.pem')
        cold['node']['config']['storage'] = dict(object_storage=tier)
        configured = render(cold)
        config = json.loads(configured['ConfigMap', 'test-runtime-node']['data']['config.json'])
        assert config['storage']['object_storage'] == tier
        assert not any('ursula' in name for _, name in configured)
        store = configured['Deployment', 'test-runtime-node']['spec']['template']['spec']
        assert next(v for v in store['volumes'] if v['name'] == 'node-secrets')['secret'] == dict(secretName='node-credentials', defaultMode=288)
        assert not any(kind == "Secret" for kind, _ in configured)
        subprocess.run(["helm", "lint", "--strict", CHART, "-f", values_file], check=True)
        defaults = yaml.safe_load((CHART / "values.yaml").read_text())
        pins = json.loads((ROOT / "deploy/reference/versions.json").read_text())
        assert "ursula" not in defaults and "ursula" not in pins
        assert not any(kind in ("Secret", "Job", "RoleBinding", "ClusterRoleBinding") for kind, _ in manifests)
        station = copy.deepcopy(VALUES)
        station["controller"] = {"image": "example.invalid/runtime:proof"}
        station["runtimeControllers"] = [{"nameOverride": "runtime-ledger", "existingSecret": "runtime-ledger-key",
            "config": {"realm": 49, "principal": 8, "pid": 1, "worker": 1, "provider": {"authority_host": "transit.proof.svc.cluster.local", "container": "station"}}}]
        station['node']['station'] = dict(version=1, definition='fixture', realm=49, services=[
            dict(name='observer', principal=10, mode='observe', seed_file='/secrets/observer', watches=[dict(pid=1, resource=2)])])
        station['node']['config']['station'] = dict(file='/config/station.json')
        composed = render(station)
        for name in ("runtime-ledger",):
            spec = composed["Deployment", name]["spec"]["template"]["spec"]
            assert spec["automountServiceAccountToken"] is False
            assert next(v["secret"]["secretName"] for v in spec["volumes"] if "secret" in v) == name + "-key"
            config = json.loads(composed["ConfigMap", name]["data"]["config.json"])
            assert config["url"] == "http://test-runtime-node:8080" and config["seed_file"] == "/secrets/seed"
        assert json.loads(composed['ConfigMap', 'test-runtime-node']['data']['station.json']) == station['node']['station']
        assert ('Deployment', 'station-observer') not in composed
        assert ('RoleBinding', 'runtime-ledger') in composed
        assert ('RoleBinding', 'station-observer') not in composed
        obsolete = copy.deepcopy(VALUES)
        obsolete['stationControllers'] = []
        render(obsolete, 'stationControllers')
        duplicate = copy.deepcopy(station)
        duplicate["runtimeControllers"].append(copy.deepcopy(duplicate["runtimeControllers"][0]))
        render(duplicate, "duplicate additional controller name")
        station["running"] = False
        stopped = render(station)
        assert stopped["Deployment", "runtime-ledger"]["spec"]["replicas"] == 0
        pvc = manifests["PersistentVolumeClaim", "test-runtime-node"]
        assert pvc["metadata"]["annotations"]["helm.sh/resource-policy"] == "keep"
        for component in ("node", "board"):
            deployment = manifests["Deployment", "test-runtime-" + component]
            assert deployment["spec"]["replicas"] == 1 and deployment["spec"]["strategy"]["type"] == "Recreate"
            spec = deployment["spec"]["template"]["spec"]
            assert spec["enableServiceLinks"] is False
            assert spec["automountServiceAccountToken"] is False
            assert spec["securityContext"]["runAsNonRoot"] is True
            assert spec["containers"][0]["securityContext"]["capabilities"]["drop"] == ["ALL"]
            assert "--initialize" not in spec["containers"][0]["args"]
            secrets = [v["secret"]["secretName"] for v in spec["volumes"] if "secret" in v]
            assert secrets == ([component + "-credentials"] if component in ("node", "board") else [])
        server = manifests["Deployment", "test-runtime-node"]["spec"]["template"]["spec"]
        assert server["containers"][0]["args"] == ["server", "--no-ui", "--config", "/config/config.json"]
        config = json.loads(manifests["ConfigMap", "test-runtime-node"]["data"]["config.json"])
        assert config["external"]["root_seed_file"] == "/secrets/root"
        assert "ursula" not in config["external"]
        assert config["installation"] == "/data/installation"
        assert ("PersistentVolumeClaim", "test-runtime-node") in manifests
        assert not any(name.endswith(("-delivery", "-maintenance", "-initialize")) for _, name in manifests)
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
        assert ("PersistentVolumeClaim", "test-runtime-node") in rendered

        minimal = copy.deepcopy(VALUES)
        minimal["board"]["enabled"] = False
        for retired in ("initialize", "maintenance", "delivery"):
            old = copy.deepcopy(minimal)
            old[retired] = {"enabled": True}
            render(old, retired)
        obsolete = copy.deepcopy(minimal)
        obsolete['ursula'] = dict(enabled=False)
        render(obsolete, 'ursula')
        obsolete = copy.deepcopy(minimal)
        obsolete['node']['config']['external']['ursula'] = dict(url='http://old:8080')
        render(obsolete, 'external.ursula is unsupported')
        local = copy.deepcopy(minimal)
        local['node']['config']['external'] = {'listen': '0.0.0.0'}
        local['node']['existingSecret'] = 'native-owner-credentials'
        rendered = render(local)
        assert ('PersistentVolumeClaim', 'test-runtime-node') in rendered
        assert not any('ursula' in name for _, name in rendered)
        pod = rendered['Deployment', 'test-runtime-node']['spec']['template']['spec']
        assert next(v for v in pod['volumes'] if v['name'] == 'node-secrets')['secret']['secretName'] == 'native-owner-credentials'
        local['node']['persistence'] = dict(existingClaim='retained-native')
        rendered = render(local)
        assert not any(kind == 'PersistentVolumeClaim' for kind, _ in rendered)
        for component in ("node", "board"):
            invalid = copy.deepcopy(VALUES)
            invalid[component]["existingSecret"] = ""
            render(invalid, component + ".existingSecret")
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
    print("Transit chart: server bootstrap, private credentials, retained storage and network boundaries passed.")


if __name__ == "__main__":
    run()
    from interfaces.deployment.standalone_chart import run as standalone
    standalone()
