"""Persistent Transit application on the separately owned reference cluster."""
import copy
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import time
import uuid

from artifacts import ROLES
from common import ROOT, Installation, run, wait_for, write
from local import Local

sys.path.insert(0, str(ROOT / "tests"))
import reference as infrastructure


class ReferenceInstallation(Installation):
    def __init__(self, name, base_port=None, board_settings=None):
        super().__init__("reference", name, base_port, board_settings)

    def prepare(self):
        if not self.manifest.exists() and self.base_port is None:
            self.base_port = 18300
        super().prepare()


class Reference:
    def __init__(self, installation):
        self.installation, self.path = installation, installation.path
        self.forwarder = Local(installation)

    @property
    def state(self):
        state = infrastructure.state()
        current = infrastructure.run(["docker", "ps", "-aq", "--no-trunc", "--filter", "label=io.x-k8s.kind.cluster=" + state["cluster"]], capture=True).split()
        if not state["node_ids"] or set(current) != set(state["node_ids"]):
            raise RuntimeError("Reference cluster identity changed or incomplete; refusing to adopt it")
        registry = infrastructure.run(["docker", "inspect", state["registry"], "--format", "{{.Id}}"], capture=True)
        if registry != state.get("registry_id"):
            raise RuntimeError("Reference registry incarnation changed")
        return state

    @property
    def namespace(self):
        return "transit-" + self.installation.name + "-" + self.installation.load()["project"][-6:]

    def kube(self, *args, **kwargs):
        return infrastructure.kube(self.state, ["-n", self.namespace, *args], **kwargs)

    def provider(self, *args, missing=False):
        command = [infrastructure.ate_binary(), "--kubeconfig", infrastructure.CACHE / "kubeconfig", "--context", "kind-" + self.state["cluster"], "-o", "json", *args]
        result = subprocess.run(list(map(str, command)), capture_output=True, text=True, timeout=60)
        if result.returncode:
            if missing and "code = NotFound" in result.stderr:
                return None
            raise RuntimeError("Substrate operation failed: " + result.stderr[-1500:])
        return json.loads(result.stdout) if result.stdout.strip() and args[0] != "delete" else None

    def ownership(self, create=False):
        result = json.loads(self.kube("get", "namespace", self.namespace, "--ignore-not-found", "-o", "json", capture=True) or "null")
        identity = self.path / "reference.json"
        if result is None:
            if not create or identity.exists():
                raise RuntimeError("Owned namespace disappeared; refusing to recreate its history")
            result = json.loads(self.kube("create", "-f", "-", "-o", "json", input=json.dumps({
                "apiVersion": "v1", "kind": "Namespace", "metadata": {"name": self.namespace,
                "labels": {"transit.dev/installation": self.installation.load()["project"]}}}), capture=True))
        if result["metadata"].get("labels", {}).get("transit.dev/installation") != self.installation.load()["project"]:
            raise RuntimeError("Namespace belongs to another installation")
        current = {"namespace": self.namespace, "uid": result["metadata"]["uid"], "cluster": self.state["cluster"]}
        if identity.exists() and json.loads(identity.read_text()) != current:
            raise RuntimeError("Reference namespace incarnation changed")
        write(identity, current)
        return current

    def services(self):
        if not (self.path / "reference.json").exists():
            return []
        self.ownership()
        value = json.loads(self.kube("get", "deployments", "-l", "app.kubernetes.io/instance=transit", "-o", "json", capture=True))
        return [{"name": d["metadata"]["labels"]["app.kubernetes.io/component"], "uid": d["metadata"]["uid"],
                 "resource": d["metadata"]["name"],
                 "replicas": d["spec"].get("replicas", 1), "ready": d.get("status", {}).get("readyReplicas", 0),
                 "image": d["spec"]["template"]["spec"]["containers"][0]["image"]}
                for d in value["items"] if d["spec"].get("replicas", 1)]

    def values(self):
        return json.loads((self.path / "chart-values.json").read_text())

    def deploy(self, values):
        self.ownership()
        write(self.path / "chart-values.json", values)
        run(["helm", "--kubeconfig", infrastructure.CACHE / "kubeconfig", "--kube-context", "kind-" + self.state["cluster"],
             "upgrade", "--install", "transit", ROOT / "charts/transit", "--namespace", self.namespace,
             "--values", self.path / "chart-values.json", "--wait", "--wait-for-jobs", "--timeout", "240s", "--history-max", "5"], timeout=300)

    def images(self, selection):
        file = self.path / "registry.json"
        saved = json.loads(file.read_text()) if file.exists() else {}
        host = f'localhost:{self.state["port"]}'
        result = {}
        for name in set(self.installation.artifacts.mapping.values()):
            if name not in selection:
                continue
            artifact = selection[name]
            identity = artifact["image"]
            key = host + "/" + identity
            if key not in saved:
                tag = f"{host}/{name}:{identity.removeprefix('sha256:')}"
                run(["docker", "tag", identity, tag])
                run(["docker", "push", tag], timeout=300)
                digests = json.loads(run(["docker", "inspect", tag, "--format", "{{json .RepoDigests}}"], capture=True))
                saved[key] = next(d for d in digests if d.startswith(f"{host}/{name}@sha256:"))
                write(file, saved)
            result[name] = saved[key]
        return result

    def runtime_image(self):
        file = infrastructure.CACHE / "runtime-image.json"
        host = f'localhost:{self.state["port"]}'
        if file.exists():
            saved = json.loads(file.read_text())
            if saved["registry"] == self.state["registry_id"] and saved["revision"] == infrastructure.PINS["substrate"]:
                return saved["image"]
        infrastructure.source()
        image = infrastructure.go(["hack/run-tool.sh", "ko", "build", "--bare", "./cmd/ateom-gvisor"],
                                  {"KO_DOCKER_REPO": host + "/ateom", "KO_DEFAULTPLATFORMS": "linux/amd64"}, capture=True)
        write(file, {"registry": self.state["registry_id"], "revision": infrastructure.PINS["substrate"], "image": image})
        return image

    def forwards(self):
        if (self.path / "pc.sock").exists():
            return
        argv = [shutil.which("kubectl"), "--kubeconfig", str(infrastructure.CACHE / "kubeconfig"), "--context", "kind-" + self.state["cluster"], "-n", self.namespace]
        values = {"disable_env_expansion": True, "vars": {"KUBECTL": shlex.join(argv),
                  "TRANSIT_PORT": self.installation.load()["base_port"] + 1,
                  "BOARD_HOST": self.installation.board["host"], "BOARD_PORT": self.installation.board["port"]}}
        write(self.path / "process-compose.vars.json", values)
        self.forwarder.pc("up", "-f", ROOT / "deploy/reference/process-compose.yaml", "-f", self.path / "process-compose.vars.json", "--disable-dotenv", "-D", manager=True, capture=True)

    def credentials(self, roles=None):
        for role, data in (("board", {"seed": "board/seed.key"}),
                           ("maintenance", {"seed": "maintenance/seed.key"}), ("delivery", {"seed": "delivery/seed.key"}), ("controller", {"seed": "controller/seed.key"})):
            if roles is not None and role not in roles:
                continue
            # Structured stdin prevents credentials entering argv or Helm history.
            self.kube("apply", "-f", "-", input=json.dumps({"apiVersion": "v1", "kind": "Secret", "metadata": {"name": role + "-credentials"},
                "stringData": {key: (self.path / relative).read_text().strip() for key, relative in data.items()}}))
            if role == "board":
                # stringData is write-only: omitting a former field from apply
                # does not remove its stored data entry. Delete that entry only.
                self.kube("patch", "secret", "board-credentials", "--type=merge",
                          "--patch", json.dumps({"data": {"access": None}}))

    def workload(self, image, configuration=None, role="counter"):
        i = self.installation
        identity = {"pid": json.loads((self.path / "pid.json").read_text()), "principal": 1} if role == "counter" else i.records()[role]
        pid = identity["pid"]
        config = i.counter_config() if role == "counter" else i.worker_config(role)
        container = "counter" if role == "counter" else "station"
        executable = i.artifacts.mapping[role]
        logging = (configuration or i.load()).get("observability", {}).get(role, {"level": "info", "format": "json"})
        version_basis = {"image": image, "logging": logging}
        if role != "counter": version_basis.update(role=role, pid=pid, config=config)
        version = hashlib.sha256(json.dumps(version_basis, sort_keys=True).encode()).hexdigest()[:16]
        name = role + "-" + version
        host = f"transit.{self.namespace}.svc.cluster.local"
        space = self.provider("get", "atespace", self.namespace, missing=True)
        if space is None:
            space = self.provider("create", "atespace", self.namespace)
        space_file = self.path / "atespace.json"
        space_identity = {"name": self.namespace, "uid": space["metadata"]["uid"]}
        if space_file.exists() and json.loads(space_file.read_text()) != space_identity:
            raise RuntimeError("Substrate atespace incarnation changed")
        write(space_file, space_identity)
        template = {"metadata": {"atespace": self.namespace, "name": name}, "workerSelector": {"matchLabels": {"transit.dev/workload": name}},
            "containers": [{"name": container, "image": image, "env": [{"name": "LOG_FORMAT", "value": logging["format"]}, {"name": "LOG_LEVEL", "value": logging["level"]}],
                "command": ["/bin/" + executable, "--bootstrap-json", json.dumps({"url": "http://" + host + ":8080", "realm": i.load()["realm"], "principal": identity["principal"], "pid": pid, **config})],
                "volumeMounts": [{"name": "runtime-data", "mountPath": "/runtime-data"}]}],
            "volumes": [{"name": "runtime-data", "durableDir": {}}],
            "resources": {"limits": [{"name": "cpu", "quantity": "1"}, {"name": "memory", "quantity": "512Mi"}]},
            "snapshotsConfig": {"storageLocation": f"gs://ate-snapshots/{self.namespace}/", "onPause": "SNAPSHOT_CONTENT_SCOPE_DATA", "onCommit": "SNAPSHOT_CONTENT_SCOPE_DATA", "onResume": {"fromData": "RESUME_SOURCE_COLD_BOOT"}},
            "sandboxConfig": {"sandboxClass": "SANDBOX_CLASS_GVISOR", "configName": "gvisor-default"}}
        current = self.provider("get", "actor-template", name, "-a", self.namespace, missing=True)
        if current is None:
            file = self.path / "templates" / (name + ".json")
            write(file, template)
            current = self.provider("create", "actor-template", "-f", str(file))
        if current["containers"][0]["image"] != image or current["containers"][0]["command"] != template["containers"][0]["command"] or current["containers"][0]["env"] != template["containers"][0]["env"] or current["workerSelector"] != template["workerSelector"]:
            raise RuntimeError("Workload template identity/configuration mismatch")
        write(self.path / "templates" / (name + ".observed.json"), {"name": name, "uid": current["metadata"]["uid"]})
        provider = {"instance": list(uuid.UUID(self.ownership()["uid"]).bytes), "atespace": self.namespace, "actor": f"process-{pid}",
                    "template": name, "template_uid": list(uuid.UUID(current["metadata"]["uid"]).bytes), "image": image, "authority_host": host}
        if role != "counter": provider["container"] = container
        pool = {"name": name, "labels": {"transit.dev/workload": name}, "spec": {"replicas": 1, "workerImage": self.runtime_image(),
                "template": {"nodeSelector": {"ate.dev/substrate-version": infrastructure.PINS["substrate"][:7]},
                "resources": {"requests": {"cpu": "100m", "memory": "512Mi"}, "limits": {"cpu": "1", "memory": "1Gi"}}}}}
        return provider, pool

    @staticmethod
    def workload_hash(provider):
        return list(hashlib.sha256(b"rey.substrate.workload.v1\0" + bytes(provider["template_uid"]) + provider["image"].encode()).digest())

    def service_values(self, values, selection, images):
        i = self.installation
        values["node"].update(image=images["transit-node"], config=json.loads((self.path / "node.json").read_text()))
        values["board"].update(image=images["transit-board"], config=json.loads((self.path / "board/config.json").read_text()))
        values.setdefault("delivery", {"enabled": False, "nameOverride": "delivery", "existingSecret": "delivery-credentials"})
        values["delivery"].update(image=images["transit-delivery"], config={"realm": i.load()["realm"], "principal": 5})
        values["controller"].update(image=images["transit-runtime-controller"])
        if "provider" in values["controller"].get("config", {}):
            values["controller"]["config"]["provider"]["cli"] = selection["transit-runtime-controller"]["provider_cli"]
        for role in ("node", "board", "maintenance", "controller", "delivery"):
            env = i.service_environment(role)
            values[role]["logging"] = {"level": env["LOG_LEVEL"], "format": env["LOG_FORMAT"]}

    def up(self, detached=True):
        if sys.platform != "linux" or os.uname().machine != "x86_64":
            raise RuntimeError("The pinned reference runtime currently requires Linux x86_64")
        if not infrastructure.STATE.exists():
            infrastructure.up()
        self.ownership(create=True)
        if (self.path / "ready.json").exists() and self.services():
            raise RuntimeError("Reference application is running; use update, restart or down")
        self.installation.artifacts.initialize()
        previous = self.installation.load().get("observability", {}).get("counter")
        if not (self.path / "pc.sock").exists():
            self.installation.configure_board()
            # Counter logging is embedded in its immutable provider template.
            # Starting a saved binding cannot silently assign a new template.
            if previous and (self.path / "chart-values.json").exists() and self.values()["controller"].get("config"):
                configured = self.installation.load()
                if configured["observability"]["counter"] != previous:
                    configured["observability"]["counter"] = previous
                    write(self.installation.manifest, configured)
                    print("Counter template settings retained; use update counter to apply changed logging.", flush=True)
        self.installation.configs()
        selection = self.installation.artifacts.read("selected")
        images = self.images(selection)
        if (self.path / "chart-values.json").exists():
            values = self.values()
        else:
            values = {"running": True,
                "node": {"enabled": False, "nameOverride": "transit"}, "initialize": {"enabled": False, "nameOverride": "initialize"},
                "ursula": {"nameOverride": "ursula", "image": infrastructure.PINS["ursula"]},
                "board": {"enabled": False, "nameOverride": "board", "existingSecret": "board-credentials"},
                "maintenance": {"enabled": False, "nameOverride": "maintenance", "existingSecret": "maintenance-credentials"},
                "controller": {"enabled": False, "nameOverride": "controller", "existingSecret": "controller-credentials"}}
        self.service_values(values, selection, images)
        values["running"] = True
        for pool in values.get("workerPools", []):
            pool["spec"]["replicas"] = 1
        if not (self.path / "initialized.json").exists():
            # Storage must be ready before the one-shot bootstrap Job starts.
            # Retrying an incomplete bootstrap reuses the exact realm/genesis.
            values["initialize"]["enabled"] = False
            self.deploy(values)
            values["initialize"]["enabled"] = True
            self.deploy(values)
            write(self.path / "initialized.json", True)
        values["initialize"]["enabled"] = False
        values["node"]["enabled"] = True
        self.deploy(values)
        self.forwards()
        wait_for(self.installation.url + "/health")
        self.installation.provision()
        pid = json.loads((self.path / "pid.json").read_text())
        self.installation.command("grant-worker", {"grant": {"subject": 1, "public_key": self.installation.key("counter/initial.key"), "permissions": 24, "pid": pid}})
        self.installation.grant_counter_state("initial")
        self.installation.command("grant-controller", {"grant": {"subject": 4, "public_key": self.installation.key("controller/seed.key"), "permissions": 17, "pid": pid}})
        self.credentials()
        if not values["controller"].get("config"):
            provider, pool = self.workload(images["example-counter"])
            provider["cli"] = selection["transit-runtime-controller"]["provider_cli"]
            values["controller"]["config"] = {"realm": self.installation.load()["realm"], "principal": 4, "pid": pid, "worker": 1, "provider": provider}
            values["workerPools"] = [pool]
        self.service_values(values, selection, images)
        for role in ("board", "maintenance", "controller", "delivery"):
            values[role]["enabled"] = True
        self.deploy(values)
        process = self.installation.view()
        if process["binding"] and process["binding"]["desired"] == "stopped" and not (self.path / "update.json").exists():
            self.intent(False, "up")
        self.await_process(lambda p: p["binding"] and p["binding"]["activation"] is not None, "fresh worker activation")
        wait_for(self.installation.board_url + "/health", headers=self.installation.board_headers)
        write(self.path / "ready.json", True)

    def await_process(self, predicate, description, seconds=240):
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            try:
                process = self.installation.view()
                if predicate(process):
                    return process
            except subprocess.SubprocessError:
                pass
            time.sleep(.5)
        raise RuntimeError("Timed out awaiting " + description + "; inspect controller logs and pending update")

    def intent(self, stopped, reason):
        process = self.installation.view()
        b = process["binding"]
        if not b:
            return
        desired = "stopped" if stopped else "running"
        if b["phase"] in ("pending", "unknown"):
            self.await_process(lambda p: p["binding"]["phase"] not in ("pending", "unknown"), "outstanding provider operation")
            return self.intent(stopped, reason)
        if b["desired"] == desired:
            return
        self.installation.command(f'{reason}-{desired}-{b["revision"]}', {"runtime_intent": {"pid": process["pid"], "expected_revision": b["revision"],
            "instance": b["instance"], "resource": b["resource"], "workload": b["workload"], "desired": desired}})

    def stop_workload(self, reason):
        self.intent(True, reason)
        return self.await_process(lambda p: p["binding"] is None or p["binding"]["phase"] == "stopped", "stopped workload")

    def await_worker_release(self, uid):
        deadline = time.monotonic() + 90
        while uid and any(list(uuid.UUID(p["metadata"]["uid"]).bytes) == uid for p in json.loads(self.kube("get", "pods", "-o", "json", capture=True))["items"]):
            if time.monotonic() > deadline:
                raise RuntimeError("Previous worker pod did not stop")
            time.sleep(.5)

    def down(self):
        if not (self.path / "reference.json").exists():
            return
        if not (self.path / "chart-values.json").exists():
            self.forwarder.down()
            return
        values = self.values()
        if values.get("running", True):
            if (self.path / "pid.json").exists():
                self.forwards()
                wait_for(self.installation.url + "/health")
                write(self.path / "stopped.json", self.stop_workload("down"))
            values["running"] = False
            for pool in values.get("workerPools", []):
                pool["spec"]["replicas"] = 0
            self.deploy(values)
        if (self.path / "stopped.json").exists():
            binding = json.loads((self.path / "stopped.json").read_text())["binding"]
            self.await_worker_release(binding["last_worker_incarnation"] if binding else None)
        self.forwarder.down()
        (self.path / "ready.json").unlink(missing_ok=True)

    def validate_update(self, operation):
        self.ownership()
        if "counter" in operation["services"]:
            self.installation.validate_counter_update()
            operation["old_provider"] = copy.deepcopy(self.values()["controller"]["config"]["provider"])

    def apply_update(self, operation):
        from updates import publish, completed
        images = self.images(operation["selection"])
        values = self.values()
        add_delivery = not values.get("delivery", {}).get("enabled", False)
        if "counter" in operation["services"]:
            if "new_provider" not in operation:
                target, pool = self.workload(images["example-counter"], operation["configuration"])
                old = operation["old_provider"]
                target["previous_workload"] = {key: old[key] for key in ("template", "template_uid", "image")}
                target["cli"] = operation["selection"]["transit-runtime-controller"]["provider_cli"]
                operation.update(new_provider=target, new_pool=pool)
                write(self.path / "update.json", operation)
            if "upgrade_command" not in operation:
                stopped = self.stop_workload(operation["id"])
                operation["upgrade_command"] = {"runtime_upgrade": {"pid": stopped["pid"], "expected_revision": stopped["binding"]["revision"],
                    "expected_workload": stopped["binding"]["workload"], "workload": self.workload_hash(operation["new_provider"]),
                    "expected_code": 1, "expected_state_revision": stopped["revision"]}}
                write(self.path / "update.json", operation)
            # Saved exact request makes a lost authority response retryable.
            self.installation.command("upgrade-" + operation["id"], operation["upgrade_command"])
            values["controller"]["config"]["provider"] = operation["new_provider"]
            pools = {p["name"]: p for p in values.get("workerPools", [])}
            pools[operation["new_pool"]["name"]] = operation["new_pool"]
            values["workerPools"] = list(pools.values())
        publish(self, operation)
        self.service_values(values, operation["selection"], images)
        self.deploy(values)
        if add_delivery:
            # The old authority cannot accept the new permission bit. Upgrade
            # it first, then record the courier grant before enabling the pod.
            wait_for(self.installation.url + "/health")
            self.installation.provision()
            self.credentials(("delivery",))
            values["delivery"]["enabled"] = True
            self.deploy(values)
        if "counter" in operation["services"]:
            target_hash = self.workload_hash(operation["new_provider"])
            self.await_process(lambda p: p["binding"]["workload"] == target_hash and not p["binding"].get("upgrade_from"), "template switch readback")
            self.intent(False, operation["id"])
            self.await_process(lambda p: p["binding"]["workload"] == target_hash and p["binding"]["activation"] is not None, "upgraded activation")
            values["workerPools"] = [operation["new_pool"]]
            self.deploy(values)
        if "board" in operation["services"]:
            # Reapply the seed-only Secret after the new Board is ready, so an
            # earlier access-key field is removed without interrupting old pods.
            self.credentials(("board",))
            self.forwarder.down()
            self.forwards()
        wait_for(self.installation.url + "/health")
        wait_for(self.installation.board_url + "/health", headers=self.installation.board_headers)
        for role in operation["services"]:
            completed(self, operation, role)

    def restart(self, name):
        if name == "counter":
            old = self.stop_workload("restart")
            uid = old["binding"]["last_worker_incarnation"]
            values = self.values()
            for pool in values["workerPools"]:
                pool["spec"]["replicas"] = 0
            self.deploy(values)
            self.await_worker_release(uid)
            for pool in values["workerPools"]:
                pool["spec"]["replicas"] = 1
            self.deploy(values)
            self.intent(False, "restart")
            self.await_process(lambda p: p["binding"]["activation"] is not None, "fresh activation")
        else:
            component = {"node": "transit", "board": "board", "controller": "controller", "maintenance": "maintenance", "delivery": "delivery", "ursula": "ursula"}.get(name)
            if component is None:
                raise ValueError("Unknown reference service")
            self.kube("rollout", "restart", "deployment/" + component)
            self.kube("rollout", "status", "deployment/" + component, "--timeout=120s")

    def logs(self, name):
        if name == "counter":
            infrastructure.ate(self.state, ["logs", "actor", self.values()["controller"]["config"]["provider"]["actor"], "-a", self.namespace, "-c", "counter"])
            return
        name = "transit" if name == "node" else name
        if name not in ("transit", "board", "controller", "maintenance", "delivery", "ursula"):
            raise ValueError("Unknown service")
        self.kube("logs", "--tail=200", "deployment/" + name)

    def attach(self):
        self.forwarder.attach()

    def reset(self):
        if self.services():
            raise RuntimeError("Run reference down before reset")
        self.ownership()
        if (self.path / "atespace.json").exists():
            expected = json.loads((self.path / "atespace.json").read_text())
            space = self.provider("get", "atespace", self.namespace, missing=True)
            if space:
                if space["metadata"]["uid"] != expected["uid"]:
                    raise RuntimeError("Substrate atespace incarnation changed")
                provider = self.values()["controller"]["config"]["provider"]
                actor = self.provider("get", "actor", provider["actor"], "-a", self.namespace, missing=True)
                if actor:
                    stopped = json.loads((self.path / "stopped.json").read_text())
                    if list(uuid.UUID(actor["metadata"]["uid"]).bytes) != stopped["binding"]["incarnation"] or actor["status"]["state"] != "ACTOR_STATE_SUSPENDED":
                        raise RuntimeError("Actor is not the stopped owned incarnation")
                    self.provider("delete", "actor", provider["actor"], "-a", self.namespace)
                for file in sorted((self.path / "templates").glob("*.observed.json")):
                    expected_template = json.loads(file.read_text())
                    template = self.provider("get", "actor-template", expected_template["name"], "-a", self.namespace, missing=True)
                    if template:
                        if template["metadata"]["uid"] != expected_template["uid"]:
                            raise RuntimeError("Substrate template incarnation changed")
                        self.provider("delete", "actor-template", expected_template["name"], "-a", self.namespace)
                self.provider("delete", "atespace", self.namespace)
        run(["helm", "--kubeconfig", infrastructure.CACHE / "kubeconfig", "--kube-context", "kind-" + self.state["cluster"],
             "uninstall", "transit", "--namespace", self.namespace, "--ignore-not-found"], timeout=180)
        self.kube("delete", "namespace", self.namespace, "--wait=true", "--timeout=120s")
        shutil.rmtree(self.path)
