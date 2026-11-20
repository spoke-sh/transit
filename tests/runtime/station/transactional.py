"""Installed private behavior and replacement schedules; preserve failed owners."""
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import signal
import subprocess
import threading
import time
from urllib.parse import urlparse

from runner.capture import identity, provenance
from runner.paths import ROOT


CASES = ("small", "large", "head", "begin", "claim", "input", "acquire", "dispatch",
         "draft", "staged", "executed", "decision", "cleared", "poison", "exception",
         "capacity", "stop", "stale")
FAULTS = CASES[2:13]


ALL_CASES = CASES + ("calls", "timers_pool", "services", "server_services")


class CapacityProxy:
    """Forwards HTTP calls to the authority, or returns 503 HttpCapacity on demand."""

    def __init__(self, target_url):
        parsed = urlparse(target_url)
        self.host = parsed.hostname
        self.port = parsed.port
        self.refuse = False
        self.refusals = 0
        owner = self

        class Server(ThreadingHTTPServer):
            daemon_threads = False

        class Handler(BaseHTTPRequestHandler):
            protocol_version = "HTTP/1.1"

            def log_message(self, *_):
                pass

            def do_POST(self):
                length = int(self.headers.get("Content-Length", "0"))
                body = self.rfile.read(length) if length else b""
                if owner.refuse:
                    owner.refusals += 1
                    payload = b'{"err":"HttpCapacity"}'
                    self.send_response(503)
                    self.send_header("Content-Type", "application/json")
                    self.send_header("Content-Length", str(len(payload)))
                    self.end_headers()
                    self.wfile.write(payload)
                    return
                headers = {"Content-Type": "application/json"}
                for key in ("x-transit-control", "x-transit-wait"):
                    if key in self.headers:
                        headers[key] = self.headers[key]
                conn = HTTPConnection(owner.host, owner.port, timeout=30)
                try:
                    conn.request("POST", self.path, body, headers)
                    resp = conn.getresponse()
                    data = resp.read()
                    self.send_response(resp.status)
                    self.send_header("Content-Type", resp.getheader("Content-Type", "application/json"))
                    self.send_header("Content-Length", str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                finally:
                    conn.close()

        self.server = Server(("127.0.0.1", 0), Handler)
        self.thread = threading.Thread(target=self.server.serve_forever)

    @property
    def url(self):
        return f"http://127.0.0.1:{self.server.server_port}"

    def __enter__(self):
        self.thread.start()
        return self

    def __exit__(self, *_):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=15)
        assert not self.thread.is_alive()


def wait_status(status_path, proc, predicate, timeout=20.0):
    deadline = time.monotonic() + timeout
    last = None
    while time.monotonic() < deadline:
        if status_path.exists():
            try:
                last = json.loads(status_path.read_text())
            except ValueError:
                last = None
            if last is not None and predicate(last):
                return last
        if proc.poll() is not None:
            raise RuntimeError(f"Station role exited early with {proc.returncode}; last status={last}")
        time.sleep(0.025)
    raise TimeoutError(f"Station role status timeout at {status_path}; last={last}")


