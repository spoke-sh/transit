"""Three Station Actors, with scoped in-cluster runtime/framework controllers."""
import copy
import json
import os
import shutil
import sys
import time
import uuid

from common import ROOT, run, wait_for, write
from kubernetes import Reference, infrastructure


class StationReference(Reference):
    controllers = {"ledger": 4, "requester": 8, "coordinator": 9}

    def services(self):
        rows = super().services()
        for row in rows:
            if row["name"] in ("controller", "station"):
                row["name"] = row["resource"]
        return rows

    def secret(self, name, path):
        self.kube("apply", "-f", "-", input=json.dumps({"apiVersion": "v1", "kind": "Secret",
            "metadata": {"name": name}, "stringData": {"seed": path.read_text().strip()}}))

    def controller(self, values, role):
        return next(item for item in values["runtimeControllers"] if item["nameOverride"] == "runtime-" + role)

    def service_values(self, values, selection, images):
        super().service_values(values, selection, images)
        for settings in values.get("runtimeControllers", []):
            settings["image"] = images["transit-runtime-controller"]
            settings["config"]["provider"]["cli"] = selection["transit-runtime-controller"]["provider_cli"]
        for settings in values.get("stationControllers", []):
            settings["image"] = images["transit-station-controller"]
            role = settings["nameOverride"]
            env = self.installation.service_environment(role)
            settings["logging"] = {"level": env["LOG_LEVEL"], "format": env["LOG_FORMAT"]}

    def up(self, detached=True):
        if sys.platform != "linux" or os.uname().machine != "x86_64":
            raise RuntimeError("The reference runtime requires Linux x86_64")
        self.prepare_infrastructure()
        if (self.path / "ready.json").exists() and self.services():
            raise RuntimeError("Reference application is running; use update, restart or down")
        i = self.installation
        i.artifacts.initialize()
        previous = i.load().get("observability", {})
        if not (self.path / "pc.sock").exists():
            i.configure_board()
            if (self.path / "chart-values.json").exists() and self.values().get("runtimeControllers"):
                configured = i.load()
                for role in i.workloads:
                    if role in previous: configured["observability"][role] = previous[role]
                write(i.manifest, configured)
        i.configs()
        selection = i.artifacts.read("selected")
        images = self.images(selection)
        values = self.values() if (self.path / "chart-values.json").exists() else {
            "running": True, "node": {"enabled": False, "nameOverride": "transit"},
            "initialize": {"enabled": False, "nameOverride": "initialize"},
            "ursula": {"nameOverride": "ursula", "image": infrastructure.PINS["ursula"]},
            "board": {"enabled": False, "nameOverride": "board", "existingSecret": "board-credentials"},
            "maintenance": {"enabled": False, "nameOverride": "maintenance", "existingSecret": "maintenance-credentials"},
            "controller": {"enabled": False}, "runtimeControllers": [], "stationControllers": []}
        self.service_values(values, selection, images)
        values["running"] = True
        for pool in values.get("workerPools", []): pool["spec"]["replicas"] = 1
        if not (self.path / "initialized.json").exists():
            self.deploy(values)
            values["initialize"]["enabled"] = True
            self.deploy(values)
            write(self.path / "initialized.json", True)
        values["initialize"]["enabled"] = False
        values["node"]["enabled"] = True
        self.deploy(values)
        self.forwards()
        wait_for(i.url + "/health")
        i.provision()
        self.credentials(("board", "maintenance", "delivery"))
        for role, record in i.records().items():
            i.command("provider-worker-" + role, {"grant": {"subject": record["principal"],
                "public_key": i.key(role + "/initial.key"), "permissions": 88, "pid": record["pid"]}})
            i.command("provider-state-" + role, {'grant_resource': {"resource": record["resource"],
                "subject": record["principal"], "permissions": 7}})
            if role in ('ledger', 'requester'):
                peer = i.records()['requester' if role == 'ledger' else 'ledger']
                i.command('provider-query-read-' + role, {'grant_resource': {
                    'resource': peer['resource'], 'subject': record['principal'], 'permissions': 3}})
            controller_role = "runtime-" + role
            i.command("grant-" + controller_role, {"grant": {"subject": self.controllers[role],
                "public_key": i.key(controller_role + "/seed.key"), "permissions": 17, "pid": record["pid"]}})
            self.secret(controller_role + "-credentials", self.path / controller_role / "seed.key")
        if not values["runtimeControllers"]:
            pools = []
            for role, record in i.records().items():
                provider, pool = self.workload(images["example-station-ledger"], role=role)
                provider["cli"] = selection["transit-runtime-controller"]["provider_cli"]
                pools.append(pool)
                values["runtimeControllers"].append({"nameOverride": "runtime-" + role,
                    "existingSecret": "runtime-" + role + "-credentials",
                    "config": {"realm": i.load()["realm"], "principal": self.controllers[role], "pid": record["pid"],
                               "worker": record["principal"], "provider": provider}})
            values["workerPools"] = pools
        values["stationControllers"] = []
        for role in ("station-observer", "station-lifecycle"):
            self.secret(role + "-credentials", self.path / role / "seed.key")
            config = json.loads((self.path / role / "config.json").read_text())
            values["stationControllers"].append({"nameOverride": role, "existingSecret": role + "-credentials", "config": config})
        for role in ("board", "maintenance", "delivery"): values[role]["enabled"] = True
        self.service_values(values, selection, images)
        self.deploy(values)
        for role in i.workloads:
            process = i.process(role)
            if process["binding"] and process["binding"]["desired"] == "stopped" and not (self.path / "update.json").exists():
                self.intent_for(role, False, "up")
            self.await_role(role, lambda p: p["binding"] and p["binding"]["activation"] is not None, "fresh activation")
        wait_for(i.board_url + "/health", headers=i.board_headers)
        write(self.path / "ready.json", True)

    def await_role(self, role, predicate, description, seconds=240):
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            process = self.installation.process(role)
            if predicate(process): return process
            time.sleep(.5)
        raise RuntimeError(f"Timed out awaiting {role} {description}; inspect runtime-{role} logs")

    def intent_for(self, role, stopped, reason):
        process = self.await_role(role, lambda p: p["binding"] is None or p["binding"]["phase"] not in ("pending", "unknown"), "provider observation")
        binding = process["binding"]
        desired = "stopped" if stopped else "running"
        if binding is None or binding["desired"] == desired: return
        self.installation.command(f'{reason}-{role}-{desired}-{binding["revision"]}', {"runtime_intent": {
            "pid": process["pid"], "expected_revision": binding["revision"], "instance": binding["instance"],
            "resource": binding["resource"], "workload": binding["workload"], "desired": desired}})

    def stop_role(self, role, reason):
        self.intent_for(role, True, reason)
        return self.await_role(role, lambda p: p["binding"] is None or p["binding"]["phase"] == "stopped", "stopped provider")

    def down(self):
        if not (self.path / "reference.json").exists(): return
        if not (self.path / "chart-values.json").exists():
            self.forwarder.down()
            return
        values = self.values()
        stopped_path = self.path / "stopped-station.json"
        if values.get("running", True):
            if (self.path / "station.json").exists():
                self.forwards()
                wait_for(self.installation.url + "/health")
                stopped = {role: self.stop_role(role, "down") for role in self.installation.workloads}
                write(stopped_path, stopped)
            values["running"] = False
            for pool in values.get("workerPools", []): pool["spec"]["replicas"] = 0
            self.deploy(values)
        if stopped_path.exists():
            for process in json.loads(stopped_path.read_text()).values():
                if process["binding"]: self.await_worker_release(process["binding"]["last_worker_incarnation"])
        self.forwarder.down()
        (self.path / "ready.json").unlink(missing_ok=True)

    def restart(self, name):
        if name in self.installation.workloads:
            old = self.stop_role(name, "restart")
            values = self.values()
            template = self.controller(values, name)["config"]["provider"]["template"]
            pool = next(pool for pool in values["workerPools"] if pool["name"] == template)
            pool["spec"]["replicas"] = 0
            self.deploy(values)
            self.await_worker_release(old["binding"]["last_worker_incarnation"])
            pool["spec"]["replicas"] = 1
            self.deploy(values)
            self.intent_for(name, False, "restart")
            self.await_role(name, lambda p: p["binding"]["activation"] is not None, "replacement activation")
        elif name in ("station-observer", "station-lifecycle") or name in ["runtime-" + role for role in self.installation.workloads]:
            self.kube("rollout", "restart", "deployment/" + name)
            self.kube("rollout", "status", "deployment/" + name, "--timeout=120s")
        else: super().restart(name)

    def logs(self, name):
        if name in self.installation.workloads:
            provider = self.controller(self.values(), name)["config"]["provider"]
            infrastructure.ate(self.state, ["logs", "actor", provider["actor"], "-a", self.namespace, "-c", "station"])
        elif name in ("station-observer", "station-lifecycle") or name in ["runtime-" + role for role in self.installation.workloads]:
            self.kube("logs", "--tail=200", "deployment/" + name)
        else: super().logs(name)

    def validate_update(self, operation):
        self.ownership()
        operation["workloads"] = {}
        for role in self.installation.workloads:
            if role not in operation["services"]: continue
            process = self.installation.process(role)
            if process["code"] != 1 or process["failure"] or process["lifecycle"] != "running":
                raise RuntimeError("Station upgrades require compatible code=1 and an unblocked running process")
            operation["workloads"][role] = {"old": copy.deepcopy(self.controller(self.values(), role)["config"]["provider"])}

    def apply_update(self, operation):
        from updates import publish, completed
        images = self.images(operation["selection"])
        values = self.values()
        for role, change in operation["workloads"].items():
            if "provider" not in change:
                provider, pool = self.workload(images["example-station-ledger"], operation["configuration"], role)
                provider["previous_workload"] = {key: change["old"][key] for key in ("template", "template_uid", "image")}
                provider["cli"] = operation["selection"]["transit-runtime-controller"]["provider_cli"]
                change.update(provider=provider, pool=pool)
                write(self.path / "update.json", operation)
            if "command" not in change:
                stopped = self.stop_role(role, operation["id"])
                change["command"] = {"runtime_upgrade": {"pid": stopped["pid"], "expected_revision": stopped["binding"]["revision"],
                    "expected_workload": stopped["binding"]["workload"], "workload": self.workload_hash(change["provider"]),
                    "expected_code": 1, "expected_state_revision": stopped["revision"]}}
                write(self.path / "update.json", operation)
            self.installation.command("upgrade-" + role + "-" + operation["id"], change["command"])
            self.controller(values, role)["config"]["provider"] = change["provider"]
            pools = {pool["name"]: pool for pool in values["workerPools"]}
            pools[change["pool"]["name"]] = change["pool"]
            values["workerPools"] = list(pools.values())
        publish(self, operation)
        self.service_values(values, operation["selection"], images)
        self.deploy(values)
        for role, change in operation["workloads"].items():
            target = self.workload_hash(change["provider"])
            self.await_role(role, lambda p: p["binding"]["workload"] == target and not p["binding"].get("upgrade_from"), "template switch")
            self.intent_for(role, False, operation["id"])
            self.await_role(role, lambda p: p["binding"]["workload"] == target and p["binding"]["activation"] is not None, "upgraded activation")
            values["workerPools"] = [pool for pool in values["workerPools"] if pool["name"] != change["old"]["template"]]
        self.deploy(values)
        if "board" in operation["services"]:
            self.forwarder.down()
            self.forwards()
        wait_for(self.installation.url + "/health")
        wait_for(self.installation.board_url + "/health", headers=self.installation.board_headers)
        for role in operation["services"]: completed(self, operation, role)

    def reset(self):
        if self.services(): raise RuntimeError("Run reference down before reset")
        self.ownership()
        space_path = self.path / "atespace.json"
        if space_path.exists():
            expected = json.loads(space_path.read_text())
            space = self.provider("get", "atespace", self.namespace, missing=True)
            if space:
                if space["metadata"]["uid"] != expected["uid"]: raise RuntimeError("Atespace incarnation changed")
                stopped = json.loads((self.path / "stopped-station.json").read_text())
                for role in self.installation.workloads:
                    name = self.controller(self.values(), role)["config"]["provider"]["actor"]
                    actor = self.provider("get", "actor", name, "-a", self.namespace, missing=True)
                    if actor:
                        binding = stopped[role]["binding"]
                        if binding is None or list(uuid.UUID(actor["metadata"]["uid"]).bytes) != binding["incarnation"] or actor["status"]["state"] != "ACTOR_STATE_SUSPENDED":
                            raise RuntimeError("Actor is not the stopped owned incarnation")
                        self.provider("delete", "actor", name, "-a", self.namespace)
                for path in sorted((self.path / "templates").glob("*.observed.json")):
                    expected = json.loads(path.read_text())
                    template = self.provider("get", "actor-template", expected["name"], "-a", self.namespace, missing=True)
                    if template:
                        if template["metadata"]["uid"] != expected["uid"]: raise RuntimeError("Template incarnation changed")
                        self.provider("delete", "actor-template", expected["name"], "-a", self.namespace)
                self.provider("delete", "atespace", self.namespace)
        run(["helm", "--kubeconfig", infrastructure.CACHE / "kubeconfig", "--kube-context", "kind-" + self.state["cluster"],
             "uninstall", "transit", "--namespace", self.namespace, "--ignore-not-found"], timeout=180)
        self.kube("delete", "namespace", self.namespace, "--wait=true", "--timeout=120s")
        shutil.rmtree(self.path)
