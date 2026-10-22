#!/usr/bin/env python3
"""Owned Linux/Docker reference cluster. Never uses the default kube context."""
import json
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import sys

from storage import free_port

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / ".cache/reference"
SOURCE = ROOT / ".cache/upstream/substrate"
PINS = json.loads((ROOT / "deploy/reference/versions.json").read_text())
STATE = CACHE / "state.json"


def run(argv, *, cwd=ROOT, env=None, capture=False, input=None, timeout=900):
    result = subprocess.run(list(map(str, argv)), cwd=cwd, env=env, text=True,
                            input=input, stdout=subprocess.PIPE if capture else None,
                            check=True, timeout=timeout)
    return result.stdout.strip() if capture else None


def go(args, env=None, capture=False):
    values = dict(os.environ, GOTOOLCHAIN=PINS["go"], GOMAXPROCS="4")
    values.update(env or {})
    return run(["nix", "shell", "--inputs-from", ROOT, "nixpkgs#go", "--command", *args],
               cwd=SOURCE, env=values, capture=capture)


def source():
    if not SOURCE.exists():
        SOURCE.parent.mkdir(parents=True, exist_ok=True)
        run(["git", "clone", "--no-checkout", "https://github.com/agent-substrate/substrate", SOURCE])
        run(["git", "fetch", "--depth=1", "origin", PINS["substrate"]], cwd=SOURCE)
        run(["git", "checkout", "--detach", PINS["substrate"]], cwd=SOURCE)
    if run(["git", "rev-parse", "HEAD"], cwd=SOURCE, capture=True) != PINS["substrate"]:
        raise RuntimeError("Substrate cache is at another revision; move it aside before just launchers::reference::up")
    if run(["git", "status", "--porcelain"], cwd=SOURCE, capture=True):
        raise RuntimeError("Substrate source cache is dirty; refusing to alter or build it")


def state():
    value = json.loads(STATE.read_text())
    if not value["cluster"].startswith("transit-m1") or not value["registry"].startswith("transit-m1"):
        raise RuntimeError("Invalid owned reference state")
    return value


def kube(s, args, **kwargs):
    return run(["kubectl", "--kubeconfig", CACHE / "kubeconfig", "--context", "kind-" + s["cluster"], *args], **kwargs)


def ate(s, args, **kwargs):
    return run([ate_binary(), "--kubeconfig", CACHE / "kubeconfig", "--context", "kind-" + s["cluster"], *args], **kwargs)


def ate_binary():
    binary = shutil.which("kubectl-ate")
    if binary is None:
        raise RuntimeError("Enter nix develop to use the pinned kubectl ate plugin")
    return str(Path(binary).resolve())


def up():
    if sys.platform != "linux" or os.uname().machine != "x86_64":
        raise RuntimeError("The first reference proof supports Linux x86_64 with Docker")
    if STATE.exists():
        raise RuntimeError("An owned reference cluster already exists; use just launchers::reference::up, or infra-down to destroy it")
    run(["docker", "info"], capture=True)
    source()
    CACHE.mkdir(parents=True, exist_ok=True)
    name = "transit-m1-" + secrets.token_hex(3)
    s = {"cluster": name, "registry": name + "-registry", "port": free_port(), "node_ids": []}
    # Record ownership before external operations, so interrupted setup is cleanable.
    STATE.write_text(json.dumps(s, indent=2))
    registry_id = run(["docker", "run", "-d", "--name", s["registry"],
                       "--label", "transit.reference=" + name, "-p", f"127.0.0.1:{s['port']}:5000", PINS["registry"]], capture=True)
    s["registry_id"] = registry_id
    STATE.write_text(json.dumps(s, indent=2))
    config = CACHE / "kind.yaml"
    config.write_text('''kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
featureGates:
  ClusterTrustBundle: true
  ClusterTrustBundleProjection: true
  PodCertificateRequest: true
runtimeConfig:
  certificates.k8s.io/v1beta1: "true"
networking:
  ipFamily: ipv4
nodes:
- role: control-plane
kubeadmConfigPatches:
- |
  kind: KubeletConfiguration
  containerLogMaxSize: "5Mi"
  containerLogMaxFiles: 3
containerdConfigPatches:
- |-
  [plugins."io.containerd.cri.v1.images".registry]
    config_path = "/etc/containerd/certs.d"
''')
    run(["kind", "create", "cluster", "--name", name, "--config", config,
         "--image", PINS["kind_node"], "--wait", "120s", "--kubeconfig", CACHE / "kubeconfig"])
    s["node_ids"] = run(["docker", "ps", "-aq", "--no-trunc", "--filter", "label=io.x-k8s.kind.cluster=" + name], capture=True).split()
    STATE.write_text(json.dumps(s, indent=2))
    run(["docker", "network", "connect", "kind", s["registry"]])
    host = f"localhost:{s['port']}"
    hosts = CACHE / "hosts.toml"
    hosts.write_text(f'[host."http://{s["registry"]}:5000"]\n  capabilities = ["pull", "resolve", "push"]\n')
    for node in s["node_ids"]:
        run(["docker", "exec", node, "mkdir", "-p", "/etc/containerd/certs.d/" + host])
        run(["docker", "cp", hosts, node + ":/etc/containerd/certs.d/" + host + "/hosts.toml"])
        run(["docker", "exec", node, "sysctl", "-w", "net.ipv4.conf.all.proxy_arp=1"])
    go(["hack/install-ate-kind.sh", "--deploy-ate-system"], {
        "KUBECONFIG": str(CACHE / "kubeconfig"), "KIND_CLUSTER_NAME": name,
        "KUBECTL_CONTEXT": "kind-" + name, "KO_DOCKER_REPO": host,
    })
    configure_registry(s)
    print("Reference infrastructure ready:", name)
    print("Kubeconfig:", CACHE / "kubeconfig")
    print("Use kubectl get nodes or kubectl ate get workers from the project Nix/direnv environment.")


