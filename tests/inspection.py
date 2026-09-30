"""Public signed inspection against disk Ursula; reusable Board service fixture."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import urllib.error
import urllib.request
from storage import Fixture, free_port, wait_ready


def available_post(post, path, signed):
    """Bound transient retries without changing the signed operation."""
    deadline = time.monotonic() + 10
    while True:
        try:
            status, body = post(path, signed, status=None)
        except (ConnectionError, TimeoutError):
            if time.monotonic() >= deadline: raise
        else:
            if status == 200: return body
            assert (status == 503 and body.get("err") in
                    ("AuthorityUnavailable", "AuthorityTimeout", "HttpCapacity") and
                    time.monotonic() < deadline), (status, body)
        time.sleep(.05)


class System:
    def __init__(self, node, cli, clock_error_ms=None, allow_history_trim=False, request_timeout_ms=800,
                 storage_config=None):
        self.node, self.cli = node, cli
        self.store = Fixture(storage_config)
        self.children, self.logs = [], []
        self.sequence = 0
        self.clock_error_ms = clock_error_ms
        self.allow_history_trim = allow_history_trim
        self.request_timeout_ms = request_timeout_ms

    def __enter__(self):
        self.store.__enter__()
        self.root = self.store.root
        self.seed, public = self.key("root")
        self.port = free_port()
        self.url = f"http://127.0.0.1:{self.port}"
        self.config = self.root / "node.json"
        self.config.write_text(json.dumps({"genesis": {"realm": 72, "root_key": public, "max_clock_error_ms": self.clock_error_ms, "allow_history_trim": self.allow_history_trim},
                                         "ursula_url": self.store.url, "bucket": "inspection", "journal": "authority",
                                         "port": self.port, "request_timeout_ms": self.request_timeout_ms}))
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
            response = self.store.http.open(request, timeout=max(5, self.request_timeout_ms / 1000 + 1))
        except urllib.error.HTTPError as error:
            response = error
        with response:
            body = json.load(response)
            if status is None: return response.status, body
            assert response.status == status, (response.status, body, status)
            return body

    def command(self, command):
        self.sequence += 1
        # Keep the signed bytes and sequence fixed after an uncertain result.
        return self.available_post("/v1/command", self.signed(command, self.sequence))["position"]

    def available_post(self, path, signed):
        return available_post(self.post, path, signed)

    def native_query(self, kind, principal=0, seed=None, status=200):
        path = self.root / "native-query.json"
        path.write_text(json.dumps({"realm": 72, "principal": principal, "kind": kind}))
        signed = self.invoke("sign-query", seed or self.seed, path)
        return self.available_post("/v1/query", signed) if status == 200 else self.post("/v1/query", signed, status)

    def query(self, resource, pid=None, principal=0, seed=None, **options):
        path = self.root / "query.json"
        path.write_text(json.dumps({"realm": 72, "principal": principal, "kind": {"inspection": {"resource": resource, "pid": pid, **options}}}))
        return self.invoke("sign-query", seed or self.seed, path)

    def inspect(self, resource, pid=None, status=200, **options):
        result = self.post("/v1/query", self.query(resource, pid, **options), status)
        return result["body"]["inspection"] if status == 200 else result


def run(node, cli):
    with System(node, cli) as s:
        pids = [s.command({"spawn": {}}) for n in range(20)]
        seed, public = s.key("reader")
        s.command({"grant": {"subject": 1, "public_key": public, "permissions": 16, "pid": pids[0]}})
        first = s.inspect("processes")
        assert len([p for p in first["processes"] if p]) == 8 and not first["complete"]
        middle = s.inspect("processes", cut=first["cut"], after=first["next"])
        assert [p["pid"] for p in middle["processes"] if p] == pids[8:16]
        last = s.inspect("processes", cut=first["cut"], after=middle["next"])
        assert [p["pid"] for p in last["processes"] if p] == pids[16:]
        assert last["complete"]
        scoped = s.inspect("processes", principal=1, seed=seed)
        assert [p["pid"] for p in scoped["processes"] if p] == pids[:1]
        s.inspect("process", pids[1], principal=1, seed=seed, status=403)
        query = s.query("process", pids[0])
        canonical = json.dumps(query["query"], separators=(",", ":"))
        assert json.loads(canonical)["definition"] == json.loads((Path(__file__).resolve().parents[1] / "contracts/transit-v1.schema.json").read_text())["x-transit"]["definition"]
        query["query"]["kind"]["inspection"]["pid"] = pids[1]
        s.post("/v1/query", query, 403)
        s.post("/v1/command", s.query("process", pids[0]), 400)
        before = s.native_query({"capabilities": {}})["position"]
        for version in (2, 3):
            incompatible = s.signed({"spawn": {}}, s.sequence + 1)
            incompatible["request"]["version"] = version
            s.post("/v1/command", incompatible, 400)
            old_query = s.query("process", pids[0])
            old_query["query"]["version"] = version
            s.post("/v1/query", old_query, 400)
        for route in ("/v2/command", "/v2/view", "/v2/inspect", "/v3/command", "/v3/query"):
            s.post(route, {}, 404)
        assert s.native_query({"capabilities": {}})["position"] == before
        for _ in range(18):
            s.command({"send": {"pid": pids[0], "value": b"input".hex()}})
        s.inspect("processes", cut=first["cut"], after=first["next"], status=409)
        page = s.inspect("mailbox", pids[0])
        assert all(e["mailbox_status"] == "pending" for e in page["events"] if e)
        assert len([e for e in page["events"] if e]) == 8
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
