"""Two-editor Document schedule in owned Compose or reference infrastructure."""
import json
import ipaddress
import os
from pathlib import Path
import secrets
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'examples'))
from server_config import configuration as server_configuration, wait_delivered
sys.path.insert(0, str(ROOT / "launchers"))
from native_client import Client, public_key
sys.path.insert(0, str(ROOT / "tests"))
from storage.providers.cold_storage import ColdStore
from runtime.document.document_contract import encode
from placement import Compose, Reference


def run(profile):
    assert profile in ("compose", "reference")
    started = time.monotonic()
    host = ROOT / "zig-out/bin/transit-client-host"
    env = {k: v for k, v in os.environ.items() if not k.startswith(("OTEL_",))}
    env.update(LOG_LEVEL="warn", RUST_LOG="warn", TOKIO_WORKER_THREADS="2")
    http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    with tempfile.TemporaryDirectory(prefix="transit-document-") as directory:
        work = Path(directory)
        for role in ("operator", "writer", "left", "right"):
            (work / role).mkdir(mode=0o700)
            if role != "operator": (work / (role+"-activations")).mkdir(mode=0o700)
        (work / "wal").mkdir()
        placement = None
        cold = None

        def write(path, value):
            path = work / path
            path.write_text(json.dumps(value))
            path.chmod(0o600)
            return path

        def invoke(argv):
            result = subprocess.run(list(map(str, argv)), env=env, capture_output=True, timeout=120)
            if result.returncode: raise RuntimeError(result.stderr.decode()[-4000:])
            return json.loads(result.stdout)

        def ready(child, url):
            deadline = time.monotonic() + 60
            while child.poll() is None and time.monotonic() < deadline:
                try:
                    with http.open(url, timeout=.5) as response:
                        if response.status == 200: return
                except (urllib.error.URLError, TimeoutError, ConnectionError): pass
                time.sleep(.1)
            raise RuntimeError("Document example service unavailable")

        keys, public = {}, {}
        for role in ("operator", "writer", "left", "right"):
            keys[role] = work / role / "seed.key"
            keys[role].write_text(secrets.token_hex(32))
            keys[role].chmod(0o600)
            public[role] = public_key(keys[role])
        realm = secrets.randbelow(2**30)+1
        url = ""

        def query(kind):
            return Client(host, url).query(keys["operator"], dict(realm=realm, principal=0, kind=kind))

        def command(body):
            sequence = query({"capabilities": {}})["principal_sequence"]+1
            request = write(f"operator/command-{sequence}.json", dict(realm=realm, principal=0, sequence=sequence, command=body))
            for attempt in range(3):
                try: return Client(host, url).submit(keys["operator"], json.loads(request.read_text()))["position"]
                except RuntimeError:
                    if attempt == 2: raise

        try:
            placement = Reference(work) if profile == "reference" else Compose(work)
            if profile == "compose":
                placement.prepare_storage_network()
                network = placement.project + "_storage"
            else:
                network = "kind"
            addresses = json.loads(subprocess.check_output(['docker', 'network', 'inspect', network]))[0]['IPAM']['Config']
            bridge = next((item['Gateway'] for item in addresses if 'Gateway' in item and ipaddress.ip_address(item['Gateway']).version == 4), None)
            if bridge is None: raise RuntimeError('Document placement needs a private IPv4 bridge gateway')
            cold = ColdStore(bind_address=bridge).__enter__()
            placement.cold_address, placement.cold_port = bridge, cold.port
            write("operator/node.json", server_configuration(realm, '/operator/seed.key',
                object_storage=cold.placement_config(work)))
            placement.initialize()
            authority = placement.start("node")
            url = placement.url("node")
            ready(authority, url+"/health")
            denied = [placement.cold_address+":"+str(cold.port), "1.1.1.1:443"]
            assert placement.invoke("caller-probe", "probe", placement.authority, *denied) == dict(authority="reachable", denied=len(denied))
            records = {}
            for principal, role in enumerate(("writer", "left", "right"), 1):
                pid = command({"spawn": {}})
                resource = command({"create_resource": {"writer": pid, "owned": False}})
                records[role] = dict(pid=pid, resource=resource, principal=principal)
                command({"grant": {"subject": principal, "public_key": public[role], "permissions": 4|8|16|64, "pid": pid}})
                for subject in (0, principal): command({"grant_resource": {"resource": resource, "subject": subject, "permissions": 7}})
                command({"associate": {"pid": pid, "name": b"state".hex(), "resource": resource}})
            writer = records["writer"]
            for role in ("left", "right"):
                other = records[role]
                command({"associate": {"pid": writer["pid"], "name": role.encode().hex(), "resource": other["resource"], "required": False}})
                command({"associate": {"pid": other["pid"], "name": b"document".hex(), "resource": writer["resource"], "required": False}})
                command({"grant_resource": {"resource": other["resource"], "subject": writer["principal"], "permissions": 3}})
                command({"grant_resource": {"resource": writer["resource"], "subject": other["principal"], "permissions": 3}})
            policies = [dict(caller=records[role]["pid"], resource=records[role]["resource"], replica=replica, revision=1) for replica, role in enumerate(("left", "right"), 1)]

            def activate(role, mode, **extra):
                record = records[role]
                generation = query({"process": record["pid"]})["body"]["process"]["process"]["generation"]
                config = dict(url=placement.authority, realm=realm, pid=record["pid"], principal=record["principal"], generation=generation+1,
                    seed_file=f"/{role}/seed.key", activation_directory="/activations", document=17, mode=mode, **extra)
                if profile == "reference" and role == "writer":
                    # The trusted pod's firewall already pins this Service IP.
                    # Resolve physical placement once, rather than adding a DNS
                    # exchange to every bounded signed resource read.
                    config["url"] = "http://" + placement.address("node") + ":8080"
                if profile == "reference" and role != "writer":
                    config.pop("seed_file")
                    config["activation_directory"] = "/runtime-data"
                    handle, registration = placement.register(config)
                    assert registration == dict(version=1, realm=realm, pid=record["pid"], principal=record["principal"], generation=generation+1, public_key=registration["public_key"])
                    assert len(registration["public_key"]) == 32 and registration["public_key"] != public[role]
                    public[role] = registration["public_key"]
                    command({"grant": {"subject": record["principal"], "public_key": public[role], "permissions": 4|8|16|64, "pid": record["pid"]}})
                    command({"grant_resource": {"resource": record["resource"], "subject": record["principal"], "permissions": 7}})
                    command({"grant_resource": {"resource": writer["resource"], "subject": record["principal"], "permissions": 3}})
                    command({"own": {"pid": record["pid"], "expected_generation": generation, "worker": record["principal"]}})
                    return placement.finish(handle)
                command({"own": {"pid": record["pid"], "expected_generation": generation, "worker": record["principal"]}})
                write(role+"/config.json", config)
                return placement.invoke(role)

            def worker(mode="run", **extra):
                return activate("writer", mode, policies=policies, **extra)

            def deliver():
                wait_delivered(query)

            def dot(counter, replica=1): return dict(counter=str(counter), replica=str(replica))
            def assign(value, observed=()): return {"assign": {"field": "title", "observed": list(observed), "value": {"string": value}}}
            common = dict(document="17", epoch="1", type_revision=1)
            seed = dict(common, replica="1", first="1", operations=[assign("Notes"), {"assign": {"field": "body", "value": {"text": {}}}}, {"insert": {"object": dot(2), "value": {"character": "A"}}}])
            left = dict(common, replica="1", previous="3", first="4", operations=[assign("Left", [dot(1)]), {"insert": {"object": dot(2), "after": dot(3), "value": {"character": "a"}}}])
            right = dict(common, replica="2", first="4", operations=[assign("Right", [dot(1)]), {"insert": {"object": dot(2), "after": dot(3), "value": {"character": "🙂"}}}])
            resolve = dict(common, replica="1", previous="5", first="6", operations=[assign("Resolved", [dot(4), dot(4, 2)])])
            def caller(role, mode, namespace=1, change=seed):
                return activate(role, mode, writer=writer["pid"], resource=writer["resource"], replica=1 if role == "left" else 2, namespace=namespace, change=encode(change).hex())

            def submit(role, namespace, change):
                assert caller(role, "publish", namespace, change)["phase"] == "called"
                deliver()
                assert worker()["phase"] == "complete"
                deliver()
                return caller(role, "receive", namespace, change)

            assert worker("create")["revision"] == "0"
            assert caller("left", "publish")["phase"] == "called"
            if profile == "reference": placement.kill_caller_worker()
            assert caller("left", "publish")["phase"] == "called"
            deliver()
            pending = worker(max_steps=2)
            assert pending["phase"] == "progress" and pending["revision"] == "0" and pending["active_job"] != "0"
            # Unpublished material survives physical node/store loss; only the
            # same durable PID under fresh ownership may resume its candidate.
            placement.stop_for_recovery("node", authority)
            authority = placement.start("node")
            url = placement.url("node")
            ready(authority, url+"/health")
            assert worker()["revision"] == "1"
            deliver()
            assert caller("left", "receive")["phase"] == "accepted"
            print("Document placement: caller recovery and unpublished candidate after node/store loss passed", flush=True)
            assert submit("right", 1, right)["revision"] == "2"
            assert submit("left", 2, left)["revision"] == "3"
            view = caller("right", "inspect", change=right)
            assert (view["title_status"], view["alternatives"], view["text"]) == ("conflict", 2, "A🙂a"), view
            assert submit("left", 3, left)["phase"] == "duplicate"
            assert submit("left", 4, resolve)["revision"] == "4"
            assert caller("right", "inspect", change=right)["title_status"] == "scalar"
            worker("window", merge_window=2)
            assert worker("checkpoint", job=90)["epoch"] == "2"
            rejected = submit("right", 2, right)
            assert rejected["phase"] == "rejected" and rejected["reason"] == "resynchronize"
            sync = caller("right", "resynchronize", change=right)
            assert sync["epoch"] == 2 and sync["floor"] == 4 and sync["previous_counter"] == 5
            worker("retire")
            assert submit("right", 3, right)["reason"] == "retired"
            assert cold.native_data_objects() > 0, "Cold spill was not exercised"
            print("Document placement evidence:", json.dumps(dict(profile=profile, seconds=round(time.monotonic()-started, 2), independent_editors=2,
                node_store_restarts=1, unpublished_recovery=True, bootstrap=profile=="reference", conflicts_resolved=True,
                resynchronized=True, retired=True, caller_storage_denied=True, cache_bytes=32*1024*1024, cold_objects=cold.native_data_objects(), cold_bytes=cold.file_bytes())), flush=True)
        except BaseException:
            if placement:
                print(placement.call("ps", "--all", "--format", "json"))
                print(placement.call("logs", "--tail", "80"))
            raise
        finally:
            try:
                if placement: placement.close()
            finally:
                if cold: cold.__exit__(None, None, None)
