"""Qualify named external profiles using their existing owned public-boundary rigs.

Profiles are separate experiments. A local result does not certify Kubernetes,
other SDK hosts, arbitrary TLS peers or the deterministic simulation itself.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]

DISCOVERY = [
    ['just', 'test::model', '--tail', '5'],
    ['just', 'test::properties', '--seeds', '128', '--steps', '128'],
    ['just', 'test::simulation', '--seeds', '64', '--steps', '128'],
    ['just', 'test::resource-simulation', '--seeds', '4'],
    ['just', 'test::scheduler-simulation', '--seeds', '16', '--steps', '128'],
    ['just', 'test::domain-simulation', '--seeds', '16'],
    ['just', 'test::vortex', '--seed', '19', '--rounds', '16'],
    ['just', 'test::codecs', '--fuzz=10K'],
    ['just', 'test::mutations'],
    ['just', 'test::simulation-mutations'],
    ['just', 'test::resource-simulation-mutations'],
    ['just', 'test::scheduler-simulation-mutations'],
    ['just', 'test::domain-simulation-mutations'],
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=('sdk', 'application', 'query', 'reactive', 'discovery'), required=True)
    args = parser.parse_args()
    destination = ROOT / '.cache/verification/external' / f'{time.time_ns()}-{args.profile}'
    destination.mkdir(parents=True)
    report = dict(completed=False, profile=args.profile, placement='owned local Linux',
        revision=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        dirty=bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT)),
        compiler=subprocess.check_output(['zig', 'version'], text=True).strip(),
        runner_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), stages=[])
    report_path = destination / 'report.json'
    report_path.write_text(json.dumps(report, indent=2) + '\n')
    if args.profile == 'discovery' and report['dirty']:
        raise SystemExit('Discovery includes mutation checks against committed HEAD; commit source changes first.')
    profiles = dict(
        application=[['just', 'test::server-application-faults'], ['just', 'test::runtime-upgrade']],
        query=[['just', 'test::unified-lifecycle'], ['just', 'test::unified-expiry'],
               ['just', 'test::interactive-query', '--source', 'table']],
        reactive=[['just', 'test::reactive-views-lifecycle']],
        discovery=DISCOVERY)
    started = time.monotonic()

    def execute(command, *, capture=False):
        # Keep artifact preparation in the same failure/timeout ledger as the
        # scenarios. Native preparation emits one verified immutable prefix.
        stage = dict(command=list(map(str, command)), completed=False,
                     timeout_seconds=3600 if args.profile == 'discovery' else 900)
        index = len(report['stages'])
        report['stages'].append(stage)
        report_path.write_text(json.dumps(report, indent=2) + '\n')
        print(f'External {args.profile}: {command[0:3]}', flush=True)
        begin = time.monotonic()
        with (destination / f'{index}.log').open('w') as log:
            child = subprocess.Popen(command, cwd=ROOT,
                stdout=subprocess.PIPE if capture else log, stderr=log, start_new_session=True, text=True)
            try:
                output, _ = child.communicate(timeout=stage['timeout_seconds'])
                if output:
                    log.write(output)
                stage.update(exit=child.returncode, completed=child.returncode == 0)
                if child.returncode:
                    raise RuntimeError(f'external stage failed; inspect {destination / f"{index}.log"}')
                return output.strip() if capture else None
            finally:
                if child.poll() is None:
                    # Let the owned fixture join its children before escalating
                    # within this invocation's process group only.
                    os.killpg(child.pid, signal.SIGTERM)
                    try:
                        child.wait(timeout=20)
                    except subprocess.TimeoutExpired:
                        os.killpg(child.pid, signal.SIGKILL)
                        child.wait(timeout=10)
                stage['seconds'] = round(time.monotonic() - begin, 3)
                report_path.write_text(json.dumps(report, indent=2) + '\n')

    try:
        if args.profile == 'sdk':
            execute(['just', 'bindings::python-build', 'bindings::node-build'])
            prepare = [sys.executable, '-B', 'tests/runner/launch.py',
                       'tests/harness/native_artifacts.py', 'prepare']
            clients = Path(execute([*prepare, 'clients', '--optimize', 'Debug'], capture=True)).resolve(strict=True)
            authority = Path(execute([*prepare, 'authority', '--optimize', 'Debug'], capture=True)).resolve(strict=True)
            native = [authority / 'bin/transit-node', clients / 'bin/transit-admin', clients / 'lib/libtransit_client.so']
            packages = ROOT / '.cache/bindings/Debug'
            profiles['sdk'] = [
                [sys.executable, '-B', 'tests/runner/launch.py', 'tests/sdk/consumers/python/python_client_sdk.py',
                 *native, packages / 'wheels', destination / 'python.json'],
                [sys.executable, '-B', 'tests/runner/launch.py', 'tests/sdk/consumers/node/node_client_sdk.py',
                 *native, packages / 'node', destination / 'node.json']]
        for command in profiles[args.profile]:
            execute(command)
        if args.profile == 'sdk':
            report['artifacts'] = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in [*native, *(packages / 'wheels').glob('*.whl'), *(packages / 'node').glob('*.tgz')]}
            for name in ('python', 'node'):
                if not json.loads((destination / f'{name}.json').read_text())['completed']:
                    raise RuntimeError(f'incomplete installed {name} driver')
        report['completed'] = True
    finally:
        report['seconds'] = round(time.monotonic() - started, 3)
        report_path.write_text(json.dumps(report, indent=2) + '\n')
        print(f'External evidence: {destination}', flush=True)


if __name__ == '__main__':
    signal.signal(signal.SIGTERM, lambda *_: (_ for _ in ()).throw(KeyboardInterrupt()))
    main()
