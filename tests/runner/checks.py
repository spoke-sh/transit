"""Run declared repository checks with separate generation and validation timings."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time

from capture import directory, provenance, run, write_json

ROOT = Path(__file__).resolve().parents[2]
CATALOG = Path(__file__).with_name("checks.json")


def expand(command, root):
    result = []
    for argument in command:
        if isinstance(argument, str):
            result.append(argument)
        else:
            assert set(argument) == {"glob"}, argument
            matches = sorted(str(path.relative_to(root)) for path in root.glob(argument["glob"]))
            assert matches, f"empty check input: {argument}"
            result.extend(matches)
    assert result
    return result


def execute(checks, generators, destination, root=ROOT):
    assert checks and len({check["id"] for check in checks}) == len(checks)
    required = {check["generator"]["name"] for check in checks if "generator" in check}
    assert generators.keys() == required, (required, generators.keys())
    artifacts = directory(destination)
    report = {"version": 1, **provenance(root),
              "run_directory": str(artifacts.relative_to(destination.parent)),
              "checks_sha256": hashlib.sha256(json.dumps(checks, sort_keys=True).encode()).hexdigest(),
              "started_unix": time.time(),
              "completed": False, "expected_checks": [check["id"] for check in checks],
              "checks": [], "active": None}
    def checkpoint():
        write_json(artifacts / "report.json", report)
        write_json(destination, report)

    def invoke(command, stage, **kwargs):
        log = artifacts / f"{len(report['checks']):03d}-{stage}.log"
        result = {"stage": stage, "command": command, "exit_code": None,
                  "log": log.name, "completed": False}
        entry["stages"].append(result)
        report["active"] = {"id": entry["id"], "stage": stage}
        checkpoint()
        started = time.monotonic()
        try:
            process = run(command, cwd=root, log=log, result=result, **kwargs)
            process.check_returncode()
            return process
        except subprocess.CalledProcessError as error:
            result["exit_code"] = error.returncode
            raise
        finally:
            result["seconds"] = round(time.monotonic() - started, 3)
            checkpoint()

    checkpoint()
    try:
        for check in checks:
            entry = {"id": check["id"], "phase": check["phase"], "stages": [], "completed": False,
                     "expected_stages": ["generate", "validate"] if "generator" in check else ["validate"]}
            report["checks"].append(entry)
            print(f"Check {check['id']}", flush=True)
            body = None
            if generator := check.get("generator"):
                command = [generators[generator["name"]], *generator["args"]]
                body = invoke(command, "generate", capture_stdout=True).stdout
            invoke(expand(check["command"], root), "validate", input=body)
            entry["completed"] = True
            report["active"] = None
            checkpoint()
        report["completed"] = True
    finally:
        checkpoint()
    print(f"Checks passed: {len(checks)}; timings: {destination}", flush=True)


def main():
    catalog = json.loads(CATALOG.read_text())
    assert catalog["version"] == 1
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("profile", choices=catalog["profiles"])
    parser.add_argument("--generator", nargs=2, action="append", default=[])
    args = parser.parse_args()
    generators = {name: str(Path(path).resolve()) for name, path in args.generator}
    assert len(generators) == len(args.generator), "duplicate generator"
    try:
        execute(catalog["profiles"][args.profile], generators,
                ROOT / ".cache/checks" / f"{args.profile}.json")
    except subprocess.CalledProcessError as error:
        raise SystemExit(error.returncode if error.returncode > 0 else 128 - error.returncode)


if __name__ == "__main__":
    main()