def configure_registry(s):
    # Upstream's kind overlay hardcodes kind-registry. Use the IP of our owned
    # registry instead of changing shared Docker DNS or adopting that name.
    address = run(["docker", "inspect", s["registry"], "--format", "{{.NetworkSettings.Networks.kind.IPAddress}}"], capture=True)
    name = "atelet-" + PINS["substrate"][:7]
    daemon = json.loads(kube(s, ["-n", "ate-system", "get", "daemonset", name, "-o", "json"], capture=True))
    args = daemon["spec"]["template"]["spec"]["containers"][0]["args"]
    args = ["--localhost-registry-replacement=" + address + ":5000" if a.startswith("--localhost-registry-replacement=") else a for a in args]
    kube(s, ["-n", "ate-system", "patch", "daemonset", name, "--type=json", "-p", json.dumps([
        {"op": "replace", "path": "/spec/template/spec/containers/0/args", "value": args}])])
    kube(s, ["-n", "ate-system", "rollout", "status", "daemonset/" + name, "--timeout=120s"])


def images(s):
    source()
    CACHE.mkdir(parents=True, exist_ok=True)
    ate_binary()  # The shell and runtime controller share the Nix-packaged CLI.
    run(["zig", "build", "apps", "examples", "probe", "transit-board", "-Dtarget=x86_64-linux-musl", "-Doptimize=ReleaseSafe", "--prefix", CACHE / "bin"])
    host = f"localhost:{s['port']}"
    result = {}
    for name in ("transit-node", "example-counter", "isolation-probe", "transit-board"):
        context = CACHE / (name + "-image")
        context.mkdir(exist_ok=True)
        shutil.copy2(CACHE / "bin/bin" / name, context / name)
        # Zig's shared cache can originate in a private launcher (umask 077).
        # Published executables must also run as the image's non-root user.
        (context / name).chmod(0o755)
        (context / "Dockerfile").write_text(f'FROM scratch\nCOPY {name} /{name}\nUSER 65532:65532\nENTRYPOINT ["/{name}"]\n')
        tag = f"{host}/{name}:m1"
        run(["docker", "build", "-t", tag, context])
        run(["docker", "push", tag])
        digests = json.loads(run(["docker", "image", "inspect", tag, "--format", "{{json .RepoDigests}}"], capture=True))
        current = [value for value in digests if value.startswith(f"{host}/{name}@sha256:")]
        if len(current) != 1:
            raise RuntimeError(f"Expected one digest in the owned registry for {name}")
        result[name] = current[0]
    # Ursula publishes its own multi-platform image. Keep its release aligned
    # with the dev-shell overlay and pin the upstream manifest, without repacking.
    result["ursula"] = PINS["ursula"]
    result["ateom"] = go(["hack/run-tool.sh", "ko", "build", "--bare", "./cmd/ateom-gvisor"],
                         {"KO_DOCKER_REPO": host + "/ateom", "KO_DEFAULTPLATFORMS": "linux/amd64"}, capture=True)
    (CACHE / "images.json").write_text(json.dumps(result, indent=2))
    return result


def down():
    s = state()
    # Container IDs prevent a reused name from targeting someone else's resource.
    current = run(["docker", "ps", "-aq", "--no-trunc", "--filter", "label=io.x-k8s.kind.cluster=" + s["cluster"]], capture=True).split()
    if s["node_ids"] and set(current) - set(s["node_ids"]):
        raise RuntimeError("Reference node identity changed; refusing deletion")
    run(["kind", "delete", "cluster", "--name", s["cluster"], "--kubeconfig", CACHE / "kubeconfig"])
    registry = subprocess.run(["docker", "inspect", s["registry"], "--format", "{{.Id}}"], capture_output=True, text=True)
    if registry.returncode == 0:
        if registry.stdout.strip() != s.get("registry_id"):
            raise RuntimeError("Reference registry identity changed; refusing deletion")
        run(["docker", "rm", "-f", s["registry"]])
    STATE.unlink()
    print("Removed owned reference cluster and registry; default kubeconfig was untouched.")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: reference.py up|images|down")
    {"up": up, "images": lambda: images(state()), "down": down}[sys.argv[1]]()
