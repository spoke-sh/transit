#!/usr/bin/env python3
"""Exercise the real Zig CLI at its kubectl boundary; no cluster or credentials."""
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import tempfile
import time

FAKE = r'''#!/usr/bin/env python3
import json, os, signal, sys, time
from pathlib import Path
with open(os.environ["CALLS"], "a") as f:
    f.write(json.dumps(sys.argv[1:]) + "\n")
mode = os.environ.get("MODE", "normal")
if mode == "failure":
    print("Error from server (Forbidden): denied by Kubernetes", file=sys.stderr)
    sys.exit(7)
if mode == "oversize":
    print("x" * (1024 * 1024 + 1))
    sys.exit(0)
if mode == "oversize-error":
    print("x" * (32 * 1024 + 1), file=sys.stderr)
    sys.exit(0)
if mode in ("stream", "closed-hang"):
    def stop(sig, frame):
        Path(os.environ["STOPPED"]).write_text(str(sig))
        sys.exit(0)
    signal.signal(signal.SIGINT, stop)
    signal.signal(signal.SIGTERM, stop)
    Path(os.environ["CHILD_PID"]).write_text(str(os.getpid()))
    if mode == "closed-hang":
        os.close(1)
        os.close(2)
    while True:
        signal.pause()
if "logs" in sys.argv or "port-forward" in sys.argv:
    print("live output")
    sys.exit(0)
resource = sys.argv[sys.argv.index("get") + 1]
fixtures = json.loads(Path(os.environ["FIXTURES"]).read_text())
result = fixtures.get(resource, {"apiVersion":"v1", "kind":"List", "items":[]})
selector = dict(part.split("=", 1) for part in sys.argv[sys.argv.index("--selector") + 1].split(","))
namespace = sys.argv[sys.argv.index("--namespace") + 1] if "--namespace" in sys.argv else "demo"
result["items"] = [item for item in result["items"]
    if ("--all-namespaces" in sys.argv or item["metadata"]["namespace"] == namespace)
    and all(item["metadata"].get("labels", {}).get(key) == value for key, value in selector.items())]
print(json.dumps(result))
'''


def fixture(kind, component, name):
    return {"apiVersion": "v1", "kind": kind, "metadata": {
        "namespace": "demo", "name": name, "labels": {
            "app.kubernetes.io/name": "transit",
            "app.kubernetes.io/instance": "example",
            "app.kubernetes.io/component": component}}}


def listed(*resources):
    return {"apiVersion": "v1", "kind": "List", "items": list(resources)}


def wait_file(path, process):
    deadline = time.monotonic() + 5
    while not path.exists():
        assert process.poll() is None, process.communicate()
        assert time.monotonic() < deadline, "child did not start"
        time.sleep(0.02)


