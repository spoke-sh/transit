#!/usr/bin/env python3
"""Real signed HTTP ingress, bounded reads, worker fencing and disk recovery."""
import json
from wire_values import encode_command
import os
from pathlib import Path
import signal
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request

from storage import Fixture, free_port, wait_ready
from inspection import available_post


def run(node, worker, cli):
    with Fixture() as store:
        root = store.root
        children = []
        logs = []

        def start(binary, *args, separate_stderr=False):
            error_log = subprocess.STDOUT
            if separate_stderr:
                error_log = (root / f"child-{len(logs)}-stderr.log").open("w+")
                logs.append(error_log)
            log = (root / f"child-{len(logs)}.log").open("w+")
            logs.append(log)
            child = subprocess.Popen([str(binary), *map(str, args)], stdout=log, stderr=error_log)
            children.append(child)
            return child

        def stop(child):
            if child.poll() is None:
                child.kill()
            child.wait(timeout=10)

        def invoke(*args):
            return json.loads(subprocess.check_output([str(cli), *map(str, args)], timeout=10))

        def key(name):
            path = root / name
            path.write_text(os.urandom(32).hex())
            path.chmod(0o600)
            return path, invoke("public-key", path)

        root_key, root_public = key("root.key")
        worker_key, worker_public = key("worker.key")
        rotated_key, rotated_public = key("rotated.key")
        port = free_port()
        url = f"http://127.0.0.1:{port}"
        config = root / "node.json"
        config.write_text(json.dumps({"genesis": {"realm": 47, "root_key": root_public, "max_clock_error_ms": 10000},
                                      "ursula_url": store.url, "bucket": "transit-service", "journal": "authority",
                                      "port": port, "request_timeout_ms": 800}))
        seq = 0

        def signed(command, sequence=0, principal=0, seed=root_key, realm=47):
            revision = view(command["turn"]["pid"])["process"]["revision"] if "turn" in command else 0
            command = encode_command(command, revision)
            path = root / "request.json"
            path.write_text(json.dumps({"realm": realm, "principal": principal, "sequence": sequence, "command": command}))
            return invoke("sign", seed, path)

        def post(path, body, status=200, headers=None):
            request = urllib.request.Request(url + path, json.dumps(body).encode(), headers or {"Content-Type": "application/json"})
            try:
                response = store.http.open(request, timeout=5)
            except urllib.error.HTTPError as error:
                response = error
            with response:
                value = json.load(response)
                if status is None: return response.status, value
                assert response.status == status, (response.status, value, status)
                return value

        def command(value):
            nonlocal seq
            seq += 1
            return available_post(post, "/v1/command", signed(value, seq))["position"]

        resources = {}
        def sign_query(kind, principal=0, seed=root_key, realm=47):
            path = root / "query.json"
            path.write_text(json.dumps({"realm": realm, "principal": principal, "kind": kind}))
            return invoke("sign-query", seed, path)
        def query(kind, principal=0, seed=root_key, status=200):
            signed_read = sign_query(kind, principal, seed)
            return available_post(post, "/v1/query", signed_read) if status == 200 else post("/v1/query", signed_read, status)
        def view(pid, principal=0, seed=root_key, status=200):
            response = query({"process": pid}, principal, seed, status)
            return {**response["body"]["process"], "principal_sequence": response["principal_sequence"]} if status == 200 else response
        def provision(pid, principal):
            resource = command({"create_resource": {"writer": pid}})
            resources[pid] = resource
            for subject in (0, principal):
                command({"grant_resource": {"resource": resource, "subject": subject, "permissions": 7}})
            command({"associate": {"pid": pid, "name": b"counter".hex(), "resource": resource}})
        def state(pid):
            resource = resources[pid]
            entries = query({"read_entries": {"resource": resource, "keys": [b"value".hex()] + [None] * 7}})["body"]["read_entries"]["entries"]
            return int(bytes.fromhex(entries[0]["value"])) if entries[0] else 0

        def await_state(pid, expected):
            deadline = time.monotonic() + 30
            while True:
                current = view(pid)
                if state(pid) == expected:
                    return current
                assert time.monotonic() < deadline, current
                time.sleep(0.05)

        try:
            authority = start(node, config, "--bootstrap")
            wait_ready(store.http, authority, url + "/health")
            pid = command({"spawn": {}})
            other = command({"spawn": {}})
            command({"grant": {"subject": 1, "public_key": worker_public, "permissions": 24, "pid": pid}})
            provision(pid, 1)
            command({"own": {"pid": pid, "expected_generation": 1, "worker": 1}})
            # Signatures and realms are checked before process existence can leak.
            forged = sign_query({"process": pid})
            forged["signature"] = [0] * 64
            assert post("/v1/query", forged, 403) == {"err": "AccessDenied"}
            post("/v1/query", sign_query({"process": pid}, realm=48), 403)
            view(other, 1, worker_key, 403)
            post("/v1/command", signed({"send": {"pid": pid, "value": 999}}, 1, 1, worker_key), 403)
            # Invalid/malformed input never appends or blocks subsequent requests.
            post("/v1/command", {"sender": "root", "request": {}}, 400)
            for value in range(1, 25):
                command({"send": {"pid": pid, "value": value}})
            initial = view(pid, 1, worker_key)
            # Record the same first KV turn a worker would propose, retain its
            # exact signed bytes, then let the real worker drain the remainder.
            opened = signed({"open_view": {"pid": pid, "generation": 2, "input": initial["input"]["position"],
                "expected_revision": initial["process"]["revision"], "resource": resources[pid],
                "revision": query({"resource": resources[pid]})["body"]["resource"]["revision"],
                "deadline_ms": int(time.time() * 1000) + 30000}}, 1, 1, worker_key)
            view_id = post("/v1/command", opened)["position"]
            stale = signed({"turn": {"pid": pid, "generation": 2, "input": initial["input"]["position"],
                "views": [view_id, None, None, None], "write_view": view_id,
                "mutations": [{"key": b"value".hex(), "value": b"1".hex()}, None, None, None]}}, 2, 1, worker_key)
            post("/v1/command", stale)
            worker_config = root / "worker.json"
            worker_options = {"url": url, "realm": 47, "principal": 1, "pid": pid, "generation": 2, "seed_file": str(worker_key)}
            worker_config.write_text(json.dumps(worker_options))
            first = start(worker, worker_config)
            await_state(pid, 300)
            first.send_signal(signal.SIGSTOP)
            # A historical receipt remains valid; it grants no fresh execution.
            post("/v1/command", stale)
            command({"send": {"pid": pid, "value": 7}})
            paused = view(pid, 1, worker_key)
            stale = signed({"turn": {"pid": pid, "generation": 2,
                                      "input": paused["input"]["position"]}},
                           paused["principal_sequence"] + 1, 1, worker_key)
            command({"own": {"pid": pid, "expected_generation": 2, "worker": 1}})
            post("/v1/command", stale, 422)
            worker_options["generation"] = 3
            worker_config.write_text(json.dumps(worker_options))
            second = start(worker, worker_config)
            await_state(pid, 307)
            first.send_signal(signal.SIGCONT)
            assert first.wait(timeout=10) != 0
            stop(second)
            # Incomplete headers and bodies must release the sequential server
            # at its deadline, including with no spare async worker threads.
            for partial in (
                b"POST /v1/command HTTP/1.1\r\nHost:",
                b"POST /v1/command HTTP/1.1\r\nHost: local\r\nContent-Length: 100\r\n\r\n{",
            ):
                with socket.create_connection(("127.0.0.1", port), timeout=3) as slow:
                    slow.sendall(partial)
                    time.sleep(1)
                    assert state(pid) == 307
            # A connected authority that never responds must also release the
            # protocol client at its own deadline, not the harness timeout.
            read_path = root / "timeout-read.json"
            read_path.write_text(json.dumps({"realm": 47, "principal": 0, "kind": {"process": pid}}))
            with socket.socket() as stalled:
                stalled.bind(("127.0.0.1", 0))
                stalled.listen()
                stalled.settimeout(5)
                caller = start(cli, "query", root_key, read_path,
                               f"http://127.0.0.1:{stalled.getsockname()[1]}")
                connection, _ = stalled.accept()
                with connection:
                    connection.settimeout(5)
                    with connection.makefile("rb") as incoming:
                        assert incoming.readline(8192).startswith(b"POST /v1/query ")
                        assert caller.wait(timeout=8) != 0
                        assert "AuthorityTimeout" in Path(logs[-1].name).read_text()
            # Key renewal preserves sequencing; revocation applies to cached reads.
            old_read = sign_query({"process": pid}, principal=1, seed=worker_key)
            command({"grant": {"subject": 1, "public_key": rotated_public, "permissions": 24, "pid": pid}})
            post("/v1/query", old_read, 403)
            assert view(pid, 1, rotated_key)["process"]["consumed"] == 25
            assert state(pid) == 307
            command({"revoke": 1})
            view(pid, 1, rotated_key, 403)
            # A cold worker publishes only a public key. The trusted runtime
            # controller verifies provider identity before rotating its grant.
            command({"grant": {"subject": 2, "public_key": worker_public, "permissions": 24, "pid": other}})
            provision(other, 2)
            operation = command({"runtime_intent": {"pid": other, "expected_revision": 0,
                                                     "instance": [1] * 16, "resource": [2] * 32, "workload": [3] * 32}})
            command({"runtime_observe": {"pid": other, "revision": 1, "operation": operation,
                                          "incarnation": [4] * 16, "outcome": "ready"}})
            command({"send": {"pid": other, "value": 11}})
            boot = start(worker, "--bootstrap-json", json.dumps({"url": url, "realm": 47, "principal": 2, "pid": other}), separate_stderr=True)
            log = logs[-1]
            deadline = time.monotonic() + 5
            while True:
                log.seek(0)
                line = log.readline()
                if line:
                    bootstrap = json.loads(line)["bootstrap"]
                    break
                assert time.monotonic() < deadline
                time.sleep(0.05)
            assert bootstrap["pid"] == other and bootstrap["realm"] == 47
            assert state(other) == 0
            command({"activate": {"pid": other, "revision": 1, "expected_generation": 2, "worker": 2,
                                   "public_key": bootstrap["public_key"], "worker_incarnation": [5] * 16}})
            await_state(other, 11)
            stop(boot)
            before = view(pid)
            stop(authority)
            store.stop()
            store.start()
            authority = start(node, config)
            wait_ready(store.http, authority, url + "/health")
            assert view(pid) == before
            view(pid, 1, rotated_key, 403)
            command({"terminate": pid})
            assert view(pid)["process"]["lifecycle"] == "terminated"
            failed_pid = command({"spawn": {}})
            command({"grant": {"subject": 3, "public_key": worker_public, "permissions": 24, "pid": failed_pid}})
            provision(failed_pid, 3)
            command({"own": {"pid": failed_pid, "expected_generation": 1, "worker": 3}})
            command({"send": {"pid": failed_pid, "value": 9223372036854775807}})
            bad_input = command({"send": {"pid": failed_pid, "value": 1}})
            failed_config = root / "failed-worker.json"
            failed_config.write_text(json.dumps({"url": url, "realm": 47, "principal": 3,
                "pid": failed_pid, "generation": 2, "seed_file": str(worker_key)}))
            failed_worker = start(worker, failed_config)
            assert failed_worker.wait(timeout=20) != 0
            failed = view(failed_pid)["process"]
            assert failed["failure"] == bad_input
            assert failed["consumed"] == 1 and failed["cancelled"] == 0 and failed["owner"] is None
            stop(authority)
            authority = start(node, config)
            wait_ready(store.http, authority, url + "/health")
            assert view(failed_pid)["process"] == failed
            # Invalid application bytes are a caller failure, not invalid protocol.
            # They must block visibly instead of crashing and being replaced forever.
            malformed_pid = command({"spawn": {}})
            command({"grant": {"subject": 4, "public_key": worker_public, "permissions": 24, "pid": malformed_pid}})
            provision(malformed_pid, 4)
            command({"own": {"pid": malformed_pid, "expected_generation": 1, "worker": 4}})
            malformed_input = command({"send": {"pid": malformed_pid, "value": b"not-a-number".hex()}})
            failed_config.write_text(json.dumps({"url": url, "realm": 47, "principal": 4,
                "pid": malformed_pid, "generation": 2, "seed_file": str(worker_key)}))
            malformed_worker = start(worker, failed_config)
            assert malformed_worker.wait(timeout=20) != 0
            malformed = view(malformed_pid)["process"]
            assert malformed["failure"] == malformed_input
            assert malformed["consumed"] == 0 and malformed["owner"] is None
            from service_wait import run as wait_proof
            wait_proof(post, sign_query, query, command, malformed_pid, worker_key, worker_public)
            print("Signed service ingress, scoped/revoked reads, bounded requests, worker fencing and disk recovery passed.")
        except BaseException:
            for log in logs:
                log.flush()
                log.seek(0)
                sys.stderr.write(log.read()[-5000:])
            raise
        finally:
            for child in children:
                stop(child)
            for log in logs:
                log.close()


if __name__ == "__main__":
    if hasattr(os, "sched_setaffinity"):
        # All child services inherit a single CPU. This makes inline async
        # fallback deterministic even on large developer machines.
        os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    binaries = [Path(path).resolve(strict=True) for path in sys.argv[1:]]
    from fixtures import run as fixtures
    fixtures(binaries[2])
    run(*binaries[:3])
    from maintenance import run as maintenance
    maintenance(binaries[0], binaries[2])
    from effect_io import run as effect_io
    effect_io(binaries[0], binaries[3], binaries[2])
    from deletion_service import run as deletion
    deletion(binaries[0], binaries[2], binaries[4])
