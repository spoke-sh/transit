"""Public signed inspection against disk Ursula; reusable Board service fixture."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import urllib.error
import urllib.request
from storage import Fixture, free_port, wait_ready


class System:
    def __init__(self, node, cli):
        self.node, self.cli = node, cli
        self.store = Fixture()
        self.children, self.logs = [], []
        self.sequence = 0

    def __enter__(self):
        self.store.__enter__()
        self.root = self.store.root
        self.seed, public = self.key("root")
        self.port = free_port()
        self.url = f"http://127.0.0.1:{self.port}"
        self.config = self.root / "node.json"
        self.config.write_text(json.dumps({"genesis": {"realm": 72, "root_key": public, "retry_policy": "last_per_principal"},
                                         "ursula_url": self.store.url, "bucket": "inspection", "journal": "authority",
                                         "port": self.port, "request_timeout_ms": 800}))
        self.authority = self.start(self.node, self.config, "--bootstrap")
        wait_ready(self.store.http, self.authority, self.url + "/health")
        return self

    def __exit__(self, *exc):
        for child in reversed(self.children):
            if child.poll() is None:
                child.kill()
            child.wait(timeout=10)
        for log in self.logs:
            if exc[0] is not None:
                log.seek(0)
                print(log.read()[-5000:], file=sys.stderr)
            log.close()
        self.store.__exit__(*exc)

    def start(self, binary, *args, **kwargs):
        log = (self.root / f"child-{len(self.logs)}.log").open("w+")
        self.logs.append(log)
        child = subprocess.Popen([str(binary), *map(str, args)], stdout=log, stderr=subprocess.STDOUT, **kwargs)
        self.children.append(child)
        return child

    def invoke(self, *args):
        return json.loads(subprocess.check_output([str(self.cli), *map(str, args)], timeout=10))

    def key(self, name):
        path = self.root / f"{name}.key"
        path.write_text(os.urandom(32).hex())
        path.chmod(0o600)
        return path, self.invoke("public-key", path)

    def signed(self, command, sequence=0):
        path = self.root / "command.json"
        path.write_text(json.dumps({"realm": 72, "principal": 0, "sequence": sequence, "command": command}))
        return self.invoke("sign", self.seed, path)

    def post(self, path, value, status=200):
        request = urllib.request.Request(self.url + path, json.dumps(value).encode(), {"Content-Type": "application/json"})
        try:
            response = self.store.http.open(request, timeout=5)
        except urllib.error.HTTPError as error:
            response = error
        with response:
            body = json.load(response)
            assert response.status == status, (response.status, body, status)
            return body

    def command(self, command):
        self.sequence += 1
        return self.post("/v2/command", self.signed(command, self.sequence))["position"]

    def query(self, resource, pid=None, principal=0, seed=None, **options):
        path = self.root / "query.json"
        path.write_text(json.dumps({"realm": 72, "principal": principal, "resource": resource, "pid": pid, **options}))
        return self.invoke("sign-inspection", seed or self.seed, path)

    def inspect(self, resource, pid=None, status=200, **options):
        return self.post("/v2/inspect", self.query(resource, pid, **options), status)


def run(node, cli):
    with System(node, cli) as s:
        pids = [s.command({"spawn": {"initial_state": str(n).encode().hex()}}) for n in range(20)]
        seed, public = s.key("reader")
        s.command({"grant": {"subject": 1, "public_key": public, "permissions": 16, "pid": pids[0]}})
        first = s.inspect("processes")
        assert len([p for p in first["processes"] if p]) == 16 and not first["complete"]
        last = s.inspect("processes", cut=first["cut"], after=first["next"])
        assert [p["pid"] for p in last["processes"] if p] == pids[16:]
        assert last["complete"]
        scoped = s.inspect("processes", principal=1, seed=seed)
        assert [p["pid"] for p in scoped["processes"] if p] == pids[:1]
        s.inspect("process", pids[1], principal=1, seed=seed, status=403)
        query = s.query("process", pids[0])
        canonical = json.dumps(query["query"], separators=(",", ":"))
        assert canonical.startswith('{"version":1,"realm":72,"principal":0,"resource":"process"')
        fixture = json.loads((Path(__file__).resolve().parents[1] / "packages/zig/transit-protocol/src/fixtures/inspection-v1.json").read_text())
        assert hashlib.sha256(b"rey.transit.inspection.v1\0" + fixture["canonical"].encode()).hexdigest() == fixture["sha256"]
        vector_key = s.root / "vector.key"
        vector_key.write_text(fixture["seed_hex"])
        vector_key.chmod(0o600)
        vector_request = s.root / "vector-query.json"
        vector_request.write_text(fixture["canonical"])
        vector = s.invoke("sign-inspection", vector_key, vector_request)
        assert vector["signature"] == fixture["signature"]
        assert json.dumps(vector["query"], separators=(",", ":")) == fixture["canonical"]
        query["query"]["pid"] = pids[1]
        s.post("/v2/inspect", query, 403)
        s.post("/v2/command", s.query("process", pids[0]), 400)
        for _ in range(18):
            s.command({"send": {"pid": pids[0], "value": b"input".hex()}})
        s.inspect("processes", cut=first["cut"], after=first["next"], status=409)
        page = s.inspect("mailbox", pids[0])
        assert all(e["mailbox_status"] == "pending" for e in page["events"] if e)
        assert len([e for e in page["events"] if e]) == 16
        s.command({"revoke": 1})
        s.inspect("processes", principal=1, seed=seed, cut=scoped["cut"], status=403)
        s.authority.kill()
        s.authority.wait(timeout=10)
        s.store.stop()
        s.store.start()
        s.authority = s.start(s.node, s.config)
        wait_ready(s.store.http, s.authority, s.url + "/health")
        assert s.inspect("mailbox", pids[0]) == page | {"cut": s.inspect("mailbox", pids[0])["cut"]}
    print("Inspection: scoped discovery, signed queries, bounded pages, expired cuts, revocation and disk recovery passed.")


if __name__ == "__main__":
    run(*[Path(p).resolve() for p in sys.argv[1:]])
