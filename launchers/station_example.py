"""Trusted development provisioning for the bounded three-process Station example."""
import json
import secrets
import struct

from common import Installation, ROOT, lock, run, write


def frame(payload):
    return (b"STN1\x01" + bytes(8) + payload).hex()


class StationInstallation(Installation):
    example = "station"
    workloads = ("ledger", "requester", "coordinator")
    principals = {"ledger": 1, "requester": 6, "coordinator": 7}
    artifact_roles = {"node": "transit-node", "maintenance": "transit-node", "delivery": "transit-delivery",
                      "board": "transit-board", **dict.fromkeys(workloads, "example-station-ledger"),
                      "station-observer": "transit-station-controller", "station-lifecycle": "transit-station-controller",
                      "controller": "transit-runtime-controller"}
    service_names = ("ursula", "node", "maintenance", "delivery", "board", *workloads,
                     "station-observer", "station-lifecycle")
    local_topology = ROOT / "examples/station-ledger/process-compose.yaml"
    compose_topology = ROOT / "examples/station-ledger/docker-compose.yaml"

    def records(self):
        return json.loads((self.path / "station.json").read_text())

    def provision(self):
        records = {}
        for role, principal in self.principals.items():
            pid = self.command("spawn-" + role, {'create': {"required": [b"data".hex(), None, None, None]}})
            resource = self.command("resource-" + role, {'create_resource': {"writer": pid}})
            self.command("operator-state-" + role, {'grant_resource': {"resource": resource, "subject": 0, "permissions": 7}})
            self.command("associate-" + role, {'associate': {"pid": pid, "name": b"data".hex(), "resource": resource}})
            records[role] = {"pid": pid, "resource": resource, "principal": principal}
        # The lifecycle identity is scoped to the ledger PID. Its separate read
        # grant can reach the supervisor's intent only through this association.
        self.command("associate-supervisor", {"associate": {
            "pid": records["ledger"]["pid"], "name": b"supervisor".hex(),
            "resource": records["coordinator"]["resource"], "required": False}})
        for role, peer in (("ledger", "requester"), ("requester", "ledger")):
            self.command("associate-query-" + role, {"associate": {
                "pid": records[role]["pid"], "name": b"query-peer".hex(),
                "resource": records[peer]["resource"], "required": False}})
        for role, record in records.items():
            # Named provisioning requests must retain identical bytes on restart.
            # Each association fences once: data, optional query peer/supervisor.
            generation = {"ledger": 3, "requester": 2, "coordinator": 1}[role]
            self.command("initialize-" + role, {'initialize': {"pid": record["pid"], "expected_generation": generation}})
        write(self.path / "station.json", records)
        write(self.path / "pid.json", records["ledger"]["pid"])
        for principal, label, permissions in ((2, "board", 16), (3, "maintenance", 161), (5, "delivery", 132),
                                              (10, "station-observer", 20), (11, "station-lifecycle", 17)):
            grant = {"subject": principal, "public_key": self.key(label + "/seed.key"), "permissions": permissions}
            if label == "station-lifecycle": grant["pid"] = records["ledger"]["pid"]
            self.command("grant-" + label, {"grant": grant})
        for role, record in records.items():
            self.command("board-state-" + role, {'grant_resource': {"resource": record["resource"], "subject": 2, "permissions": 3}})
            self.command("seed-" + role, {"send": {"pid": record["pid"], "value": frame(b"init")}})
        for role, principal in (("coordinator", 10), ("requester", 10), ("coordinator", 11)):
            self.command(f"observe-state-{role}-{principal}", {'grant_resource': {
                "resource": records[role]["resource"], "subject": principal, "permissions": 3}})
        for value in (b"prepare-table", b"allow-query", b"7", b"5"):
            self.command("seed-ledger-" + value.decode(), {"send": {"pid": records["ledger"]["pid"], "value": frame(value)}})
        self.command("registry-peer", {"send": {"pid": records["coordinator"]["pid"],
            "value": frame(f'lookup-peer:{records["requester"]["pid"]}'.encode())}})
        registration = b"RGQ1\x02" + struct.pack("<IQQB", 1, 0, records["ledger"]["pid"], 6) + b"ledger"
        self.command("registry-ledger", {"send": {"pid": records["coordinator"]["pid"], "value": frame(registration)}})
        self.controller_configs()
        self.configs()

    def controller_configs(self):
        records = self.records()
        for role, principal, mode in (("station-observer", 10, "observe"), ("station-lifecycle", 11, "lifecycle")):
            watches = [{"pid": records["coordinator"]["pid"], "resource": records["coordinator"]["resource"],
                        "child": records["ledger"]["pid"]}]
            if mode == "observe": watches.append({"pid": records["requester"]["pid"], "resource": records["requester"]["resource"]})
            write(self.path / role / "config.json", {"url": "http://node:8080" if self.profile == "compose" else self.url,
                "realm": self.load()["realm"], "principal": principal, "mode": mode, "watches": watches,
                "seed_file": f"/{role}/seed.key" if self.profile == "compose" else str(self.path / role / "seed.key")})

    def worker_config(self, role):
        records = self.records()
        return {"role": role, "association": "data", "observer": 10, "registry": records["coordinator"]["pid"],
                "destination": records["requester" if role == "ledger" else "ledger"]["pid"],
                "source_resource": records["ledger"]["resource"] if role == "requester" else None,
                "peer_resource": records["requester"]["resource"] if role == "ledger" else None}

    def process(self, role):
        return self.native_query({"process": self.records()[role]["pid"]})["body"]["process"]["process"]

    def activate(self, name=None):
        for role in self.workloads if name is None else (name,):
            if role not in self.workloads: raise ValueError("Unknown Station workload")
            with lock(self.path / "activation.lock"):
                process = self.process(role)
                if process["lifecycle"] != "running" or process["failure"] or process["binding"]:
                    raise RuntimeError(f"{role} is retired, blocked or provider-bound; no automatic replacement")
                record = self.records()[role]
                identity = secrets.token_hex(12)
                write(self.path / role / "seed.key", secrets.token_hex(32))
                self.command("worker-grant-" + identity, {"grant": {"subject": record["principal"],
                    "public_key": self.key(role + "/seed.key"), "permissions": 88, "pid": record["pid"]}})
                self.command("worker-state-" + identity, {'grant_resource': {"resource": record["resource"], "subject": record["principal"], "permissions": 7}})
                if role in ('ledger', 'requester'):
                    peer = self.records()['requester' if role == 'ledger' else 'ledger']
                    self.command('worker-query-read-' + identity, {'grant_resource': {
                        'resource': peer['resource'], 'subject': record['principal'], 'permissions': 3}})
                self.command("worker-own-" + identity, {"own": {"pid": record["pid"], "worker": record["principal"], "expected_generation": process["generation"]}})
                write(self.path / role / "config.json", {"url": "http://node:8080" if self.profile == "compose" else self.url,
                    "realm": self.load()["realm"], "principal": record["principal"], "pid": record["pid"], "generation": process["generation"] + 1,
                    "seed_file": f"/{role}/seed.key" if self.profile == "compose" else str(self.path / role / "seed.key"), **self.worker_config(role)})

    def validate_workload_update(self, name):
        process = self.process(name)
        if process["code"] != 1 or process["failure"] or process["lifecycle"] != "running" or process["binding"]:
            raise RuntimeError("Station native update requires compatible code=1 and a running, unbound PID")

    def send_value(self, value):
        data = value.encode()
        if len(data) > 243: raise ValueError("Station message exceeds its frame budget")
        return {"send": {"pid": self.records()["requester"]["pid"], "value": frame(data)}}

    def endpoints(self):
        result = {**super().endpoints(), "example": "station"}
        if (self.path / "station.json").exists():
            result["processes"] = self.records()
        return result
