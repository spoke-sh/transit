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


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("profile", choices=("local", "compose"))
    parser.add_argument("action", choices=("up", "down", "status", "endpoints", "logs", "restart", "inspect", "send", "reset", "attach", "service"))
    parser.add_argument("argument", nargs="?")
    parser.add_argument("--name", default=os.environ.get("REY_LAUNCHER_NAME", "default"))
    parser.add_argument("--base-port", type=int, default=os.environ.get("REY_LAUNCHER_BASE_PORT"))
    parser.add_argument("--request-id")
    parser.add_argument("-d", "--detach", action="store_true", help="Start local services in the background")
    args = parser.parse_intermixed_args()
    if args.detach and (args.profile != "local" or args.action != "up"):
        parser.error("--detach is only supported by local up")
    installation = Installation(args.profile, args.name, args.base_port, environment() if args.action == "up" else {})
    launcher = Local(installation) if args.profile == "local" else Compose(installation)
    if args.profile == "local" and args.action == "up" and not args.detach:
        launcher.foreground()
        return
    if args.action == "service":
        if args.profile != "local":
            raise ValueError("Internal service command is local-only")
        launcher.service(args.argument)
        return
    if args.action == "attach":
        if args.profile != "local":
            raise ValueError("Attach is local-only; use Compose status and logs")
        launcher.attach()
        return
    with lock(installation.lifecycle_lock):
        if args.action == "up":
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
            if args.action == "down":
                launcher.down()
                print("Stopped owned services; data and keys retained.")
            elif args.action == "status":
                print(json.dumps({**installation.endpoints(), "services": launcher.services()}, indent=2))
            elif args.action == "endpoints":
                print(json.dumps(installation.endpoints(), indent=2))
            elif args.action == "logs":
                launcher.logs(args.argument or "node")
            elif args.action == "restart":
                launcher.restart(args.argument)
            elif args.action == "inspect":
                print(json.dumps(installation.inspect(), indent=2))
            elif args.action == "send":
                value = int(args.argument)
                if not -(2**63) <= value < 2**63:
                    raise ValueError("Counter input must fit a signed 64-bit integer")
                identity = "send-" + (args.request_id or secrets.token_hex(12))
                print(f"Request ID: {identity.removeprefix('send-')}", file=sys.stderr, flush=True)
                position = installation.command(identity, {"send": {"pid": installation.endpoints()["pid"], "value": str(value).encode().hex()}})
                print(json.dumps({"request_id": identity.removeprefix("send-"), "admitted_at": position}))
            elif args.action == "reset":
                if launcher.services():
                    raise RuntimeError("Run down before reset; reset never stops or adopts live resources")
                shutil.rmtree(installation.path)
                print("Deleted this launcher's development data and keys.")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, OSError, subprocess.SubprocessError) as error:
        raise SystemExit(str(error)) from error
