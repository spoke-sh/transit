"""Shared Station ABI: host loss, failed turns and async/native ownership."""
import asyncio
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import subprocess
import sys
import threading
import time

from inspection import System
from station import frame

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "packages/python/transit-station"))
from transit_station import Client, GenServer, TransitError


def rejects(status, function, *args):
    try:
        function(*args)
    except TransitError as error:
        assert error.status == status, (error.status, error.detail)
    else:
        raise AssertionError("Expected a native rejection")


def ready(server):
    for _ in range(10):
        event = server.next()
        if event["event"] == "ready":
            return event
    raise AssertionError("No handler turn")


def run(node, cli, library, raw_library, host):
    with System(node, cli, clock_error_ms=10000) as s:
        libraries = s.root / "libraries"
        libraries.mkdir()
        for name, source in (("station", library), ("client", raw_library)):
            (libraries / f"libtransit_{name}.so").symlink_to(Path(source).resolve())
        pid = s.command({"lifecycle": {"create": {"required": [b"data".hex(), None, None, None]}}})
        resource = s.command({"state": {"create": {"writer": pid}}})
        seed, public = s.key("foreign")
        s.command({"grant": {"subject": 1, "public_key": public, "permissions": 88, "pid": pid}})
        for subject in (0, 1):
            s.command({"state": {"grant": {"resource": resource, "subject": subject, "permissions": 7}}})
        s.command({"state": {"associate": {"pid": pid, "name": b"data".hex(), "resource": resource}}})
        s.command({"send": {"pid": pid, "value": frame(b"init")}})
        s.command({"lifecycle": {"initialize": {"pid": pid, "expected_generation": 1}}})
        s.command({"own": {"pid": pid, "worker": 1, "expected_generation": 2}})
        config = {"realm": 72, "principal": 1, "pid": pid, "generation": 3}
        with GenServer(libraries, s.url, seed, config) as server:
            assert ready(server)["initializing"]
            server.apply({"put": {"key": "61", "value": "62"}})
            rejects(1, server.apply, {"put": {"key": "00", "value": "62"}})
            # A rejected helper neither commits nor discards the private turn.
            assert server.apply({"get": "61"}) == {"value": "62"}
            server.finish()
            frozen = server.pending()
        # No native handles survive; the canonical pending request is sufficient
        # for an exact retry through the lower-level shared client.
        with Client(libraries, s.url) as client:
            first = client.call(frozen)
            assert client.call(frozen) == first
        view = s.post("/v2/view", s.signed({"inspect": pid}))
        assert view["input"] is None
        s.command({"send": {"pid": pid, "value": frame(b"failure")}})
        with GenServer(libraries, s.url, seed, config) as server:
            event = ready(server)
            assert not event["initializing"]
            server.apply({"put": {"key": "61", "value": "6368616e676564"}})
            server.finish(failed=True)
            assert server.next()["event"] == "blocked"
            assert server.next()["event"] == "blocked"
        state = s.root / "read.json"
        state.write_text(json.dumps({"realm": 72, "principal": 0, "kind": "entries", "resource": resource, "key": "61"}))
        assert s.post("/v2/state", s.invoke("sign-state", s.seed, state))["entries"][0]["value"] == "62"
        view = s.post("/v2/view", s.signed({"inspect": pid}))
        assert view["input"]["position"] == event["input"]["position"]
        with GenServer(libraries, s.url, seed, config) as stale:
            rejects(11, stale.next)
        s.command({"revoke": 1})
        with GenServer(libraries, s.url, seed, config) as denied:
            rejects(4, denied.next)

        # The port negotiates versions and uses the same codecs, with full-width
        # correlation values carried as decimal strings rather than JS numbers.
        host_config = s.root / "host.json"
        host_config.write_text(json.dumps({"url": s.url}))
        requests = ["{", json.dumps({"hello": {}}), json.dumps({"frame": {
            "kind": 2, "correlation": "18446744073709551615", "payload": "00ff"}})]
        result = subprocess.run([host, host_config], input="\n".join(requests) + "\n", text=True, capture_output=True, timeout=10)
        assert result.returncode == 0, result.stderr
        replies = [json.loads(line) for line in result.stdout.splitlines()]
        assert replies[0]["status"] == 1
        assert replies[1]["value"] == {"host_version": 1, "station_version": 1, "transit_version": 1}
        assert replies[2]["value"] == "53544e3102ffffffffffffffff00ff"
        assert seed.read_text() not in result.stderr + result.stdout

        asyncio.run(cancellation(libraries, seed, config))
    print("Station ABI: exact host-loss retry, private rollback, blocked head, fencing, revocation, port framing and cancellation ownership passed")


async def cancellation(libraries, seed, config):
    entered, release = threading.Event(), threading.Event()
    class Stall(BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass
        def do_POST(self):
            self.rfile.read(int(self.headers["Content-Length"]))
            entered.set()
            release.wait(5)
            self.close_connection = True
    proxy = ThreadingHTTPServer(("127.0.0.1", 0), Stall)
    thread = threading.Thread(target=proxy.serve_forever, daemon=True)
    thread.start()
    server = GenServer(libraries, f"http://127.0.0.1:{proxy.server_port}", seed, {**config, "timeout_ms": 500})
    try:
        task = asyncio.create_task(server.next_async())
        limit = time.monotonic() + 2
        while not entered.is_set():
            assert time.monotonic() < limit
            await asyncio.sleep(.005)
        rejects(9, server.next)
        # Cancellation drops the await, not the native worker's ownership.
        task.cancel()
        try:
            await task
        except asyncio.CancelledError:
            pass
        closing = asyncio.create_task(asyncio.to_thread(server.close))
        ticks = 0
        while not closing.done():
            await asyncio.sleep(.005)
            ticks += 1
        await closing
        assert ticks > 2, "Closing blocked the event loop or destroyed active native work"
        try:
            server.next()
        except ValueError:
            pass
        else:
            raise AssertionError("Closed native handle remained usable")
    finally:
        release.set()
        await asyncio.to_thread(server.close)
        await asyncio.to_thread(proxy.shutdown)
        proxy.server_close()
        thread.join(timeout=2)
