"""Saved update intent for recoverable deployment; never rollback protocol state."""
import json
import secrets
import socket

from common import lock, write
import settings


def update(launcher, names, no_build=False, replace_pending=False):
    installation = launcher.installation
    artifacts = installation.artifacts
    pending = installation.path / "update.json"
    running = bool(launcher.services())
    legacy_topology = bool(artifacts.read("selected")) and "transit-delivery" not in artifacts.read("selected")
    if legacy_topology and set(artifacts.roles(names)) != set(artifacts.roles([])):
        raise RuntimeError("The M8 protocol/topology upgrade requires update without service names")
    if not running and not (pending.exists() and installation.profile == "local"):
        if legacy_topology and installation.profile in ("local", "compose") and not pending.exists():
            target, _ = artifacts.plan([], no_build)
            publish(launcher, {"selection": target, "configuration": installation.load()})
            print("Coordinated artifacts selected; run up to recover the stopped installation.")
            return
        raise RuntimeError("Start the installation before updating it")
    if not artifacts.read("selected"):
        raise RuntimeError("This installation predates identified artifacts; run down then up once")
    if pending.exists() and replace_pending:
        # This discards only a deployment plan. It cannot erase or reverse an
        # accepted provider transition or a signed request with unknown outcome.
        with lock(installation.path / "operator/lock"):
            installation._flush(json.loads((installation.path / "operator/sequence.json").read_text()))
        if installation.profile == "reference":
            binding = installation.view()["binding"]
            if binding and binding.get("upgrade_from"):
                raise RuntimeError("Reconcile the recorded template switch before replacing its deployment plan")
        abandoned = json.loads(pending.read_text())
        write(installation.path / "update-history" / (abandoned["id"] + ".json"), abandoned)
        pending.unlink()
    if pending.exists():
        operation = json.loads(pending.read_text())
        if names and set(artifacts.roles(names)) != set(operation["requested"]):
            raise RuntimeError("An update is unfinished; retry update with its original services")
        print("Resuming update " + operation["id"] + "; use --replace-pending to plan a corrected deployment", flush=True)
    else:
        target, changed = artifacts.plan(names, no_build)
        roles = artifacts.roles(names)
        config = installation.load()
        proposed = dict(config)
        diagnostics = settings.observability(config.get("observability", {}), installation.profile)
        proposed["observability"] = {**config.get("observability", {})}
        for role in roles:
            proposed["observability"][role] = diagnostics.get(role, {})
            if proposed["observability"][role] != config.get("observability", {}).get(role, {}):
                changed.append(role)
        if "board" in roles:
            board = settings.resolve(installation.board, installation.board_overrides, config["base_port"])
            if board != installation.board:
                current = installation.board
                replaces_listener = board["port"] == current["port"] and (
                    board["host"] == current["host"] or "0.0.0.0" in (board["host"], current["host"]))
                if not replaces_listener:
                    with socket.socket() as listener:
                        listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                        listener.bind((board["host"], board["port"]))
                proposed["board"] = board
                changed.append("board")
        changed = [r for r in roles if r in changed]
        if not changed:
            print("Selected artifacts and configuration are unchanged; no changes applied.")
            return
        operation = {"id": secrets.token_hex(12), "requested": roles, "services": changed,
                     "selection": target, "configuration": proposed, "completed": []}
        launcher.validate_update(operation)
        write(pending, operation)
    print("Updating: " + ", ".join(operation["services"]), flush=True)
    try:
        launcher.apply_update(operation)
        write(installation.path / "observed.json", {"update": operation["id"],
              "artifacts": operation["selection"], "services": launcher.services()})
        pending.unlink()
        print("Update ready; process identity and durable state retained.", flush=True)
    except BaseException as error:
        # Diagnostics identify the phase without recording credentials/output.
        operation["error"] = type(error).__name__
        write(pending, operation)
        raise


def publish(launcher, operation):
    installation = launcher.installation
    installation.artifacts.select(operation["selection"])
    write(installation.manifest, operation["configuration"])
    installation.configs()


def completed(launcher, operation, role):
    if role not in operation["completed"]:
        operation["completed"].append(role)
    write(launcher.path / "update.json", operation)
