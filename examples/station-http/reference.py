"""Finite operator placement in an isolated namespace of the owned reference cluster.

The caller runs in Substrate/gVisor; the trusted effect worker runs in an egress-
confined pod. This does not create growing runtime bindings or a second authority.
"""
import base64
import json
import os
from pathlib import Path
import socket
import shutil
import subprocess
import sys
import time
import uuid

from compose import Compose, ROOT


class Pod:
    def __init__(self, placement, name, uid):
        self.placement, self.name, self.uid = placement, name, uid

    def poll(self):
        value = self.placement.get("pod", self.name, missing=True)
        if value is None or value["metadata"]["uid"] != self.uid: return 0
        return None if value["status"]["phase"] in ("Pending", "Running") else 0

    def kill(self):
        value = self.placement.get("pod", self.name, missing=True)
        if value and value["metadata"]["uid"] == self.uid:
            self.placement.kube("delete", "pod", self.name, "--grace-period=0", "--force", "--wait=true")

    def wait(self, timeout):
        deadline = time.monotonic() + timeout
        while self.poll() is None:
            if time.monotonic() >= deadline: raise TimeoutError("Pod did not stop")
            time.sleep(.1)


class Reference(Compose):
    def __init__(self, work):
        if sys.platform != "linux" or os.uname().machine != "x86_64":
            raise RuntimeError("The reference HTTP example currently requires Linux x86_64")
        if not (ROOT / ".cache/reference/state.json").exists() or not (ROOT / ".cache/reference/runtime-image.json").exists():
            raise RuntimeError("Prepare the owned reference infrastructure and runtime image before this task; see the reference launcher guide")
        self.state = json.loads((ROOT / ".cache/reference/state.json").read_text())
        self.pins = json.loads((ROOT / "deploy/reference/versions.json").read_text())
        self.runtime = json.loads((ROOT / ".cache/reference/runtime-image.json").read_text())
        if self.runtime["registry"] != self.state["registry_id"] or self.runtime["revision"] != self.pins["substrate"]:
            raise RuntimeError("Reference runtime image does not match the owned infrastructure")
        self.context = ["--kubeconfig", str(ROOT / ".cache/reference/kubeconfig"), "--context", "kind-" + self.state["cluster"]]
        self.namespace = "transit-http-" + uuid.uuid4().hex[:10]
        self.namespace_uid = None
        self.forwards = {}
        self.actors = []
        self.counter = 0
        self.values = None
        super().__init__(work)
        prefix = ROOT / ".cache/http-example/images"
        subprocess.run(["zig", "build", "probe", "-Doptimize=ReleaseSafe", "-Dtarget=x86_64-linux-musl", "--prefix", str(prefix / "static")], cwd=ROOT, check=True, timeout=300)
        probe = prefix / "probe"
        probe.mkdir(exist_ok=True)
        (probe / "app").unlink(missing_ok=True)
        shutil.copyfile(prefix / "static/bin/isolation-probe", probe / "app")
        (probe / "app").chmod(0o555)
        (probe / "Dockerfile").write_text('FROM scratch\nCOPY app /bin/app\nENTRYPOINT ["/bin/app"]\n')
        self.env["HTTP_PROBE_IMAGE"] = self.image(probe)
        # Only publish the images built for this example, never update services
        # or provider infrastructure in an existing application namespace.
        for role in ("NODE", "CALLER", "CONNECTOR", "PEER", "PROBE"):
            image = self.env["HTTP_" + role + "_IMAGE"]
            repository = f"localhost:{self.state['port']}/transit-http-example-{role.lower()}"
            tag = repository + ":" + image.split(":")[1][:16]
            subprocess.run(["docker", "tag", image, tag], check=True, timeout=15)
            subprocess.run(["docker", "push", tag], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, timeout=180)
            records = json.loads(subprocess.check_output(["docker", "inspect", tag], text=True))
            self.env["HTTP_" + role + "_IMAGE"] = next(d for d in records[0]["RepoDigests"] if d.startswith(repository + "@"))

    @property
    def authority(self):
        return f"http://node.{self.namespace}.svc.cluster.local:8080"

    def kube(self, *args, input=None, timeout=180, missing=False):
        result = subprocess.run(["kubectl", *self.context, "-n", self.namespace, *args], input=input,
                                text=True, capture_output=True, timeout=timeout)
        if result.returncode:
            if missing and "NotFound" in result.stderr: return None
            raise RuntimeError(result.stderr[-4000:])
        return result.stdout

    def ate(self, *args, missing=False):
        result = subprocess.run(["kubectl-ate", *self.context, "-o", "json", *map(str, args)],
                                text=True, capture_output=True, timeout=45)
        if result.returncode:
            if missing and ("NotFound" in result.stderr or "not found" in result.stderr): return None
            raise RuntimeError(result.stderr[-4000:])
        return result.stdout

    def get(self, kind, name, missing=False):
        value = self.kube("get", kind, name, "-o", "json", missing=missing)
        return json.loads(value) if value else None

    def apply(self, value):
        self.kube("apply", "-f", "-", input=json.dumps(value))

    def setup(self):
        if self.namespace_uid is not None: return
        # Create, never adopt. Cleanup checks the recorded UID before deletion.
        self.kube("create", "namespace", self.namespace)
        self.namespace_uid = self.get("namespace", self.namespace)["metadata"]["uid"]
        self.values = {"node": {"nameOverride": "node", "enabled": False, "image": self.env["HTTP_NODE_IMAGE"],
                                  "config": json.loads((self.work / "operator/node.json").read_text())},
                       "initialize": {"nameOverride": "initialize", "enabled": False},
                       "ursula": {"nameOverride": "ursula", "image": self.env["HTTP_URSULA_IMAGE"]},
                       "workerPool": {"nameOverride": "caller", "enabled": True, "labels": {"transit.dev/http-example": self.namespace},
                           "spec": {"replicas": 2, "workerImage": self.runtime["image"], "template": {
                               "nodeSelector": {"ate.dev/substrate-version": self.pins["substrate"][:7]},
                               "resources": {"requests": {"cpu": "100m", "memory": "512Mi"}, "limits": {"cpu": "1", "memory": "1Gi"}}}}}}
        self.deploy()
        self.ate("create", "atespace", self.namespace)

    def deploy(self):
        values = self.work / "reference-values.json"
        values.write_text(json.dumps(self.values))
        result = subprocess.run(["helm", "--kubeconfig", self.context[1], "--kube-context", self.context[3],
            "upgrade", "--install", "http-example", str(ROOT / "charts/transit"), "--namespace", self.namespace,
            "--values", str(values), "--wait", "--wait-for-jobs", "--timeout", "180s", "--history-max", "3"],
            capture_output=True, text=True, timeout=200)
        if result.returncode: raise RuntimeError(result.stderr[-4000:])

    def initialize(self):
        self.values["initialize"]["enabled"] = True
        self.deploy()
        self.values["initialize"]["enabled"] = False
        self.values["node"]["enabled"] = True
        self.deploy()

    def wait_pod(self, service):
        self.kube("rollout", "status", "deployment/" + service, "--timeout=180s")
        deployment = self.get("deployment", service)
        selector = deployment["spec"]["selector"]["matchLabels"]
        deadline = time.monotonic() + 180
        while time.monotonic() < deadline:
            pods = json.loads(self.kube("get", "pods", "-l", ",".join(k + "=" + v for k, v in selector.items()), "-o", "json"))["items"]
            for pod in pods:
                if not pod["metadata"].get("deletionTimestamp") and any(c["type"] == "Ready" and c["status"] == "True" for c in pod["status"].get("conditions", [])):
                    return Pod(self, pod["metadata"]["name"], pod["metadata"]["uid"])
            time.sleep(.2)
        raise TimeoutError("No ready pod for " + service)

    def start(self, service):
        self.setup()
        if service == "peer":
            self.secret("peer-files", self.work / "peer")
            container = {"name": "peer", "image": self.env["HTTP_PEER_IMAGE"], "args": ["/peer/config.json"],
                         "volumeMounts": [{"name": "files", "mountPath": "/peer", "readOnly": True}, {"name": "output", "mountPath": "/peer-output"}],
                         "readinessProbe": {"tcpSocket": {"port": 8443}, "periodSeconds": 1}}
            self.pod_deployment("peer", container, [{"name": "files", "secret": {"secretName": "peer-files"}}, {"name": "output", "emptyDir": {}}])
            self.apply({"apiVersion": "v1", "kind": "Service", "metadata": {"name": "peer"},
                        "spec": {"selector": {"app": "http-peer"}, "ports": [{"port": 8443, "targetPort": 8443}]}})
        return self.wait_pod(service)

    def url(self, service):
        previous = self.forwards.get(service)
        if previous:
            previous[0].terminate(); previous[0].wait(timeout=10)
            previous[2].close()
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", 0))
            port = listener.getsockname()[1]
        log = (self.work / (service + "-forward.log")).open("w+")
        forward = subprocess.Popen(["kubectl", *self.context, "-n", self.namespace, "port-forward", "service/" + service, f"{port}:8080"], stdout=log, stderr=subprocess.STDOUT)
        self.forwards[service] = (forward, port, log)
        return f"http://127.0.0.1:{port}"

    def address(self, service, network=None):
        return self.get("service", service)["spec"]["clusterIP"]

    def secret(self, name, directory):
        data = {p.name: base64.b64encode(p.read_bytes()).decode() for p in directory.iterdir() if p.is_file() and p.name in ("seed.key", "credential", "ca.pem", "tls.key", "config.json")}
        self.apply({"apiVersion": "v1", "kind": "Secret", "metadata": {"name": name}, "data": data})

    def pod_deployment(self, name, container, volumes):
        container.update(securityContext={"allowPrivilegeEscalation": False, "readOnlyRootFilesystem": True, "capabilities": {"drop": ["ALL"]}},
                         resources={"requests": {"cpu": "100m", "memory": "64Mi"}, "limits": {"cpu": "1", "memory": "512Mi"}})
        self.apply({"apiVersion": "apps/v1", "kind": "Deployment", "metadata": {"name": name}, "spec": {
            "replicas": 1, "strategy": {"type": "Recreate"}, "selector": {"matchLabels": {"app": "http-" + name}},
            "template": {"metadata": {"labels": {"app": "http-" + name}}, "spec": {"automountServiceAccountToken": False,
                "securityContext": {"runAsUser": 65532, "runAsGroup": 65532, "runAsNonRoot": True, "fsGroup": 65532},
                "containers": [container], "volumes": volumes}}}})

    def caller_template(self, name, config):
        return {"metadata": {"atespace": self.namespace, "name": name},
            "workerSelector": {"matchLabels": {"transit.dev/http-example": self.namespace}},
            "containers": [{"name": "caller", "image": self.env["HTTP_CALLER_IMAGE"],
                "command": ["/bin/app", "--bootstrap-json", json.dumps(config)],
                "volumeMounts": [{"name": "runtime-data", "mountPath": "/runtime-data"}]}],
            "volumes": [{"name": "runtime-data", "durableDir": {}}],
            "resources": {"limits": [{"name": "cpu", "quantity": "1"}, {"name": "memory", "quantity": "512Mi"}]},
            "snapshotsConfig": {"storageLocation": f"gs://ate-snapshots/{self.namespace}/", "onPause": "SNAPSHOT_CONTENT_SCOPE_DATA",
                                "onCommit": "SNAPSHOT_CONTENT_SCOPE_DATA", "onResume": {"fromData": "RESUME_SOURCE_COLD_BOOT"}},
            "sandboxConfig": {"sandboxClass": "SANDBOX_CLASS_GVISOR", "configName": "gvisor-default"}}

    def actor(self, handle):
        actor = json.loads(self.ate("get", "actor", handle["name"], "-a", self.namespace))
        assert actor["metadata"]["uid"] == handle["uid"] and actor["actorTemplate"] == {"atespace": self.namespace, "name": handle["name"]}
        if actor["status"]["state"] == "ACTOR_STATE_RUNNING":
            assert actor["status"]["currentActorTemplateUid"] == handle["template_uid"]
        return actor

    def messages(self, handle):
        output = self.actor_logs(handle)
        values = []
        for line in output.splitlines():
            try:
                value = json.loads(line)
                if "message" in value:
                    value = json.loads(value["message"])
                else:
                    # Substrate attaches a physical log timestamp to JSON
                    # stdout; it is not part of the caller's durable result.
                    value.pop("time", None)
                if isinstance(value, dict): values.append(value)
            except (ValueError, TypeError): pass
        return values

    def actor_logs(self, handle):
        before = self.actor(handle)
        if before["status"]["state"] != "ACTOR_STATE_RUNNING": return ""
        worker = before["status"]["workerAssignment"]["workerPodUid"]
        pods = json.loads(self.kube("get", "pods", "-o", "json"))["items"]
        assert any(p["metadata"]["uid"] == worker for p in pods), "Registration came from an unexpected worker"
        output = self.ate("logs", "actor", handle["name"], "-a", self.namespace, "-c", "caller")
        after = self.actor(handle)
        assert after["status"]["workerAssignment"] == before["status"]["workerAssignment"] and after["status"]["state"] == "ACTOR_STATE_RUNNING"
        return output

    def launch_actor(self, template):
        name = template["metadata"]["name"]
        path = self.work / (name + "-template.json")
        path.write_text(json.dumps(template))
        created = json.loads(self.ate("create", "actor-template", "-f", path))
        actor = json.loads(self.ate("create", "actor", name, "-a", self.namespace, "--template", self.namespace + "/" + name))
        handle = {"name": name, "uid": actor["metadata"]["uid"], "template_uid": created["metadata"]["uid"]}
        self.actors.append(handle)
        policy = self.work / "caller-egress.json"
        policy.write_text(json.dumps({"rules": [{"hostnames": {"patterns": ["node." + self.namespace + ".svc.cluster.local"]}}]}))
        self.ate("create", "egress-policy", name, "-a", self.namespace, "-f", policy)
        assert json.loads(self.ate("get", "egress-policy", name, "-a", self.namespace))["rules"] == json.loads(policy.read_text())["rules"]
        deadline = time.monotonic() + 120
        while True:
            try:
                self.ate("resume", "actor", name, "-a", self.namespace)
                break
            except RuntimeError as error:
                if "ResourceExhausted" not in str(error) or time.monotonic() >= deadline: raise
                # A killed worker needs replacement capacity; a recorded Transit
                # owner is not a promise that the provider can place it yet.
                time.sleep(1)
        return handle

    def register(self, config):
        for handle in self.actors:
            if handle.get("stopped"): continue
            previous = self.actor(handle)
            if previous["status"]["state"] == "ACTOR_STATE_RUNNING":
                self.ate("suspend", "actor", handle["name"], "-a", self.namespace)
            handle["stopped"] = True
        self.counter += 1
        name = "caller-" + str(self.counter)
        config = config | {"url": self.authority, "park_after_result_ms": 300000}
        handle = self.launch_actor(self.caller_template(name, config))
        deadline = time.monotonic() + 180
        while time.monotonic() < deadline:
            registrations = [m["growing_bootstrap"] for m in self.messages(handle) if "growing_bootstrap" in m]
            if len(registrations) > 1: raise RuntimeError("Ambiguous physical registration")
            if registrations: return handle, registrations[0]
            time.sleep(.2)
        raise TimeoutError("Substrate caller did not register")

    def finish(self, handle):
        deadline = time.monotonic() + 180
        while time.monotonic() < deadline:
            values = [m for m in self.messages(handle) if "phase" in m]
            if values:
                assert len(values) == 1
                return values[0]
            time.sleep(.2)
        raise TimeoutError("Substrate caller did not complete")

    def kill_caller_worker(self):
        handle = self.actors[-1]
        actor = self.actor(handle)
        uid = actor["status"]["workerAssignment"]["workerPodUid"]
        pods = json.loads(self.kube("get", "pods", "-o", "json"))["items"]
        pod = next(p for p in pods if p["metadata"]["uid"] == uid)
        self.kube("delete", "pod", pod["metadata"]["name"], "--grace-period=0", "--force", "--wait=true")

    def peer_requests(self):
        pod = self.wait_pod("peer")
        executable = str(Path(sys.executable).resolve())
        return json.loads(self.kube("exec", pod.name, "-c", "peer", "--", executable, "-c", "print(open('/peer-output/requests.json').read())"))

    def stop_peer(self, peer):
        self.kube("scale", "deployment/peer", "--replicas=0")
        # Allow the Kubernetes termination grace period plus deletion propagation.
        peer.wait(timeout=90)

    def invoke(self, service, *args):
        if service == "caller-probe":
            template = self.caller_template("caller-probe", {})
            checks = [{"label": "target-" + str(i), "url": "http://" + target + "/"} for i, target in enumerate(args[2:])]
            checks += [{"label": "kubernetes", "url": "http://kubernetes.default.svc.cluster.local:443/"},
                       {"label": "substrate", "url": "http://api.ate-system.svc.cluster.local:443/"}]
            template["containers"][0].update(image=self.env["HTTP_PROBE_IMAGE"], command=["/bin/app", json.dumps({"authority": self.authority + "/health", "checks": checks})])
            handle = self.launch_actor(template)
            deadline = time.monotonic() + 180
            while time.monotonic() < deadline:
                logs = self.actor_logs(handle)
                if "denied=false" in logs or "error:" in logs: raise RuntimeError("Caller isolation probe failed: " + logs[-2000:])
                if "ISOLATION_PROOF_PASSED" in logs:
                    self.ate("suspend", "actor", handle["name"], "-a", self.namespace)
                    handle["stopped"] = True
                    return {"authority": "reachable", "denied": len(args[2:])}
                time.sleep(.2)
            raise TimeoutError("Caller isolation probe did not complete")
        if service != "connector": raise RuntimeError("Unsupported reference invocation")
        self.counter += 1
        name = "connector-" + str(self.counter)
        self.secret(name, self.work / "connector")
        dns = json.loads(self.kube("get", "service", "kube-dns", "-n", "kube-system", "-o", "json"))["spec"]["clusterIP"]
        node_ip, peer_ip = self.address("node"), self.address("peer")
        rules = f'''set -eu
iptables -w -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -w -A OUTPUT -p tcp -d {node_ip} --dport 8080 -j ACCEPT
iptables -w -A OUTPUT -p tcp -d {peer_ip} --dport 8443 -j ACCEPT
iptables -w -A OUTPUT -p udp -d {dns} --dport 53 -j ACCEPT
iptables -w -A OUTPUT -p tcp -d {dns} --dport 53 -j ACCEPT
iptables -w -A OUTPUT -p tcp -j REJECT --reject-with tcp-reset
iptables -w -A OUTPUT -j REJECT
ip6tables -w -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
ip6tables -w -A OUTPUT -p tcp -j REJECT --reject-with tcp-reset
ip6tables -w -A OUTPUT -j REJECT
'''
        denied = [self.address("ursula") + ":8080", "1.1.1.1:443"]
        for namespace, target in (("default", "kubernetes"), ("ate-system", "api")):
            address = json.loads(self.kube("get", "service", target, "-n", namespace, "-o", "json"))["spec"]["clusterIP"]
            denied.append(address + ":443")
        secure = {"allowPrivilegeEscalation": False, "readOnlyRootFilesystem": True, "capabilities": {"drop": ["ALL"]}}
        self.apply({"apiVersion": "v1", "kind": "Pod", "metadata": {"name": name}, "spec": {
            "restartPolicy": "Never", "automountServiceAccountToken": False,
            "securityContext": {"runAsUser": 65532, "runAsGroup": 65532, "runAsNonRoot": True, "fsGroup": 65532},
            "initContainers": [
                {"name": "egress", "image": self.pins["kind_node"], "command": ["sh", "-ec", rules],
                 "securityContext": {"runAsUser": 0, "runAsNonRoot": False, "allowPrivilegeEscalation": False, "capabilities": {"drop": ["ALL"], "add": ["NET_ADMIN"]}}},
                {"name": "probe", "image": self.env["HTTP_PEER_IMAGE"], "args": ["probe", self.authority, *denied], "securityContext": secure}],
            "containers": [{"name": "connector", "image": self.env["HTTP_CONNECTOR_IMAGE"], "args": ["/connector/config.json"],
                "securityContext": secure, "env": [{"name": "LOG_LEVEL", "value": "warn"}],
                "resources": {"requests": {"cpu": "100m", "memory": "64Mi"}, "limits": {"cpu": "1", "memory": "512Mi"}},
                "volumeMounts": [{"name": "files", "mountPath": "/connector", "readOnly": True}, {"name": "activations", "mountPath": "/activations"}]}],
            "volumes": [{"name": "files", "secret": {"secretName": name}}, {"name": "activations", "emptyDir": {}}]}})
        deadline = time.monotonic() + 180
        while time.monotonic() < deadline:
            pod = self.get("pod", name)
            if pod["status"]["phase"] in ("Succeeded", "Failed"):
                stdout = self.kube("logs", name, "-c", "connector")
                if pod["status"]["phase"] != "Succeeded": raise RuntimeError("Connector failed: " + stdout[-3000:])
                values = [json.loads(line) for line in stdout.splitlines() if line.startswith('{"exchange"')]
                assert len(values) == 1
                self.kube("delete", "pod", name, "--wait=true")
                self.kube("delete", "secret", name)
                return values[0]
            time.sleep(.2)
        raise TimeoutError("Reference connector did not finish")

    def call(self, *args, timeout=120):
        # Diagnostic compatibility with the runner; no Docker lifecycle here.
        if args[0] == "ps": return self.kube("get", "pods", "-o", "wide")
        if args[0] == "logs": return self.kube("logs", "-l", "app.kubernetes.io/instance=http-example", "--all-containers", "--tail=40", missing=True) or ""
        raise RuntimeError("Unsupported reference diagnostic operation")

    def close(self):
        for child, _, log in self.forwards.values():
            if child.poll() is None: child.terminate()
            child.wait(timeout=10); log.close()
        if self.namespace_uid is None: return
        current = self.get("namespace", self.namespace, missing=True)
        if not current or current["metadata"]["uid"] != self.namespace_uid: raise RuntimeError("Owned namespace changed; refusing cleanup")
        for handle in reversed(self.actors):
            actor = self.actor(handle)
            if actor["status"]["state"] == "ACTOR_STATE_RUNNING":
                self.ate("suspend", "actor", handle["name"], "-a", self.namespace)
            deadline = time.monotonic() + 120
            while self.actor(handle)["status"]["state"] in ("ACTOR_STATE_RUNNING", "ACTOR_STATE_SUSPENDING"):
                if time.monotonic() >= deadline: raise TimeoutError("Actor did not suspend for cleanup")
                time.sleep(.2)
            self.ate("delete", "actor", handle["name"], "-a", self.namespace, missing=True)
            self.ate("delete", "actor-template", handle["name"], "-a", self.namespace, missing=True)
        self.ate("delete", "atespace", self.namespace, missing=True)
        self.kube("delete", "namespace", self.namespace, "--wait=true", timeout=180)
