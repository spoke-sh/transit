"""Captured queries retain direct Table cuts across native worker/node restart."""
import argparse
import json
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import urllib.request

from storage import free_port, wait_ready


def run(node, caller, python_native=None, ruby_host=None, java_packages=None, dotnet_packages=None, c_packages=None, beam_packages=None, rust_packages=None, node_packages=None, python_packages=None, ruby_packages=None, maintained_only=False, relational_failures_only=False, source_pages_only=False, exchanges_only=False, unified_boundaries_only=False, captured_only=False, follow_only=False, named_only=False, example=None):
    if example is not None and not follow_only:
        raise ValueError("the example schedule requires --follow-only")
    if (maintained_only or relational_failures_only or source_pages_only or exchanges_only or unified_boundaries_only or follow_only or named_only) and any((python_native, ruby_host, java_packages, dotnet_packages, c_packages, beam_packages, rust_packages, node_packages, python_packages, ruby_packages)):
        raise ValueError("focused runs do not run installed captured consumers")
    if sum((maintained_only, relational_failures_only, source_pages_only, exchanges_only, unified_boundaries_only, captured_only, follow_only, named_only)) > 1:
        raise ValueError("choose one focused schedule")
    node, caller = str(Path(node).resolve()), str(Path(caller).resolve())
    if example is not None:
        example = str(Path(example).resolve())
    with tempfile.TemporaryDirectory(prefix="transit-direct-capture-") as directory:
        root = Path(directory)
        installed = []
        if java_packages is not None:
            from sdk_unified import install_java
            installed.append(install_java(root / "java", None, Path(java_packages).resolve(), direct=True))
        if dotnet_packages is not None:
            from sdk_unified import install_dotnet
            installed.append(install_dotnet(root / "dotnet", None, Path(dotnet_packages).resolve(), direct=True))
        if c_packages is not None:
            from sdk_unified import install_c
            for language in ("c", "cpp"):
                installed.append(install_c(root / language, None, language, Path(c_packages).resolve(), direct=True))
        if beam_packages is not None:
            from sdk_unified import install_beam
            for language in ("erlang", "elixir"):
                installed.append(install_beam(root / language, None, language, Path(beam_packages).resolve(), direct=True))
        if rust_packages is not None:
            from sdk_unified import install_rust
            installed.append(install_rust(root / "rust", None, Path(rust_packages).resolve(), direct=True))
        if node_packages is not None:
            from sdk_unified import install_node
            installed.append(install_node(root / "node", None, Path(node_packages).resolve(), direct=True))
        if python_packages is not None:
            from sdk_unified import install_python_direct
            installed.append(install_python_direct(root / "python", Path(python_packages).resolve()))
        if ruby_packages is not None:
            from sdk_unified import install_ruby
            installed.append(install_ruby(root / "ruby", None, Path(ruby_packages).resolve(), direct=True))
        profile = root / "profile.json"
        config = root / "node.json"
        seed = root / "registrar.seed"
        seed.write_text("11" * 32)
        seed.chmod(0o600)
        port = free_port()
        url = f"http://127.0.0.1:{port}"
        settings = {
            "genesis": {"realm": 42, "root_key": json.loads(subprocess.check_output([caller, "public"], timeout=15)), "max_clock_error_ms": 10000},
            "local_directory": str(root / "native"),
            "port": port, "resident_pages": 1, "request_timeout_ms": 60000,
        }
        config.write_text(json.dumps(settings))
        http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        log = (root / "node.log").open("w+")
        authority = None
        proxy = None
        thread = None
        faults = {"pin": False, "release": False, "cleanup_release": False}
        freshness_faults = {1062: 0, 1063: 0}
        history_gap = False
        naming_faults = set()
        naming_pending = {}
        naming_recovered = set()
        named_dependency_faults = set()
        named_publications = {}
        proxy_failures = []

        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def do_POST(self):
                nonlocal history_gap, authority
                body = self.rfile.read(int(self.headers["Content-Length"]))
                envelope = json.loads(body)
                connection = HTTPConnection("127.0.0.1", port, timeout=70)
                headers = {"Content-Type": "application/json"}
                for name in ("x-transit-control", "x-transit-wait"):
                    if name in self.headers:
                        headers[name] = self.headers[name]
                try:
                    connection.request("POST", self.path, body, headers)
                    response = connection.getresponse()
                    data = response.read()
                    status = response.status
                    if self.path == "/v1/query" and status == 200 and (named_only or maintained_only):
                        query = envelope["query"]
                        kind = query["kind"]
                        authorization = kind.get("authorization") if isinstance(kind, dict) else None
                        original = authorization["kind"].get("receipt") if authorization and isinstance(authorization["kind"], dict) else None
                        if original is not None:
                            for sent, (identity, receipt, saved_path, saved_bytes) in list(naming_pending.items()):
                                if json.loads(sent)["request"] != original:
                                    continue
                                assert query["principal"] == original["principal"]
                                recovered = json.loads(data)["body"]["authorization"]["body"]["receipt"]
                                assert recovered == json.loads(receipt), "Original naming receipt changed after replacement"
                                assert saved_path.read_bytes() == saved_bytes, "Saved naming proposal changed during recovery"
                                del naming_pending[sent]
                                naming_recovered.add(identity)
                    if self.path == "/v1/command" and status == 200 and (named_only or maintained_only):
                        if body in naming_pending:
                            raise AssertionError("Retired worker signature unexpectedly accepted after rotation")
                        else:
                            request = envelope["request"]
                            command = request["command"]
                            turn = command.get("turn", command.get("turn_with_versions", {}).get("turn"))
                            if turn:
                                values = [bytes.fromhex(entry["value"]) for entry in turn["mutations"] if entry and entry["value"]]
                                for magic in (b"NRD1", b"NRP1", b"NRT1"):
                                    identity = (request["principal"], magic)
                                    if identity in naming_faults or not any(value.startswith(magic) for value in values):
                                        continue
                                    saved_path = root / f"named-pending-{request['principal']}.json"
                                    saved_bytes = saved_path.read_bytes()
                                    saved = json.loads(saved_bytes)
                                    assert saved["pending"]["signed"]["request"] == request
                                    assert saved["pending"]["signed"]["signature"] == envelope["signature"]
                                    assert saved_path.stat().st_mode & 0o777 == 0o600
                                    naming_faults.add(identity)
                                    naming_pending[body] = (identity, data, saved_path, saved_bytes)
                                    # The authority accepted the proposal. Replace
                                    # its OS process before exposing an unusable
                                    # reply; the caller must retain its old bytes.
                                    authority.kill()
                                    authority.wait(timeout=15)
                                    authority = None
                                    authority = start()
                                    data = b'{"position":0}'
                                    break
                    if self.path == "/table/v1" and status == 200 and (named_only or maintained_only):
                        dependency = envelope["action"].get("dependency_operation")
                        if dependency and dependency["command"] == "accept" and dependency["binding"]["action"] == "register":
                            binding = dependency["binding"]
                            dependent = binding["edge"]["dependent"]["interpretation"]
                            resource = dependent["object"]["scope"]["resource"]
                            revision = dependent["revision"]
                            identity = (resource, revision, binding["edge"]["source"]["object"]["object"])
                            if identity not in named_dependency_faults:
                                saved_path = root / f"named-publication-{resource}-{revision}.json"
                                saved = saved_path.read_bytes()
                                assert binding in json.loads(saved)["bindings"]
                                assert saved_path.stat().st_mode & 0o777 == 0o600
                                assert json.loads(data)["result"]["dependency_operation"]["outcome"]["phase"] == "applied"
                                named_dependency_faults.add(identity)
                                named_publications[saved_path] = saved
                                authority.kill()
                                authority.wait(timeout=15)
                                authority = None
                                authority = start()
                                response = json.loads(data)
                                response["context"][0] ^= 1
                                data = json.dumps(response).encode()
                    if self.path == "/table/v1" and "observe" in envelope["action"]:
                        object_id = envelope["action"]["observe"]["interpretation"]["object"]["object"]
                        fault = freshness_faults.get(object_id, 2)
                        if fault < 2:
                            assert status == 200, data
                            status, rejection = (409, "Conflict") if fault == 0 else (503, "AuthorityUnavailable")
                            data = json.dumps({"err": rejection}).encode()
                            freshness_faults[object_id] += 1
                    if self.path == "/table/v1" and "history" in envelope["action"] and envelope["action"]["history"]["snapshot"]["object"]["object"] == 84 and not history_gap:
                        # Permanent retained-coverage rejection at the service
                        # boundary. This is not a disk-corruption experiment.
                        assert status == 200, data
                        status, data = 409, json.dumps({"err": "HistoryReclaimed"}).encode()
                        history_gap = True
                    if self.path == "/table/v1" and envelope["delegation"] and envelope["delegation"]["binding"]["retention"] == "snapshot" and not relational_failures_only and not unified_boundaries_only and not follow_only and not named_only:
                        action = next(iter(envelope["action"]))
                        fault = "cleanup_release" if action == "release" and envelope.get("closure") else action
                        if fault in faults and not faults[fault]:
                            assert response.status == 200, data
                            parsed = json.loads(data)
                            assert ("pin" if action == "pin" else "released") in parsed["result"]
                            parsed["context"][0] ^= 1
                            data = json.dumps(parsed).encode()
                            faults[fault] = True
                    self.send_response(status)
                    self.send_header("Content-Type", "application/json")
                    self.send_header("Content-Length", str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                except BaseException as error:
                    proxy_failures.append(type(error).__name__)
                    raise
                finally:
                    connection.close()

        def consumers(endpoint, phase):
            for consumer in installed:
                consumer(endpoint, profile, phase)
            if python_native is not None:
                from python_direct_capture import run as python_capture
                python_capture(profile, endpoint, phase, python_native)
            if ruby_host is not None:
                subprocess.run(["ruby", str(Path(__file__).with_name("ruby_direct_capture.rb")),
                    endpoint, str(profile), phase, str(Path(ruby_host).resolve())], check=True, timeout=120)

        def start():
            child = subprocess.Popen([node, str(config), "--bootstrap"], stdout=log, stderr=subprocess.STDOUT)
            try:
                wait_ready(http, child, url + "/health")
            except BaseException:
                child.kill()
                child.wait(timeout=15)
                raise
            return child

        def stop(child):
            child.terminate()
            try:
                child.wait(timeout=15)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait(timeout=15)

        try:
            authority = start()
            subprocess.run([caller, url, "provision", str(profile)], check=True, timeout=180)
            stop(authority)
            authority = None
            settings["table"] = {"catalog": json.loads(profile.read_text())["catalog"], "registrar": {"principal": 0, "seed_file": str(seed)}}
            config.write_text(json.dumps(settings))
            authority = start()
            proxy = ThreadingHTTPServer(("127.0.0.1", 0), Proxy)
            thread = threading.Thread(target=proxy.serve_forever, daemon=True)
            thread.start()
            endpoint = f"http://127.0.0.1:{proxy.server_port}"
            if named_only:
                subprocess.run([caller, endpoint, "maintained-initialize", str(profile)], check=True, timeout=120)
                # Twelve accepted-reply faults each replace the disk-backed node;
                # both query shapes also verify retirement and source DROP.
                subprocess.run([caller, endpoint, "capture-named", str(profile)], check=True, timeout=1200)
                assert all(value == 2 for value in freshness_faults.values()), freshness_faults
                expected = {(principal, magic) for principal in (151, 152) for magic in (b"NRD1", b"NRP1", b"NRT1")}
                assert naming_faults == naming_recovered == expected and not naming_pending and not proxy_failures
                assert not list(root.glob("named-pending-*.json"))
                assert len(named_dependency_faults) == 6 and len(named_publications) == 4
                assert all(path.read_bytes() == saved for path, saved in named_publications.items())
                print("Direct named queries: six exact dependency registrations recovered after withheld replies and node replacement, saved publication/authorization/retirement proposals, lost accepted replies, worker key/generation rotation, original receipts and logical references, publication without execution, explicit activation, original attribution, verified independent Table cuts, current disclosure denial, DROP RESTRICT and explicit retirement/removal with retained results passed.", flush=True)
                return
            if follow_only:
                subprocess.run([caller, endpoint, "maintained-initialize", str(profile)], check=True, timeout=120)
                subprocess.run([caller, endpoint, "follow-prepare", str(profile)], check=True, timeout=240)
                stop(authority)
                authority = None
                authority = start()
                subprocess.run([caller, endpoint, "follow-resume", str(profile)], check=True, timeout=240)
                if example is not None:
                    saved = json.loads(profile.read_text())["follow"]
                    example_seed = root / "example.seed"
                    example_seed.write_text("1d" * 32)
                    example_seed.chmod(0o600)
                    recovery = root / "example-recovery.json"
                    example_config = root / "example.json"
                    settings = {"url": endpoint, "seed_file": str(example_seed),
                                "connection": saved["connection"], "workspace": saved["workspace"],
                                "namespace": 970, "sql": "SELECT SUM(value) AS total FROM follow_items",
                                "recovery_file": str(recovery), "mode": "upload"}
                    example_config.write_text(json.dumps(settings))
                    uploader = subprocess.Popen([example, str(example_config)], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                    try:
                        subprocess.run([caller, endpoint, "follow-example", str(profile)], check=True, timeout=240)
                        output, errors = uploader.communicate(timeout=30)
                        assert uploader.returncode == 0, (output, errors)
                    finally:
                        if uploader.poll() is None:
                            uploader.kill()
                            uploader.communicate(timeout=15)
                    original = recovery.read_bytes()
                    # A new OS process recovers the saved signed capture rather
                    # than compiling/authorizing another query under this name.
                    subprocess.run([example, str(example_config)], check=True, timeout=60, capture_output=True)
                    assert recovery.read_bytes() == original
                    settings["mode"] = "read"
                    example_config.write_text(json.dumps(settings))
                    pages = [json.loads(line) for line in subprocess.check_output([example, str(example_config)], timeout=60).splitlines()]
                    assert len(pages) == 1 and pages[0]["complete_coverage"]
                    assert pages[0]["cells"] == [[{"value": {"atom": {"signed": "20"}}}]], pages
                    print("Direct state-query example: separate caller compilation, capture authorization, saved upload, OS-process recovery and verified SUM=20 passed.", flush=True)
                print("Direct Follow: prepared single-use captures, durable selection before node restart, native worker replacement, verified fresh result and bounded pause passed.", flush=True)
                return
            if maintained_only or relational_failures_only or source_pages_only or exchanges_only or unified_boundaries_only:
                subprocess.run([caller, endpoint, "maintained-initialize", str(profile)], check=True, timeout=120)
            else:
                subprocess.run([caller, endpoint, "capture-prepare", str(profile)], check=True, timeout=240)
                consumers(endpoint, "prepare")
                for phase in ("capture-uncertain-pin", "capture-uncertain-release"):
                    stop(authority)
                    authority = None
                    authority = start()
                    subprocess.run([caller, endpoint, phase, str(profile)], check=True, timeout=240)
                assert faults["pin"] and faults["release"], faults
                stop(authority)
                authority = None
                authority = start()
                subprocess.run([caller, endpoint, "capture-resume", str(profile)], check=True, timeout=240)
                assert all(faults.values()), faults
                if not captured_only:
                    subprocess.run([caller, endpoint, "capture-source-pages", str(profile)], check=True, timeout=600)
                    subprocess.run([caller, endpoint, "capture-relational", str(profile)], check=True, timeout=600)
                    subprocess.run([caller, endpoint, "capture-named", str(profile)], check=True, timeout=600)
            if exchanges_only:
                subprocess.run([caller, endpoint, "capture-exchanges", str(profile)], check=True, timeout=900)
                print("Direct exchanges: independent receiver/worker placement, exact borrowed history cuts, one/seven-partition successor attachments, retained request retirement, host reconstruction and lease cleanup passed.", flush=True)
            elif source_pages_only:
                subprocess.run([caller, endpoint, "capture-source-pages", str(profile)], check=True, timeout=600)
                print("Direct retained source pages: wide/nested values, original interpretation, signed predicate boundaries, point-hit/absence, unsafe pushdown rejection and current permission passed.", flush=True)
            elif not relational_failures_only and not unified_boundaries_only and not captured_only:
                subprocess.run([caller, endpoint, "maintained-prepare", str(profile)], check=True, timeout=600 if maintained_only else 240)
                stop(authority)
                authority = None
                authority = start()
                # Both shapes publish a second definition and restart after each
                # new dependency registration before checking backfill progress.
                subprocess.run([caller, endpoint, "maintained-backfill", str(profile)], check=True, timeout=1200 if maintained_only else 600)
                stop(authority)
                authority = None
                authority = start()
                subprocess.run([caller, endpoint, "maintained-resume", str(profile)], check=True, timeout=900 if maintained_only else 600)
                if maintained_only:
                    expected = {(principal, magic) for principal in (107, 108) for magic in (b"NRD1", b"NRP1", b"NRT1")}
                    assert naming_faults == naming_recovered == expected and not naming_pending and not proxy_failures
                    assert not list(root.glob("named-pending-*.json"))
                    assert len(named_dependency_faults) == 6 and len(named_publications) == 4
                    assert all(path.read_bytes() == saved for path, saved in named_publications.items())
                print("Direct maintained query: original acquisition recovery, bounded physical history progress across node replacement, initial backfill, alias and independent Table cuts, accepted no-op revisions, paired deltas, original lease cleanup, post-closure disclosure, current revocation/restoration and retirement passed.", flush=True)
            if not maintained_only and not source_pages_only and not exchanges_only and not unified_boundaries_only and not captured_only:
                for case in ("captured_work", "captured_spill", "captured_overflow", "maintained_overflow", "maintained_gap"):
                    subprocess.run([caller, endpoint, "relational-failure-" + case, str(profile)], check=True, timeout=600)
                assert history_gap
                print("Direct relational failures: work/spill bounds, captured and maintained ordered-overflow witnesses, permanent history-coverage rejection, separate explicit rebuild, preserved prior results and original lease cleanup passed.", flush=True)
            if not any((maintained_only, relational_failures_only, source_pages_only, exchanges_only, unified_boundaries_only, captured_only)):
                subprocess.run([caller, endpoint, "capture-exchanges", str(profile)], check=True, timeout=900)
            if unified_boundaries_only or not any((maintained_only, relational_failures_only, source_pages_only, exchanges_only, captured_only)):
                for case in ("retired_empty", "large_row", "adapter_memory", "arrow_memory", "external_memory"):
                    subprocess.run([caller, endpoint, "unified-boundary-" + case, str(profile)], check=True, timeout=600)
                print("Direct finite capture: empty retired sources, preserved large rows, adapter/Arrow budgets, retryable external allocation failures and original lease cleanup passed.", flush=True)
            consumers(endpoint, "result")
            if captured_only:
                print("Direct captured query: original-cut recovery, verified retained Table evidence after pin closure, current disclosure rights and separate cleanup after credential rotation passed.", flush=True)
            elif not maintained_only and not relational_failures_only and not source_pages_only and not exchanges_only and not unified_boundaries_only:
                print("Direct captured query: independent worker resource, durable pre-acquisition restart, uncertain pin acquisition/release, original unflushed cuts, wide/nested Fuze/Arrow traversal after ALTER/DROP/name reuse, composite-key hit/absence, shared-alias and independent-Table relational capture, executor without Table rights, released-pin result disclosure, current revocation/restoration and separately authorized cleanup after credential rotation passed.")
        except BaseException:
            log.flush()
            log.seek(0)
            sys.stderr.write(log.read()[-24000:])
            raise
        finally:
            if proxy is not None:
                proxy.shutdown()
                proxy.server_close()
            if thread is not None:
                thread.join(timeout=15)
            if authority is not None:
                stop(authority)
            log.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("node")
    parser.add_argument("caller")
    parser.add_argument("--maintained-only", action="store_true")
    parser.add_argument("--relational-failures-only", action="store_true")
    parser.add_argument("--source-pages-only", action="store_true")
    parser.add_argument("--exchanges-only", action="store_true")
    parser.add_argument("--unified-boundaries-only", action="store_true")
    parser.add_argument("--captured-only", action="store_true")
    parser.add_argument("--follow-only", action="store_true")
    parser.add_argument("--named-only", action="store_true")
    parser.add_argument("--example")
    parser.add_argument("--python-native")
    parser.add_argument("--ruby-host")
    parser.add_argument("--java-packages")
    parser.add_argument("--dotnet-packages")
    parser.add_argument("--c-packages")
    parser.add_argument("--beam-packages")
    parser.add_argument("--rust-packages")
    parser.add_argument("--node-packages")
    parser.add_argument("--python-packages")
    parser.add_argument("--ruby-packages")
    run(**vars(parser.parse_args()))
