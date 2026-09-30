"""Replay bounded component schedules through their real package implementations.

Component assertions are independent contract checks, not a second copy of the
component algorithm. These private-turn stores do not establish disk durability.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
DOMAINS = ({'document', 'checkpoint'}, {'exchange'}, {'refresh'}, {'runtime'})


def execute(binary, seed, expected, log):
    result = subprocess.run([str(binary), f'--seed={seed}'], capture_output=True,
                            text=True, timeout=120, env=os.environ | {'TRANSIT_SIMULATION_TRACE': '1'})
    output = result.stdout + result.stderr
    log.write_text(output)
    if result.returncode:
        if any(marker in output for marker in ('FAIL (TestExpected', 'FAIL (TestUnexpectedResult)')):
            raise RuntimeError(f'component invariant failed; inspect {log}')
        raise RuntimeError(f'component schedule failed ({result.returncode}); inspect {log}')
    events = [json.loads(line.split('SIMULATION ', 1)[1])
              for line in output.splitlines() if 'SIMULATION ' in line]
    if {e['domain'] for e in events} != expected:
        raise RuntimeError(f'incomplete domain coverage; inspect {log}')
    return events


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binaries', nargs=4, type=Path)
    parser.add_argument('--seeds', type=int, default=2)
    parser.add_argument('--seed', type=int, default=1)
    args = parser.parse_args()
    if not 1 <= args.seeds <= 64 or not 1 <= args.seed <= 2**32 - args.seeds:
        parser.error('use 1..64 seeds within the nonzero u32 range')
    destination = ROOT / '.cache/verification/domain-simulation'
    destination.mkdir(parents=True, exist_ok=True)
    report_path = destination.with_suffix('.json')
    report = dict(completed=False, revision=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                  dirty=bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT)),
                  compiler=subprocess.check_output(['zig', 'version'], text=True).strip(),
                  generator='pinned-zig-default-prng-domain-v1', seed=args.seed, seeds=args.seeds,
                  binaries=[hashlib.sha256(p.read_bytes()).hexdigest() for p in args.binaries],
                  runner_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), runs=[])
    report_path.write_text(json.dumps(report, indent=2) + '\n')
    started = time.monotonic()
    try:
        for seed in range(args.seed, args.seed + args.seeds):
            for index, (binary, expected) in enumerate(zip(args.binaries, DOMAINS)):
                name = f'{index}-{seed}'
                events = execute(binary, seed, expected, destination / f'{name}.log')
                (destination / f'{name}.json').write_text(json.dumps(events, indent=2) + '\n')
                replay = execute(binary, seed, expected, destination / f'{name}-replay.log')
                if replay != events:
                    raise RuntimeError(f'component replay differs: {name}')
                report['runs'].append(dict(seed=seed, domains=sorted(expected), events=len(events),
                    trace_sha256=hashlib.sha256(json.dumps(events, sort_keys=True).encode()).hexdigest()))
        report['completed'] = True
    finally:
        report['seconds'] = round(time.monotonic() - started, 3)
        report_path.write_text(json.dumps(report, indent=2) + '\n')
    print(f'Domain simulation: {len(report["runs"])} schedules, identical replay; {report["seconds"]}s')


if __name__ == '__main__':
    main()
