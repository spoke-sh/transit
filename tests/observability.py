"""Real Board/client/node correlation, receipt semantics and untrusted headers."""
from http.client import HTTPConnection
import json
import os
from pathlib import Path
import socket
import sys
import time
from inspection import System
from storage import free_port, wait_ready


def records(path):
    return [json.loads(line) for line in path.read_text().splitlines()]


def run(node, cli, board):
    env = os.environ | {"LOG_FORMAT": "json", "LOG_LEVEL": "debug"}
    with System(node, cli) as s:
        s.authority.kill()
        s.authority.wait(timeout=10)
        config = json.loads(s.config.read_text())
        config["accept_trace_parent"] = True  # Explicit private ingress policy.
        s.config.write_text(json.dumps(config))
        s.authority = s.start(node, s.config, env=env)
        node_log = Path(s.logs[-1].name)
        wait_ready(s.store.http, s.authority, s.url + "/health")
        # A repeated receipt does not establish another admission/turn.
        signed = s.signed({"spawn": {"initial_state": b"private-state-marker".hex()}}, 1)
        receipt = s.post("/v2/command", signed)
        assert s.post("/v2/command", signed) == receipt
        s.sequence = 1
        seed, public = s.key("board")
        s.command({"grant": {"subject": 1, "public_key": public, "permissions": 16}})
        port = free_port()
        credential = s.root / "access.key"
        access = os.urandom(32).hex()
        credential.write_text(access)
        board_config = s.root / "board.json"
        board_config.write_text(json.dumps({"upstream": s.url, "realm": 72, "principal": 1,
            "seed_file": str(seed), "credential_file": str(credential), "port": port,
            "public_origin": f"http://127.0.0.1:{port}"}))
        running = s.start(board, board_config, env=env)
        board_log = Path(s.logs[-1].name)
        wait_ready(s.store.http, running, f"http://127.0.0.1:{port}/health")
        forged = "00-" + "a" * 32 + "-" + "b" * 16 + "-01"
        conn = HTTPConnection("127.0.0.1", port, timeout=5)
        conn.request("GET", "/api/v1/processes", headers={"Authorization": f"Bearer {access}", "traceparent": forged})
        response = conn.getresponse()
        assert response.status == 200
        response.read()
        conn.close()
        # Duplicate/malformed headers are discarded as context, not used for auth.
        with socket.create_connection(("127.0.0.1", s.port), timeout=3) as stream:
            stream.sendall(("GET /health HTTP/1.1\r\nHost: localhost\r\ntraceparent: " + forged +
                            "\r\ntraceparent: private-header-marker\r\n\r\n").encode())
            assert b"200" in stream.recv(8192)
        s.command({"revoke": 1})
        time.sleep(.12)
        conn = HTTPConnection("127.0.0.1", port, timeout=5)
        conn.request("GET", "/api/v1/processes", headers={"Authorization": f"Bearer {access}", "traceparent": forged})
        response = conn.getresponse()
        assert response.status == 403
        response.read()
        conn.close()
        time.sleep(.1)
        board_records, node_records = records(board_log), records(node_log)
        server = next(r for r in board_records if r.get("event", {}).get("name") == "board.http.request" and r["event"]["route"] == "/api/v1/processes" and r["event"]["status"] == 200)
        client = next(r for r in board_records if r.get("parent_span_id") == server["span_id"])
        authority = next(r for r in node_records if r.get("parent_span_id") == client["span_id"])
        assert server["trace_id"] == client["trace_id"] == authority["trace_id"] != "a" * 32
        assert len({server["span_id"], client["span_id"], authority["span_id"]}) == 3
        storage = [r for r in node_records if r.get("parent_span_id") == authority["span_id"] and r.get("event", {}).get("name") == "transit.storage.operation"]
        assert storage and all(r["trace_id"] == authority["trace_id"] for r in storage)
        recovery = [r for r in node_records if r.get("event", {}).get("name") == "transit.recovery"]
        assert len(recovery) == 1 and recovery[0]["event"]["protocol_outcome"] == "none"
        assert client["event"]["protocol_outcome"] == authority["event"]["protocol_outcome"] == "read"
        receipts = [r for r in node_records if r.get("event", {}).get("operation") == "spawn"]
        assert len(receipts) == 2
        assert all(r["event"]["protocol_outcome"] == "receipt" and r["event"]["position"] == receipt["position"] for r in receipts)
        denied = [r for r in node_records if r.get("event", {}).get("status") == 403]
        assert denied and all("pid" not in r["event"] for r in denied)
        assert not any(r.get("trace_id") == "a" * 32 for r in node_records)
        for path in (node_log, board_log):
            data = path.read_text()
            assert access not in data and seed.read_text().strip() not in data
            assert "private-state-marker" not in data and "private-state-marker".encode().hex() not in data
            assert "private-header-marker" not in data
        print("Observability: separate correlated Board/client/node spans, receipt retries, revoked reads and trace/secret boundaries passed.")


if __name__ == "__main__":
    run(*[Path(p).resolve() for p in sys.argv[1:]])