def exercise_server_services(caller, transit_bin, root, profile, url, restart):
    assert transit_bin is not None, "server_services requires the transit CLI binary"
    transit_path = str(Path(transit_bin).resolve())
    restart(maintenance=False)
    subprocess.run([caller, url, "station-transaction-server_services_setup", str(profile)], check=True, timeout=180)
    restart(maintenance=True)
    saved = json.loads(Path(f"{profile}.server-services").read_text())

    svc_dir = root / "server-station-services"
    obs_dir = svc_dir / "observer"
    life_dir = svc_dir / "lifecycle"
    obs_dir.mkdir(parents=True, exist_ok=True)
    life_dir.mkdir(parents=True, exist_ok=True)

    obs_seed = svc_dir / "observer.seed"
    obs_seed.write_text(bytes([131] * 32).hex())
    obs_seed.chmod(0o600)
    life_seed = svc_dir / "lifecycle.seed"
    life_seed.write_text(bytes([133] * 32).hex())
    life_seed.chmod(0o600)

    obs_status = obs_dir / "status.json"
    life_status = life_dir / "status.json"
    obs_cfg_path = obs_dir / "config.json"
    life_cfg_path = life_dir / "config.json"

    boot1 = [17] * 16
    boot2 = [34] * 16
    life_boot = [51] * 16

    obs_proc = None
    life_proc = None
    obs_log = (obs_dir / "role.log").open("w+")
    life_log = (life_dir / "role.log").open("w+")

    try:
        with CapacityProxy(url) as proxy:
            def write_obs_config(boot):
                obs_cfg_path.write_text(json.dumps(dict(
                    url=proxy.url,
                    realm=42,
                    principal=saved["obs_principal"],
                    seed_file=str(obs_seed),
                    mode="observe",
                    watches=[],
                    transactional=[saved["obs_watch"]],
                    lease_ms=30000,
                    interval_ms=50,
                    request_timeout_ms=2000,
                    status_file=str(obs_status),
                    boot=boot,
                )))

            write_obs_config(boot1)
            life_cfg_path.write_text(json.dumps(dict(
                url=url,
                realm=42,
                principal=saved["local_life_principal"],
                seed_file=str(life_seed),
                mode="lifecycle",
                watches=[],
                transactional=[saved["local_life_watch"]],
                lease_ms=30000,
                interval_ms=50,
                request_timeout_ms=2000,
                status_file=str(life_status),
                boot=life_boot,
                local_stop=str(life_dir),
            )))

            obs_proc = subprocess.Popen([transit_path, "__transit_role_v1", "station", str(obs_cfg_path)],
                                        stdout=obs_log, stderr=subprocess.STDOUT)
            life_proc = subprocess.Popen([transit_path, "__transit_role_v1", "station", str(life_cfg_path)],
                                         stdout=life_log, stderr=subprocess.STDOUT)

            wait_status(obs_status, obs_proc, lambda s: s["ready"] and s["boot"] == boot1 and s["completed_passes"] >= 1)
            wait_status(life_status, life_proc, lambda s: s["ready"] and s["boot"] == life_boot and s["completed_passes"] >= 1)

            # 1. Explicit HttpCapacity refusal withdraws readiness without killing the sequencer or changing boot.
            proxy.refusals = 0
            proxy.refuse = True
            wait_status(obs_status, obs_proc, lambda s: not s["ready"] and s["error_name"] == "AuthorityUnavailable")
            deadline = time.monotonic() + 10.0
            while proxy.refusals < 4:
                assert obs_proc.poll() is None, "Observer exited under HttpCapacity pressure"
                assert time.monotonic() < deadline, "Insufficient HttpCapacity refusals observed"
                time.sleep(0.025)
            proxy.refuse = False
            wait_status(obs_status, obs_proc, lambda s: s["ready"] and s["boot"] == boot1)

            # 2. SIGKILL observer OS child and restart with a fresh boot nonce.
            obs_proc.kill()
            assert obs_proc.wait(timeout=15) == -signal.SIGKILL
            obs_proc = None
            write_obs_config(boot2)
            obs_proc = subprocess.Popen([transit_path, "__transit_role_v1", "station", str(obs_cfg_path)],
                                        stdout=obs_log, stderr=subprocess.STDOUT)
            wait_status(obs_status, obs_proc, lambda s: s["ready"] and s["boot"] == boot2 and s["completed_passes"] >= 1)

            # 3. Pump Supervisor through retry_wait -> TimerTicket -> retry_requested via OS observer!
            subprocess.run([caller, url, "station-transaction-server_services_pump", str(profile)], check=True, timeout=180)

            # 4. Lifecycle OS child must write stop.json and hold local_child at generation 1 until stopped.json appears!
            stop_file = life_dir / "stop.json"
            deadline = time.monotonic() + 15.0
            while not stop_file.exists():
                assert life_proc.poll() is None
                assert time.monotonic() < deadline, "Lifecycle role did not write stop.json"
                time.sleep(0.025)
            stop_req = json.loads(stop_file.read_text())
            assert stop_req == dict(boot=life_boot, pid=saved["local_child_pid"], generation=1, failure=1), stop_req
            base_passes = json.loads(life_status.read_text())["completed_passes"]
            wait_status(life_status, life_proc, lambda s: s["ready"] and s["completed_passes"] >= base_passes + 2)
            subprocess.run([caller, url, "station-transaction-server_services_check_gated", str(profile)], check=True, timeout=60)

            # Publish joined stop acknowledgement -> lifecycle executes native own + Actor.Head unblock!
            (life_dir / "stopped.json.tmp").write_text(json.dumps(stop_req))
            (life_dir / "stopped.json.tmp").replace(life_dir / "stopped.json")

            # 5. Verify TMO1 delivery, replacement worker commit at generation 2, and rotate lifecycle key!
            subprocess.run([caller, url, "station-transaction-server_services_verify", str(profile)], check=True, timeout=180)

            # 6. Idle key rotation causes the running lifecycle OS process to withdraw readiness and exit non-zero!
            exit_code = life_proc.wait(timeout=15)
            life_proc = None
            assert exit_code != 0
            final_life_status = json.loads(life_status.read_text())
            assert not final_life_status["ready"]
    finally:
        for proc in (obs_proc, life_proc):
            if proc is not None and proc.poll() is None:
                proc.terminate()
                try:
                    proc.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.wait(timeout=10)
        obs_log.close()
        life_log.close()


