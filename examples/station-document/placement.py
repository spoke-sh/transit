"""Reuse physical operator tooling; Document semantics remain in Zig binaries."""
import base64
import json
from pathlib import Path
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "exchange"))
from compose import Compose as BaseCompose
from reference import Reference as BaseReference


class Compose(BaseCompose):
    def __init__(self, work):
        super().__init__(work, "document")
        self.command[-1] = str(Path(__file__).with_name("docker-compose.yaml"))

    def invoke(self, service, *args):
        return json.loads(self.call("run", "--rm", "--no-deps", "-T", service, *args, timeout=900))

    def stop_for_recovery(self, service, process):
        process.kill()
        process.wait(timeout=10)


class Reference(BaseReference):
    def __init__(self, work, protocol="document"):
        super().__init__(work, protocol)

    def deploy(self):
        # Keep storage credentials out of values, ConfigMaps and Helm history.
        name = self.protocol + "-store-config"
        self.apply({"apiVersion": "v1", "kind": "Secret", "metadata": {"name": name},
                    "data": {"ursula.toml": base64.b64encode((self.work / "ursula.toml").read_bytes()).decode()}})
        self.values["ursula"]["existingConfigSecret"] = name
        return super().deploy()

    def stop_for_recovery(self, service, process):
        # Hold replacements until the durable store has recovered. Deleting a
        # Deployment pod alone immediately creates another running executor.
        self.kube("scale", "deployment/" + service, "--replicas=0", "--current-replicas=1")
        process.kill()
        process.wait(timeout=10)
        deployment = self.get("deployment", service)
        selector = ",".join(k + "=" + v for k, v in deployment["spec"]["selector"]["matchLabels"].items())
        self.kube("wait", "--for=delete", "pod", "-l", selector, "--timeout=60s")

    def start(self, service):
        self.setup()
        if self.get("deployment", service)["spec"]["replicas"] == 0:
            self.kube("scale", "deployment/" + service, "--replicas=1", "--current-replicas=0")
        return super().start(service)

    def finish(self, handle):
        deadline = time.monotonic() + 180
        while time.monotonic() < deadline:
            values = [m for m in self.messages(handle) if "phase" in m or "revision" in m or "epoch" in m]
            if values:
                assert len(values) == 1
                return values[0]
            time.sleep(.2)
        raise TimeoutError("Substrate Document editor did not complete: " + self.actor_logs(handle)[-3000:])

    def invoke(self, service, *args):
        if service == "caller-probe":
            return super().invoke(service, *args)
        if service != "writer": raise RuntimeError("Unsupported Document invocation")
        self.counter += 1
        name = "writer-" + str(self.counter)
        self.secret(name, self.work / "writer")
        dns = json.loads(self.kube("get", "service", "kube-dns", "-n", "kube-system", "-o", "json"))["spec"]["clusterIP"]
        node = self.address("node")
        rules = f'''set -eu
iptables -w -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -w -A OUTPUT -p tcp -d {node} --dport 8080 -j ACCEPT
iptables -w -A OUTPUT -p udp -d {dns} --dport 53 -j ACCEPT
iptables -w -A OUTPUT -p tcp -d {dns} --dport 53 -j ACCEPT
iptables -w -A OUTPUT -p tcp -j REJECT --reject-with tcp-reset
iptables -w -A OUTPUT -j REJECT
ip6tables -w -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
ip6tables -w -A OUTPUT -p tcp -j REJECT --reject-with tcp-reset
ip6tables -w -A OUTPUT -j REJECT
'''
        targets = [self.address("ursula")+":8080", self.cold_address+":9000", "1.1.1.1:443"]
        for namespace, target in (("default", "kubernetes"), ("ate-system", "api")):
            address = json.loads(self.kube("get", "service", target, "-n", namespace, "-o", "json"))["spec"]["clusterIP"]
            targets.append(address+":443")
        secure = {"allowPrivilegeEscalation": False, "readOnlyRootFilesystem": True, "capabilities": {"drop": ["ALL"]}}
        self.apply({"apiVersion": "v1", "kind": "Pod", "metadata": {"name": name}, "spec": {
            "restartPolicy": "Never", "automountServiceAccountToken": False,
            "securityContext": {"runAsUser": 65532, "runAsGroup": 65532, "runAsNonRoot": True, "fsGroup": 65532},
            "initContainers": [
                {"name": "egress", "image": self.pins["kind_node"], "command": ["sh", "-ec", rules],
                 "securityContext": {"runAsUser": 0, "runAsNonRoot": False, "allowPrivilegeEscalation": False, "capabilities": {"drop": ["ALL"], "add": ["NET_ADMIN"]}}},
                {"name": "probe", "image": self.env["EXCHANGE_PEER_IMAGE"], "args": ["probe", self.authority, *targets], "securityContext": secure}],
            "containers": [{"name": "writer", "image": self.env["EXCHANGE_CONNECTOR_IMAGE"], "args": ["/writer/config.json"],
                "securityContext": secure, "env": [{"name": "LOG_LEVEL", "value": "warn"}],
                "resources": {"requests": {"cpu": "100m", "memory": "64Mi"}, "limits": {"cpu": "1", "memory": "512Mi"}},
                "volumeMounts": [{"name": "files", "mountPath": "/writer", "readOnly": True}, {"name": "activations", "mountPath": "/activations"}]}],
            "volumes": [{"name": "files", "secret": {"secretName": name}}, {"name": "activations", "emptyDir": {}}]}})
        deadline = time.monotonic() + 600
        while time.monotonic() < deadline:
            pod = self.get("pod", name)
            if pod["status"]["phase"] in ("Succeeded", "Failed"):
                if pod["status"]["phase"] != "Succeeded":
                    terminated = [c for c in pod["status"].get("initContainerStatuses", []) + pod["status"].get("containerStatuses", []) if "terminated" in c["state"] and c["state"]["terminated"]["exitCode"] != 0]
                    details = "\n".join(self.kube("logs", name, "-c", c["name"]) for c in terminated)
                    raise RuntimeError("Document writer failed: " + details[-3000:])
                stdout = self.kube("logs", name, "-c", "writer")
                assert json.loads(self.kube("logs", name, "-c", "probe")) == dict(authority="reachable", denied=len(targets))
                values = [json.loads(line) for line in stdout.splitlines() if line.startswith('{"phase"')]
                assert len(values) == 1
                self.kube("delete", "pod", name, "--wait=true")
                self.kube("delete", "secret", name)
                return values[0]
            time.sleep(.2)
        raise TimeoutError("Reference Document writer did not finish")
