"""Board pod: read-only principal, namespace egress confinement and public views."""
import copy
import json
import os
from pathlib import Path
import time
import urllib.error
import urllib.request
import reference as ref
from storage import free_port


class Board:
    def __init__(self, s, directory, namespace, images, pid, command, key, apply, start):
        self.s, self.directory, self.namespace = s, directory, namespace
        self.http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        seed, public = key("board")
        command({"grant": {"subject": 4, "public_key": public, "permissions": 16}})
        self.access = os.urandom(32).hex()
        self.port = free_port()
        self.origin = "https://board.reference.invalid"
        authority = f"transit.{namespace}.svc.cluster.local"
        def service_ip(name, ns=namespace):
            address = json.loads(ref.kube(s, ["-n", ns, "get", "service", name, "-o", "json"], capture=True))["spec"]["clusterIP"]
            if address == "None":
                slices = json.loads(ref.kube(s, ["-n", ns, "get", "endpointslice", "-l", f"kubernetes.io/service-name={name}", "-o", "json"], capture=True))["items"]
                addresses = [address for item in slices for endpoint in item["endpoints"] if endpoint.get("conditions", {}).get("ready", False) for address in endpoint["addresses"]]
                assert addresses, f"Headless service {ns}/{name} has no ready endpoint"
                return addresses[0]
            return address
        transit_ip = service_ip("transit")
        dns_ip = service_ip("kube-dns", "kube-system")
        ursula_ip = service_ip("ursula")
        kube_ip = service_ip("kubernetes", "default")
        substrate_ip = service_ip("api", "ate-system")
        pods = json.loads(ref.kube(s, ["-n", namespace, "get", "pods", "-l", "app=ursula", "-o", "json"], capture=True))["items"]
        raw_ip = pods[0]["status"]["podIP"]
        config = {"upstream": f"http://{authority}:8080", "realm": 49, "principal": 4,
                  "seed_file": "/board-secrets/seed", "credential_file": "/board-secrets/access",
                  "public_origin": self.origin, "listen": "0.0.0.0", "port": 8080,
                  "request_timeout_ms": 3000, "upstream_timeout_ms": 2000,
                  "lenses": [{"pid": pid, "kind": "rey.example.counter", "version": 1}]}
        apply({"apiVersion": "v1", "kind": "ConfigMap", "metadata": {"name": "board", "namespace": namespace}, "data": {"board.json": json.dumps(config)}})
        apply({"apiVersion": "v1", "kind": "Secret", "metadata": {"name": "board", "namespace": namespace},
               "stringData": {"seed": seed.read_text(), "access": self.access}})
        # Kind's default CNI does not enforce NetworkPolicy. Apply rules in this
        # owned pod network namespace, then drop NET_ADMIN from both containers.
        # This is reference-fixture plumbing, not a claimed portable K8s policy.
        rules = f'''set -eu
iptables -w -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -w -A OUTPUT -p tcp -d 127.0.0.1 --dport 8080 -j ACCEPT
iptables -w -A OUTPUT -p tcp -d {transit_ip} --dport 8080 -j ACCEPT
iptables -w -A OUTPUT -p udp -d {dns_ip} --dport 53 -j ACCEPT
iptables -w -A OUTPUT -p tcp -d {dns_ip} --dport 53 -j ACCEPT
iptables -w -A OUTPUT -p tcp -j REJECT --reject-with tcp-reset
iptables -w -A OUTPUT -j REJECT
ip6tables -w -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
ip6tables -w -A OUTPUT -p tcp -j REJECT --reject-with tcp-reset
ip6tables -w -A OUTPUT -j REJECT
'''
        checks = [{"label": label, "url": url, "deny_at_transport": True} for label, url in [
            ("raw-service", f"http://{ursula_ip}:8080/rey-reference/authority?record=0"),
            ("raw-pod", f"http://{raw_ip}:8080/rey-reference/authority?record=0"),
            ("raw-admin", f"http://{raw_ip}:8081/metrics"),
            ("substrate", f"http://{substrate_ip}:443/"),
            ("kubernetes", f"http://{kube_ip}:443/"),
        ]]
        hardened = {"allowPrivilegeEscalation": False, "readOnlyRootFilesystem": True, "capabilities": {"drop": ["ALL"]}}
        pod = {"automountServiceAccountToken": False,
               "securityContext": {"runAsNonRoot": True, "runAsUser": 65532, "runAsGroup": 65532, "fsGroup": 65532},
               "initContainers": [{"name": "egress", "image": ref.PINS["kind_node"], "command": ["sh", "-ec", rules],
                                   "securityContext": {"runAsNonRoot": False, "runAsUser": 0, "allowPrivilegeEscalation": False, "capabilities": {"drop": ["ALL"], "add": ["NET_ADMIN"]}}}],
               "containers": [{"name": "board", "image": images["board"], "env": [{"name": "LOG_FORMAT", "value": "json"}, {"name": "LOG_LEVEL", "value": "info"}], "args": ["/board-config/board.json"], "securityContext": hardened,
                               "resources": {"requests": {"cpu": "100m", "memory": "64Mi"}, "limits": {"cpu": "1", "memory": "256Mi"}},
                               "volumeMounts": [{"name": "config", "mountPath": "/board-config", "readOnly": True}, {"name": "secrets", "mountPath": "/board-secrets", "readOnly": True}],
                               "readinessProbe": {"httpGet": {"path": "/health", "port": 8080, "httpHeaders": [{"name": "Host", "value": "board.reference.invalid"}]}, "periodSeconds": 2}},
                              {"name": "probe", "image": images["isolation-probe"], "args": [json.dumps({"authority": f"http://{authority}:8080/health", "checks": checks})], "securityContext": copy.deepcopy(hardened),
                               "resources": {"requests": {"cpu": "10m", "memory": "16Mi"}, "limits": {"cpu": "100m", "memory": "64Mi"}}}],
               "volumes": [{"name": "config", "configMap": {"name": "board"}}, {"name": "secrets", "secret": {"secretName": "board", "defaultMode": 0o440}}]}
        apply({"apiVersion": "apps/v1", "kind": "Deployment", "metadata": {"name": "board", "namespace": namespace},
               "spec": {"replicas": 1, "selector": {"matchLabels": {"app": "board"}}, "template": {"metadata": {"labels": {"app": "board"}}, "spec": pod}}})
        ref.kube(s, ["-n", namespace, "rollout", "status", "deployment/board", "--timeout=180s"])
        self.forward, _ = start(["kubectl", "--kubeconfig", ref.CACHE / "kubeconfig", "--context", "kind-" + s["cluster"],
                                 "-n", namespace, "port-forward", "deployment/board", f"{self.port}:8080"], "board-forward")
        deadline = time.monotonic() + 30
        while True:
            try:
                self.read("capabilities")
                break
            except (OSError, TimeoutError):
                assert time.monotonic() < deadline
                time.sleep(.2)
        transcript = ref.kube(s, ["-n", namespace, "logs", "deployment/board", "-c", "probe"], capture=True)
        assert "ISOLATION_PROOF_PASSED" in transcript, transcript
        (directory / "board-isolation.log").write_text(transcript)
        self.evidence = {"profile": "single-realm shared read-only principal", "isolation": transcript, "observations": []}

    def read(self, resource):
        for _ in range(30):
            request = urllib.request.Request(f"http://127.0.0.1:{self.port}/api/v1/{resource}",
                                            headers={"Host": "board.reference.invalid", "Authorization": f"Bearer {self.access}"})
            try:
                with self.http.open(request, timeout=5) as response:
                    return json.load(response)
            except urllib.error.HTTPError as error:
                if error.code not in (409, 429, 503):
                    raise
                time.sleep(.2)
        raise TimeoutError("Board observation did not settle")

    def process(self, pid):
        response = self.read(f"processes/{pid}")
        self.evidence["observations"].append({"pid": pid, "cut": response["observation"]["cut"], "process": response["observation"]["processes"][0]})
        return response["observation"]["processes"][0]
