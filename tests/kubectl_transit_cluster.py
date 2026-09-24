#!/usr/bin/env python3
"""Plugin qualification in an owned namespace on an already-running reference."""
import json
from pathlib import Path
import secrets
import signal
import subprocess
import sys
import tempfile
import time
import urllib.request

import yaml

import reference as ref
from storage import free_port


def run(binary):
    binary = Path(binary).resolve()
    state = ref.state()
    context = "kind-" + state["cluster"]
    kubeconfig = ref.CACHE / "kubeconfig"
    namespace = "transit-plugin-" + secrets.token_hex(4)
    release = "inspection"
    port = free_port()
    origin = f"http://127.0.0.1:{port}"
    prefix = [str(binary), "--kubeconfig", str(kubeconfig), "--context", context,
              "--namespace", namespace, "--release", release]

    def plugin(*args):
        return subprocess.run([*prefix, *args], text=True, capture_output=True,
                              check=True, timeout=25).stdout

    # Reuse the cluster's installed CoreDNS image as a disposable HTTP health
    # responder. This tests forwarding, not Board's authentication/protocol.
    dns = json.loads(ref.kube(state, ["get", "deployment", "coredns", "-n", "kube-system", "-o", "json"], capture=True))
    image = dns["spec"]["template"]["spec"]["containers"][0]["image"]
    created = json.loads(ref.kube(state, ["create", "namespace", namespace, "-o", "json"], capture=True))
    uid = created["metadata"]["uid"]
    tunnel = None
    try:
        with tempfile.TemporaryDirectory(prefix="transit-plugin-chart-") as temp:
            values = Path(temp) / "values.json"
            values.write_text(json.dumps({
                "node": {"image": image, "nameOverride": "authority-custom", "config": {"genesis": {"realm": 1}, "ursula_url": "http://unused:8080"}},
                "ursula": {"enabled": False}, "networkPolicy": {"enabled": False},
                "board": {"enabled": True, "image": image, "nameOverride": "inspection-custom",
                          "existingSecret": "unused-fixture", "config": {"public_origin": origin}},
            }))
            rendered = subprocess.check_output(["helm", "template", release, ref.ROOT / "charts/transit",
                                                "-n", namespace, "-f", values], text=True)
        resources = list(yaml.safe_load_all(rendered))
        for resource in resources:
            if resource["kind"] != "Deployment":
                continue
            if resource["metadata"]["labels"]["app.kubernetes.io/component"] == "node":
                resource["spec"]["replicas"] = 0
                continue
            resource["spec"]["template"]["spec"] = {
                "automountServiceAccountToken": False,
                "containers": [{"name": "fixture", "image": image, "imagePullPolicy": "IfNotPresent",
                                "args": ["-conf", "/config/Corefile"], "ports": [{"name": "http", "containerPort": 8080}],
                                "readinessProbe": {"httpGet": {"path": "/health", "port": "http"}},
                                "resources": {"requests": {"cpu": "10m", "memory": "16Mi"},
                                              "limits": {"cpu": "100m", "memory": "64Mi"}},
                                "volumeMounts": [{"name": "config", "mountPath": "/config", "readOnly": True}]}],
                "volumes": [{"name": "config", "configMap": {"name": "diagnostic-input"}}],
            }
        resources.append({"apiVersion": "v1", "kind": "ConfigMap", "metadata": {"name": "diagnostic-input"},
                          "data": {"Corefile": ".:1053 {\n  health :8080\n  errors\n}\n"}})
        ref.kube(state, ["create", "-n", namespace, "-f", "-"],
                 input=json.dumps({"apiVersion": "v1", "kind": "List", "items": resources}), capture=True)
        ref.kube(state, ["rollout", "status", "deployment/inspection-custom", "-n", namespace, "--timeout=90s"])
        installations = json.loads(plugin("get", "installations", "-o", "json"))
        assert [item["metadata"]["name"] for item in installations["items"]] == ["authority-custom"]
        assert "inspection-custom" in plugin("status")
        assert any(item["kind"] == "Pod" for item in json.loads(plugin("get", "workloads", "-o", "json"))["items"])
        assert "CoreDNS" in plugin("logs", "board", "--tail", "10")
        assert plugin("board").strip() == origin
        # An unrelated release must not silently adopt these resources.
        result = subprocess.run([*prefix, "status", "--release", "missing"], text=True, capture_output=True, timeout=25)
        assert result.returncode != 0 and "ResourceNotFound" in result.stderr
        with tempfile.TemporaryFile(mode="w+") as log:
            tunnel = subprocess.Popen([*prefix, "board", "--port-forward"], stdout=log, stderr=log, text=True)
            deadline = time.monotonic() + 20
            opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
            while True:
                assert tunnel.poll() is None, "port-forward exited early"
                try:
                    with opener.open(origin + "/health", timeout=1) as response:
                        assert response.status == 200
                    break
                except OSError:
                    if time.monotonic() >= deadline:
                        log.seek(0)
                        raise AssertionError(log.read())
                    time.sleep(0.1)
            tunnel.send_signal(signal.SIGINT)
            tunnel.wait(timeout=5)
            # The listener must disappear with the foreground process.
            try:
                opener.open(origin + "/health", timeout=1)
            except OSError:
                pass
            else:
                raise AssertionError("port-forward listener survived interruption")
        print("Reference plugin: real chart labels/name overrides, discovery, status, logs and loopback forwarding passed.")
    finally:
        if tunnel is not None and tunnel.poll() is None:
            tunnel.terminate()
            try:
                tunnel.wait(timeout=5)
            except subprocess.TimeoutExpired:
                tunnel.kill()
                tunnel.wait()
        current = json.loads(ref.kube(state, ["get", "namespace", namespace, "-o", "json"], capture=True))
        if current["metadata"]["uid"] != uid:
            raise RuntimeError("Test namespace identity changed; refusing cleanup")
        ref.kube(state, ["delete", "namespace", namespace, "--wait=true", "--timeout=90s"])


if __name__ == "__main__":
    run(sys.argv[1])
