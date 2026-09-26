#!/usr/bin/env python3
"""Owned, persistent development installations. Use the launchers:: just tasks."""
import argparse
import json
import os
import secrets
import shutil
import subprocess
import sys

from common import Installation, lock
from compose import Compose
from local import Local
from settings import environment
from kubernetes import Reference, ReferenceInstallation


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("profile", choices=("local", "compose", "reference"))
    parser.add_argument("action", choices=("up", "down", "status", "endpoints", "logs", "restart", "inspect", "send", "reset", "attach", "service", "build", "update"))
    parser.add_argument("arguments", nargs="*")
    parser.add_argument("--no-build", action="store_true", help="Update using the saved candidate artifacts")
    parser.add_argument("--replace-pending", action="store_true", help="Replace a failed deployment plan when no recorded template switch is unresolved")
    parser.add_argument("--missing-cluster", action="store_true", help="Reference reset only: discard local installation files after verifying its original cluster was deleted")
    parser.add_argument("--name", default=os.environ.get("REY_LAUNCHER_NAME", "default"))
    parser.add_argument("--example", choices=("counter", "station"), help="Select a new installation's example; persisted thereafter")
    parser.add_argument("--base-port", type=int, default=os.environ.get("REY_LAUNCHER_BASE_PORT"))
    parser.add_argument("--request-id")
    parser.add_argument("-d", "--detach", action="store_true", help="Start services in the background")
    args = parser.parse_intermixed_args()
    args.argument = args.arguments[0] if args.arguments else None
    if args.missing_cluster and (args.action != "reset" or args.profile != "reference"):
        parser.error("--missing-cluster is only supported by reference reset")
    if (args.no_build or args.replace_pending) and args.action != "update":
        parser.error("--no-build and --replace-pending are only supported by update")
    if args.action not in ("build", "update") and len(args.arguments) > 1:
        parser.error("This action accepts at most one argument")
    if args.detach and args.action != "up":
        parser.error("--detach is only supported by up")
    installation = Installation(args.profile, args.name, args.base_port, environment() if args.action in ("up", "update") else {})
    selected_example = args.example
    if installation.manifest.exists():
        saved_example = json.loads(installation.manifest.read_text()).get("example", "counter")
        if selected_example is not None and selected_example != saved_example:
            raise ValueError("Example selection is permanent; use a new launcher name")
        selected_example = saved_example
    if selected_example == "station":
        from station_example import StationInstallation
        installation = StationInstallation(args.profile, args.name, args.base_port, environment() if args.action in ("up", "update") else {})
    if args.profile == "reference":
        if selected_example != "station":
            installation = ReferenceInstallation(args.name, args.base_port, environment() if args.action in ("up", "update") else {})
        elif not installation.manifest.exists() and args.base_port is None:
            installation.base_port = 18300
    reference_type = Reference
    if args.profile == "reference" and selected_example == "station":
        from station_reference import StationReference
        reference_type = StationReference
    launcher = {"local": Local, "compose": Compose, "reference": reference_type}[args.profile](installation)
    if args.action == "up" and not args.detach and args.profile != "reference":
        launcher.foreground()
        return
    if args.action == "service":
        if args.profile != "local":
            raise ValueError("Internal service command is local-only")
        launcher.service(args.argument)
        return
    if args.action == "attach":
        if args.profile == "compose":
            raise ValueError("Use Compose status and logs")
        launcher.attach()
        return
    with lock(installation.lifecycle_lock):
        if args.action == "build":
            installation.artifacts.build(args.arguments)
        elif args.action == "up":
            installation.prepare()
            launcher.up()
            print(json.dumps(installation.endpoints(), indent=2))
        elif not installation.manifest.exists():
            if args.action in ("down", "status"):
                print(json.dumps({"profile": args.profile, "name": args.name, "status": "not provisioned"}))
            else:
                raise RuntimeError("Run up first")
        else:
            installation.load()
            if args.action == "update":
                from updates import update
                update(launcher, args.arguments, args.no_build, args.replace_pending)
            elif args.action == "down":
                launcher.down()
                print("Stopped owned services; data and keys retained.")
            elif args.action == "status":
                print(json.dumps({**installation.endpoints(), "services": launcher.services(), "artifacts": {kind: installation.artifacts.read(kind) for kind in ("candidates", "selected")},
                                  "update_pending": (installation.path / "update.json").exists()}, indent=2))
            elif args.action == "endpoints":
                print(json.dumps(installation.endpoints(), indent=2))
            elif args.action == "logs":
                launcher.logs(args.argument or "node")
            elif args.action == "restart":
                if (installation.path / "update.json").exists():
                    raise RuntimeError("An update is pending; retry update before restarting services")
                launcher.restart(args.argument)
            elif args.action == "inspect":
                print(json.dumps(installation.inspect(), indent=2))
            elif args.action == "send":
                body = installation.send_value(args.argument)
                identity = "send-" + (args.request_id or secrets.token_hex(12))
                print(f"Request ID: {identity.removeprefix('send-')}", file=sys.stderr, flush=True)
                position = installation.command(identity, body)
                print(json.dumps({"request_id": identity.removeprefix("send-"), "admitted_at": position}))
            elif args.action == "reset":
                if args.missing_cluster:
                    launcher.reset_missing_cluster()
                    print("Discarded local installation files for the deleted cluster; a later up creates fresh identity and history.")
                    return
                if launcher.services():
                    raise RuntimeError("Run down before reset; reset never stops or adopts live resources")
                if args.profile == "reference":
                    launcher.reset()
                else:
                    shutil.rmtree(installation.path)
                print("Deleted this launcher's development data and keys.")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, OSError, subprocess.SubprocessError) as error:
        raise SystemExit(str(error)) from error