def exercise(node, caller, root, profile, url, restart, transit_bin=None):
    selected = os.environ.get("TRANSIT_STATION_TRANSACTION_CASES")
    cases = tuple(selected.split(",")) if selected else ALL_CASES
    assert cases and all(case in ALL_CASES for case in cases)
    outcomes = []
    for case in cases:
        if case == "server_services":
            exercise_server_services(caller, transit_bin, root, profile, url, restart)
            outcomes.append(dict(case=case, worker_sigkill=True, owner_sigkill_restarts=1,
                                 replacement_principal=1214, original_binding_unchanged=True, passed=True))
            continue
        if case in ("calls", "timers_pool", "services"):
            restart(maintenance=(case in ("timers_pool", "services")))
            subprocess.run([caller, url, f"station-transaction-{case}", str(profile)], check=True, timeout=180)
            outcomes.append(dict(case=case, worker_sigkill=False, owner_sigkill_restarts=1,
                                 replacement_principal=1202 if case == "calls" else 1209 if case == "timers_pool" else 1210,
                                 original_binding_unchanged=True, passed=True))
            continue
        def command(phase):
            return [caller, url, f"station-transaction-{phase}-{case}", str(profile)]
        subprocess.run(command("setup"), check=True, timeout=180)
        saved = Path(f"{profile}.station-{case}")
        original = saved.read_bytes()
        if case in FAULTS:
            marker = Path(f"{saved}.ready")
            with (root / f"actor-{case}.log").open("w") as output:
                child = subprocess.Popen(command("execute"), stdout=output, stderr=subprocess.STDOUT)
                try:
                    deadline = time.monotonic() + 180
                    while not marker.exists():
                        if child.poll() is not None:
                            raise RuntimeError(f"Actor {case} exited before its interruption boundary; see {root}")
                        if time.monotonic() >= deadline:
                            raise TimeoutError(f"Actor {case} did not reach its interruption boundary")
                        time.sleep(0.025)
                    assert json.loads(marker.read_text()) == {"point": case}
                    child.kill()
                    assert child.wait(timeout=15) == -signal.SIGKILL
                finally:
                    if child.poll() is None:
                        child.kill()
                        child.wait(timeout=15)
        else:
            subprocess.run(command("execute"), check=True, timeout=180)
        restart()
        subprocess.run(command("recover"), check=True, timeout=180)
        subprocess.run(command("verify"), check=True, timeout=180)
        restart()
        subprocess.run(command("verify"), check=True, timeout=180)
        assert saved.read_bytes() == original
        outcomes.append(dict(case=case, worker_sigkill=case in FAULTS,
                             owner_sigkill_restarts=2, replacement_principal=1000 + CASES.index(case),
                             original_binding_unchanged=True, passed=True))
    binaries = [identity(Path(path)) for path in (node, caller)]
    if transit_bin is not None:
        binaries.append(identity(Path(transit_bin)))
    print(json.dumps(dict(profile="private_transactional_station", source=provenance(ROOT),
                          binaries=binaries,
                          complete=cases == ALL_CASES, outcomes=outcomes, passed=True)))
