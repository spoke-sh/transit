"""Own real v1 maintenance faults; snapshot publication is not trim permission."""
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import subprocess
import sys
import threading
import time
import urllib.request

from harness.ursula import Fixture
from harness.services import free_port, wait_ready


def run(node, caller):
    with Fixture() as fixture:
        public = json.loads(subprocess.check_output([caller, "public"], timeout=10))
        port = free_port()
        url = f"http://127.0.0.1:{port}"
        seed = fixture.root / "maintenance.key"
        seed.write_text("09" * 32)
        seed.chmod(0o600)
        config = {"profile": "native_v1", "genesis": {
            "realm": 42, "root_key": public, "max_clock_error_ms": 10000,
            "allow_history_trim": True}, "ursula_url": fixture.url,
            "bucket": "growing-maintenance", "journal": "authority", "port": port,
            "resident_pages": 1, "request_timeout_ms": 10000,
            "maintenance": {"principal": 131072, "seed_file": str(seed),
                            "interval_ms": 10, "operation_timeout_ms": 10000}}
        config_file = fixture.root / "node.json"
        config_file.write_text(json.dumps(config))
        manifest = fixture.root / "expected.json"
        lost = threading.Event()
        resume = threading.Event()
        page_lost = threading.Event()
        resume_page = threading.Event()
        release_timeout = threading.Event()
        fault = {"armed": True, "page": False, "timeout": False}

        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def forward(self):
                if lost.is_set() and not resume.wait(timeout=20):
                    return
                if page_lost.is_set() and not resume_page.wait(timeout=20):
                    return
                body = self.rfile.read(int(self.headers.get("Content-Length", "0")))
                upstream = HTTPConnection("127.0.0.1", fixture.port, timeout=10)
                try:
                    headers = {key: value for key, value in self.headers.items()
                               if key.lower() not in ("host", "connection", "content-length")}
                    upstream.request(self.command, self.path, body, headers)
                    response = upstream.getresponse()
                    data = response.read()
                    if self.command == "PUT" and "/s-" in self.path and fault["page"]:
                        assert 200 <= response.status < 300
                        assert self.headers.get("Stream-Record-Match") is None
                        fault["page"] = False
                        page_lost.set()
                        # The immutable page was accepted but no locator was
                        # acknowledged. No retry/publication may hide this gap.
                        self.close_connection = True
                        return
                    if self.command == "PUT" and "/snapshot" in self.path and fault["armed"]:
                        assert 200 <= response.status < 300
                        fault["armed"] = False
                        lost.set()
                        # Publication succeeded; no reply and no subsequent trim
                        # can pass this proxy before the owned worker is killed.
                        self.close_connection = True
                        return
                    if self.command == "PUT" and "/retention?" in self.path and fault["timeout"]:
                        assert 200 <= response.status < 300
                        fault["timeout"] = False
                        # Block the acknowledgement after committed physical trim.
                        # This occurs inside a maintenance step, after bootstrap.
                        release_timeout.wait(timeout=15)
                    self.send_response(response.status)
                    for key, value in response.getheaders():
                        if key.lower() not in ("connection", "content-length", "transfer-encoding"):
                            self.send_header(key, value)
                    self.send_header("Content-Length", str(len(data)))
                    self.end_headers()
                    if self.command != "HEAD":
                        self.wfile.write(data)
                except (BrokenPipeError, ConnectionResetError):
                    pass  # The owned client was deliberately killed/timed out.
                finally:
                    upstream.close()

            do_GET = do_HEAD = do_POST = do_PUT = forward

        proxy = ThreadingHTTPServer(("127.0.0.1", 0), Proxy)
        thread = threading.Thread(target=proxy.serve_forever, daemon=True)
        thread.start()
        config["ursula_url"] = f"http://127.0.0.1:{proxy.server_port}"
        maintenance_config = fixture.root / "maintenance.json"
        maintenance_config.write_text(json.dumps(config))
        children, logs = [], []

        def start(configuration, *args):
            log = (fixture.root / f"child-{len(logs)}.log").open("w+")
            logs.append(log)
            child = subprocess.Popen([node, str(configuration), *args], stdout=log, stderr=subprocess.STDOUT,
                                     env={**os.environ, 'LOG_FORMAT': 'json'})
            children.append(child)
            return child, log

        def stop(child):
            if child.poll() is None:
                child.kill()
            child.wait(timeout=10)

        def invoke(phase):
            subprocess.run([caller, url, phase, str(manifest)], check=True, timeout=60)

        def first():
            request = urllib.request.Request(fixture.url + "/growing-maintenance/authority", method="HEAD")
            with fixture.http.open(request, timeout=5) as response:
                return int(response.headers["Stream-Record-First"])

        def await_condition(check, child):
            until = time.monotonic() + 30
            while not check():
                assert child.poll() is None, "maintenance exited"
                if time.monotonic() > until:
                    raise TimeoutError("growing maintenance condition")
                time.sleep(0.025)

        def contains(log, value):
            return value in Path(log.name).read_text()

        try:
            authority, _ = start(config_file, "--bootstrap")
            wait_ready(fixture.http, authority, url + "/health")
            invoke("maintenance-seed")
            expected = json.loads(manifest.read_text())
            worker, _ = start(maintenance_config, "--maintain")
            assert lost.wait(timeout=20), "snapshot fault never reached"
            stop(worker)
            assert first() == 0, "unacknowledged snapshot was followed by trim"
            resume.set()
            fault["page"] = True
            worker, _ = start(maintenance_config, "--maintain")
            assert page_lost.wait(timeout=20), "immutable staging fault never reached"
            stop(worker)
            request = urllib.request.Request(fixture.url + "/growing-maintenance/authority", method="HEAD")
            with fixture.http.open(request, timeout=5) as response:
                assert int(response.headers["Stream-Record-Next"]) == expected["checkpoint"] + 1, "unacknowledged page published authority"
            resume_page.set()
            worker, _ = start(maintenance_config, "--maintain")
            await_condition(lambda: first() >= expected["checkpoint"], worker)
            invoke("maintenance-check")
            stop(worker)
            floor = first()
            invoke("maintenance-revoke")
            # Current revocation forbids even a restart from doing physical trim.
            worker, log = start(maintenance_config, "--maintain")
            await_condition(lambda: contains(log, '"error_type":"Forbidden"'), worker)
            assert first() == floor
            stop(worker)
            invoke("maintenance-grant")
            # Guaranteed concurrency must enforce the deadline on one CPU, even
            # when the storage operation accepted and its response never arrives.
            fault["timeout"] = True
            config["maintenance"]["operation_timeout_ms"] = 1000
            maintenance_config.write_text(json.dumps(config))
            worker, log = start(maintenance_config, "--maintain")
            await_condition(lambda: contains(log, '"error_type":"MaintenanceTimeout"'), worker)
            release_timeout.set()
            await_condition(lambda: contains(log, '"operation":"trimmed"'), worker)
            assert first() > floor
            stop(worker)
            stop(authority)
            fixture.stop()
            fixture.start()
            authority, _ = start(config_file)
            wait_ready(fixture.http, authority, url + "/health")
            invoke("maintenance-check")
            worker, _ = start(maintenance_config, "--maintain")
            invoke("maintenance-check")
        except BaseException:
            for log in logs:
                sys.stderr.write(Path(log.name).read_text()[-12000:])
            raise
        finally:
            resume.set()
            resume_page.set()
            release_timeout.set()
            for child in reversed(children):
                stop(child)
            proxy.shutdown()
            proxy.server_close()
            thread.join(timeout=5)
            for log in logs:
                log.close()
    print("Growing maintenance: bounded retirement, snapshot/page reply loss, trim timeout, revocation and disk restart passed.")