def run(binary):
    binary = Path(binary).resolve()
    if hasattr(os, "sched_getaffinity"):
        # Exercise deadline concurrency on the smallest Linux runner too. This
        # process and its children change affinity; the invoking shell does not.
        os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    with tempfile.TemporaryDirectory(prefix="transit-plugin-") as temp:
        root = Path(temp)
        kubectl = root / "kubectl"
        kubectl.write_text(FAKE)
        kubectl.chmod(0o755)
        calls, fixtures = root / "calls", root / "fixtures"
        child_pid, stopped = root / "child", root / "stopped"
        env = dict(os.environ, PATH=str(root) + os.pathsep + os.environ["PATH"],
                   CALLS=str(calls), FIXTURES=str(fixtures),
                   CHILD_PID=str(child_pid), STOPPED=str(stopped))
        env.pop("MODE", None)
        node = fixture("Deployment", "node", "custom-authority")
        node.update(spec={"replicas": 1}, status={"readyReplicas": 1})
        config = fixture("ConfigMap", "board", "custom-settings")
        service = fixture("Service", "board", "custom-inspection")
        service["spec"] = {"ports": [{"name": "http", "port": 8080}]}

        def setup(origin="http://127.0.0.1:18102"):
            config["data"] = {"config.json": json.dumps({"public_origin": origin,
                "seed_file": "/secrets/seed"})}
            fixtures.write_text(json.dumps({
                "deployments": listed(node),
                "deployments,statefulsets,jobs,pods": listed(node),
                "deployments,statefulsets,jobs,pods,services,persistentvolumeclaims": listed(node, service),
                "configmaps": listed(config), "services": listed(service)}))

        def invoke(*args, mode=None, code=0):
            values = dict(env)
            if mode:
                values["MODE"] = mode
            result = subprocess.run([binary, *args], env=values, text=True,
                                    capture_output=True, timeout=8)
            assert result.returncode == code, (args, result)
            return result

        setup()
        assert "inspect Transit" in invoke("--help").stdout
        assert "0.1.0" in invoke("--version").stdout
        assert not calls.exists()
        for args in [("status",), ("delete", "pod"), ("logs", "worker", "--release", "example"),
                     ("get", "installations", "--release", "x,other=y"),
                     ("get", "installations", "-n", "bad/namespace"),
                     ("get", "installations", "-A", "-n", "demo"),
                     ("status", "--release", "example", "--follow"),
                     ("board", "--release", "example", "-o", "json"),
                     ("logs", "node", "--release", "example", "--tail", "10001"),
                     ("get", "installations", "--timeout", "0"),
                     ("get", "installations", "--kubeconfig"),
                     ("get", "installations", "--port-forward"),
                     ("get", "installations", "--unknown")]:
            invoke(*args, code=2)
        assert not calls.exists(), "invalid CLI must not reach Kubernetes"

        path = str(root / "config with spaces;$(false)")
        result = invoke("--kubeconfig", path, "--context=chosen-context", "get", "installations", "-A", "-o", "json")
        assert json.loads(result.stdout)["items"] == [node]
        args = json.loads(calls.read_text().splitlines()[-1])
        assert args[args.index("--kubeconfig") + 1] == path
        assert args[args.index("--context") + 1] == "chosen-context"
        assert "--all-namespaces" in args and "--request-timeout=15s" in args
        assert args[args.index("--selector") + 1] == "app.kubernetes.io/name=transit,app.kubernetes.io/component=node"
        # Discovery keeps namespace and Helm release visually associated, even
        # when names have different widths. Its selectors can then be copied.
        other = fixture("Deployment", "node", "transit")
        other["metadata"].update(namespace="transit-sample-abc123")
        other["metadata"]["labels"]["app.kubernetes.io/instance"] = "transit"
        other.update(spec={"replicas": 1}, status={"readyReplicas": 1})
        fixtures.write_text(json.dumps({"deployments": listed(node, other),
            "deployments,statefulsets,jobs,pods": listed(node, other)}))
        discovery = invoke("get", "installations", "-A")
        lines = discovery.stdout.splitlines()
        assert len(lines) == 3 and "\t" not in discovery.stdout, discovery
        columns = ["NAMESPACE", "RELEASE", "COMPONENT", "KIND", "NAME", "OBSERVED"]
        assert lines[0].split() == columns
        starts = [match.start() for match in re.finditer(r"\S+", lines[0])]
        ends = starts[1:] + [None]
        assert [lines[2][start:end].strip() for start, end in zip(starts, ends)] == [
            "transit-sample-abc123", "transit", "node", "Deployment", "transit", "ready=1/1"]
        assert "--namespace NAMESPACE --release RELEASE" in discovery.stderr
        for args, message in [
            (("--release", "abc123"), "--namespace was not supplied"),
            (("--release", "transit"), "--namespace was not supplied"),
            (("--release", "abc123", "-n", "transit-sample-abc123"), "namespace 'transit-sample-abc123'"),
        ]:
            result = invoke("get", "workloads", *args, code=1)
            assert not result.stdout and "ResourceNotFound" in result.stderr
            assert message in result.stderr and "NAMESPACE column" in result.stderr
            assert "namespace suffix is not a release name" in result.stderr
        result = invoke("get", "workloads", "--release", "transit", "-n", "transit-sample-abc123", "-o", "json")
        assert json.loads(result.stdout)["items"] == [other]
        for invalid in ("forged\nrow", "\x1b[31mforged", "x" * 254):
            other["metadata"]["name"] = invalid
            fixtures.write_text(json.dumps({"deployments": listed(other)}))
            result = invoke("get", "installations", "-A", code=1)
            assert "InvalidKubernetesResponse" in result.stderr and not result.stdout
        setup()
        result = invoke("status", "--release", "example", "-n", "demo")
        assert "custom-authority" in result.stdout and "ready=1/1" in result.stdout
        assert "execution authority" in result.stderr
        invoke("get", "workloads", "--release=example", "--namespace=demo", "--output=json")
        assert invoke("board", "--release", "example").stdout.strip() == "http://127.0.0.1:18102"
        invoke("board", "--release", "example", "--port-forward")
        args = json.loads(calls.read_text().splitlines()[-1])
        assert "service/custom-inspection" in args and "18102:8080" in args
        assert "--address=127.0.0.1" in args and "--selector" not in args
        assert args[args.index("--namespace") + 1] == "demo"
        for component in ("node", "controller"):
            invoke("logs", component, "--release", "example", "-n", "demo", "--tail", "42")
            args = json.loads(calls.read_text().splitlines()[-1])
            assert "--tail=42" in args and "--prefix=true" in args
            assert "app.kubernetes.io/instance=example,app.kubernetes.io/component=" + component in args[args.index("--selector") + 1]
        for origin in ["https://board.example.test", "http://board.example.test:18102", "http://localhost:18102"]:
            setup(origin)
            assert invoke("board", "--release", "example").stdout.strip() == origin
            result = invoke("board", "--release", "example", "--port-forward", code=1)
            assert "BoardOriginCannotBeForwarded" in result.stderr
            assert "port-forward" not in json.loads(calls.read_text().splitlines()[-1])
        for origin in ["http://user:password@127.0.0.1", "http://127.0.0.1/?token=secret", "http://127.0.0.1\nforged"]:
            setup(origin)
            result = invoke("board", "--release", "example", code=1)
            assert "InvalidBoardOrigin" in result.stderr and not result.stdout
        setup()
        fixtures.write_text(json.dumps({"configmaps": listed(config, config)}))
        assert "AmbiguousResources" in invoke("board", "--release", "example", code=1).stderr
        fixtures.write_text("{}")
        assert "Reference up" in invoke("get", "installations").stdout
        assert json.loads(invoke("get", "installations", "-o", "json").stdout)["items"] == []
        assert "ResourceNotFound" in invoke("status", "--release", "example", code=1).stderr
        assert "ResourceNotFound" in invoke("board", "--release", "example", code=1).stderr
        assert "Forbidden" in invoke("get", "installations", mode="failure", code=7).stderr
        for mode in ["oversize", "oversize-error"]:
            result = invoke("get", "installations", mode=mode, code=1)
            assert "StreamTooLong" in result.stderr and not result.stdout
        result = invoke("get", "installations", "--timeout", "1", mode="closed-hang", code=1)
        assert "QueryTimeout" in result.stderr
        try:
            os.kill(int(child_pid.read_text()), 0)
        except ProcessLookupError:
            pass
        else:
            raise AssertionError("timed-out kubectl was not reaped")
        child_pid.unlink()

        # Exec handoff preserves the PID and forwards signals without an orphaned tunnel.
        setup()
        for command in [("logs", "node", "--follow"), ("board", "--port-forward")]:
            # For Board, only the final stream blocks; serve discovery queries normally.
            script = FAKE.replace('mode = os.environ.get("MODE", "normal")',
                                  'mode = "stream" if "logs" in sys.argv or "port-forward" in sys.argv else "normal"')
            kubectl.write_text(script)
            for sig in [signal.SIGINT, signal.SIGTERM]:
                child = subprocess.Popen([binary, *command, "--release", "example"], env=env,
                                         stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                try:
                    wait_file(child_pid, child)
                    assert int(child_pid.read_text()) == child.pid
                    child.send_signal(sig)
                    child.communicate(timeout=5)
                    assert child.returncode == 0 and stopped.read_text() == str(sig)
                finally:
                    if child.poll() is None:
                        child.kill()
                    child.wait()
                    child_pid.unlink(missing_ok=True)
                    stopped.unlink(missing_ok=True)
        for line in calls.read_text().splitlines():
            args = json.loads(line)
            assert not set(args) & {"secrets", "secret", "apply", "patch", "delete", "exec", "config", "create"}
    print("kubectl transit: selection, JSON, read-only boundaries, Board origins, output/deadline bounds and streaming signal cleanup passed.")


if __name__ == "__main__":
    run(sys.argv[1])
