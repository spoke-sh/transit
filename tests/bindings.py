"""Real-authority qualification shared by every foreign Station caller."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

from inspection import System
from station import frame

ROOT = Path(__file__).resolve().parents[1]


def pair(node, cli, courier, library, raw_library, host, service_command, requester_command, label):
    with System(node, cli, clock_error_ms=10000) as s:
        records = []
        for principal in (1, 2):
            pid = s.command({"lifecycle": {"create": {"required": [b"data".hex(), None, None, None]}}})
            resource = s.command({"state": {"create": {"writer": pid}}})
            seed, public = s.key(f"foreign-{principal}")
            s.command({"grant": {"subject": principal, "public_key": public, "permissions": 88, "pid": pid}})
            for subject in (0, principal):
                s.command({"state": {"grant": {"resource": resource, "subject": subject, "permissions": 7}}})
            s.command({"state": {"associate": {"pid": pid, "name": b"data".hex(), "resource": resource}}})
            s.command({"send": {"pid": pid, "value": frame(b"init")}})
            s.command({"lifecycle": {"initialize": {"pid": pid, "expected_generation": 1}}})
            s.command({"own": {"pid": pid, "worker": principal, "expected_generation": 2}})
            config = s.root / f"host-{principal}.json"
            config.write_text(json.dumps({"url": s.url, "seed_file": str(seed), "server": {
                "realm": 72, "principal": principal, "pid": pid, "generation": 3}}))
            records.append((pid, resource, config))
        seed, public = s.key("courier")
        s.command({"grant": {"subject": 3, "public_key": public, "permissions": 132}})
        delivery = s.root / "delivery.json"
        delivery.write_text(json.dumps({"url": s.url, "realm": 72, "principal": 3,
            "seed_file": str(seed), "interval_ms": 10}))
        s.start(courier, delivery)
        libraries = s.root / "libraries"
        libraries.mkdir()
        for name, source in (("station", library), ("client", raw_library)):
            (libraries / f"libtransit_{name}.so").symlink_to(Path(source).resolve())
        env = os.environ | {"TRANSIT_LIBRARY_DIR": str(libraries),
            "TRANSIT_HOST": str(Path(host).resolve()),
            "PYTHONPATH": str(ROOT / "packages/python/transit-station"),
            "ERL_FLAGS": "+S 2:2 +SDcpu 1 +SDio 1"}
        def once(index):
            pid, _, config = records[index]
            for _ in range(300):
                if s.post("/v2/view", s.signed({"inspect": pid}))["input"] is not None:
                    break
                time.sleep(.025)
            else:
                raise AssertionError((label, "undelivered", pid))
            command = service_command if index == 0 else requester_command
            child = s.start(*command, config, "service" if index == 0 else "requester", records[1-index][0], env=env)
            assert child.wait(timeout=30) == 0, (label, command)
        def observed():
            query = s.root / "entries.json"
            query.write_text(json.dumps({"realm": 72, "principal": 0, "kind": "entries",
                "resource": records[1][1], "key": b"observed".hex()}))
            entry = s.post("/v2/state", s.invoke("sign-state", s.seed, query))["entries"][0]
            return bytes.fromhex(entry["value"]) if entry else None
        once(0)
        once(1)
        s.command({"send": {"pid": records[1][0], "value": frame(b"call")}})
        once(1)
        suspended = s.post("/v2/view", s.signed({"inspect": records[1][0]}))
        once(0)  # durable capture
        once(0)  # captured publication, in a new foreign/native host
        for _ in range(4):
            if observed() is not None:
                break
            once(1)
        assert observed() == b"9007199254740993", label
        from sdk_scenarios import check
        check("durable-continuation", {"observed_wide_integer": observed().decode(),
            "source_admitted": suspended["process"]["admitted"] == 2,
            "source_turn_completed_before_reply": suspended["process"]["consumed"] == 2 and suspended["input"] is None})
        once(0)  # acknowledgement, without deleting the result
        print(f"Bindings {label}: handler, associated Table, correlation, host restart and exact Arrow int64 passed", flush=True)


def run(node, cli, courier, library, raw_library, host, c, cpp, *extra):
    from station_abi import run as abi_proof
    # Completion can wake the caller before a bounded native pool retires its
    # previous workers. Exercise both ABIs without spare CPUs hiding that race;
    # restore affinity before building/running the rest of the language matrix.
    affinity = os.sched_getaffinity(0) if hasattr(os, "sched_getaffinity") else None
    try:
        if affinity:
            os.sched_setaffinity(0, {min(affinity)})
        abi_proof(node, cli, library, raw_library, host)
    finally:
        if affinity:
            os.sched_setaffinity(0, affinity)
    python = [sys.executable, str(ROOT / "examples/station-bindings/python/main.py")]
    pair(node, cli, courier, library, raw_library, host, python, python, "Python")
    pair(node, cli, courier, library, raw_library, host, [c], [cpp], "C → C++")
    pair(node, cli, courier, library, raw_library, host, [cpp], python, "C++ → Python")
    pair(node, cli, courier, library, raw_library, host, python, [c], "Python → C")
    if extra:
        assert extra == ("foreign",)
        libraries = ROOT / ".cache/bindings/lib"
        libraries.mkdir(parents=True, exist_ok=True)
        for name, source in (("station", library), ("client", raw_library)):
            path = libraries / f"libtransit_{name}.so"
            path.unlink(missing_ok=True)
            path.symlink_to(Path(source).resolve())
        target = ROOT / ".cache/bindings/rust"
        env = os.environ | {"TRANSIT_LIBRARY_DIR": str(libraries), "CARGO_TARGET_DIR": str(target)}
        subprocess.run(["cargo", "build", "--locked", "--manifest-path", ROOT / "packages/rust/transit-station/Cargo.toml", "--example", "station"], env=env, check=True)
        rust = [target / "debug/examples/station"]
        pair(node, cli, courier, library, raw_library, host, rust, [cpp], "Rust → C++")
        pair(node, cli, courier, library, raw_library, host, [c], rust, "C → Rust")
        nodejs = ["node", ROOT / "examples/station-bindings/node/main.ts"]
        pair(node, cli, courier, library, raw_library, host, nodejs, rust, "Node → Rust")
        pair(node, cli, courier, library, raw_library, host, python, nodejs, "Python → Node")
        classes = ROOT / ".cache/bindings/java"
        classes.mkdir(parents=True, exist_ok=True)
        gson = os.environ["TRANSIT_GSON_JAR"]
        sources = list((ROOT / "packages/java/transit-station/src").rglob("*.java"))
        subprocess.run(["javac", "-Xlint:all,-classfile", "-Werror", "-cp", gson, "-d", classes,
                        *sources, ROOT / "examples/station-bindings/java/StationExample.java",
                        ROOT / "tests/BindingPort.java"], check=True)
        java = ["java", "-cp", str(classes) + os.pathsep + gson, "StationExample"]
        with tempfile.TemporaryDirectory(prefix="station-java-") as temporary:
            subprocess.run(["java", "-cp", str(classes) + os.pathsep + gson, "BindingPort",
                            ROOT / "tests/binding_port_fixture.py", temporary], check=True, timeout=20)
        pair(node, cli, courier, library, raw_library, host, java, nodejs, "Java → Node")
        pair(node, cli, courier, library, raw_library, host, rust, java, "Rust → Java")
        artifacts = ROOT / ".cache/bindings/dotnet"
        subprocess.run(["dotnet", "build", ROOT / "examples/station-bindings/dotnet/StationExample.csproj",
                        "--configfile", ROOT / "packages/dotnet/transit-station/NuGet.Config",
                        "--artifacts-path", artifacts], check=True)
        dotnet = ["dotnet", artifacts / "bin/StationExample/debug/StationExample.dll"]
        subprocess.run([*dotnet, "--boundary-proof"], env=env, check=True, timeout=20)
        pair(node, cli, courier, library, raw_library, host, dotnet, java, ".NET → Java")
        pair(node, cli, courier, library, raw_library, host, nodejs, dotnet, "Node → .NET")
        beam = ROOT / ".cache/bindings/beam"
        beam.mkdir(parents=True, exist_ok=True)
        (beam / "Elixir.Transit.Station.beam").unlink(missing_ok=True)
        beam_env = os.environ | {"ERL_FLAGS": "+S 2:2 +SDcpu 1 +SDio 1"}
        subprocess.run(["erlc", "-Werror", "-I", ROOT / "packages/beam/transit-station/include",
                        "-o", beam, ROOT / "packages/beam/transit-station/src/transit_station.erl",
                        ROOT / "examples/station-bindings/erlang/station_example.erl",
                        ROOT / "tests/binding_port.erl"], env=beam_env, check=True)
        subprocess.run(["elixirc", "--warnings-as-errors", "-pa", beam, "-o", beam,
                        ROOT / "packages/beam/transit-station/lib/transit_station.ex"], env=beam_env, check=True)
        erlang = ["erl", "-noshell", "-pa", beam, "-eval",
                  "station_example:main(init:get_plain_arguments()), halt().", "-extra"]
        elixir = ["elixir", "-pa", beam, ROOT / "examples/station-bindings/elixir/main.exs"]
        with tempfile.TemporaryDirectory(prefix="station-beam-") as temporary:
            subprocess.run(["erl", "-noshell", "-pa", beam, "-s", "binding_port", "run", "-extra",
                            ROOT / "tests/binding_port_fixture.py", temporary], env=beam_env, check=True, timeout=20)
        pair(node, cli, courier, library, raw_library, host, erlang, dotnet, "Erlang → .NET")
        pair(node, cli, courier, library, raw_library, host, java, erlang, "Java → Erlang")
        pair(node, cli, courier, library, raw_library, host, elixir, erlang, "Elixir → Erlang")
        pair(node, cli, courier, library, raw_library, host, python, elixir, "Python → Elixir")


if __name__ == "__main__":
    run(*sys.argv[1:])
