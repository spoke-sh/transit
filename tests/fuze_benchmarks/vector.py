"""Retain paired decoded-kernel/owned-row measurements and independent answers."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import statistics
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def command(*args):
    return subprocess.check_output(args, text=True).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--engines', nargs='+', choices=['scalar', 'batch', 'simd'], default=['scalar'])
    args = parser.parse_args()
    cpu = min(os.sched_getaffinity(0))
    report = dict(definition='transit.vector.measurement.v1', status='running', completed=False,
                  revision=command('git', 'rev-parse', 'HEAD'),
                  tracked_dirty=bool(command('git', 'status', '--porcelain', '--untracked-files=no')),
                  binary_sha256=digest(args.binary), driver_sha256=digest(__file__),
                  fixture='key=null if i%13==0 else missing if i%17==0 else i%101-50; payload=i*3-7',
                  cpu=cpu, cpuinfo=Path('/proc/cpuinfo').read_text().split('\n\n')[0],
                  platform=platform.platform(), compiler=command('zig', 'version'),
                  lock_sha256=digest(ROOT/'flake.lock'), samples=[], summary=[])

    def save():
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2)+'\n')

    save()
    try:
        for rows, repeats in [(8, 100), (4096, 20)]:
            expected = [i*3-7 for i in range(rows) if i%13 and i%17 and i%101 >= 50]
            for phase in ['kernel', 'pipeline']:
                for repetition in range(10):
                    for engine in args.engines[::1 if repetition%2 else -1]:
                        result = subprocess.run([str(args.binary.resolve()), engine, phase, str(rows), str(repeats)],
                            capture_output=True, text=True, timeout=120,
                            preexec_fn=lambda: os.sched_setaffinity(0, {cpu}))
                        sample = dict(engine=engine, phase=phase, rows=rows, repetition=repetition,
                                      warmup=repetition==0, exit_code=result.returncode,
                                      stdout=result.stdout, stderr=result.stderr)
                        report['samples'].append(sample)
                        save()
                        assert result.returncode == 0, sample
                        data = json.loads(result.stdout)
                        sample['record'] = data
                        assert data['count'] == len(expected)*repeats and data['checksum'] == sum(expected)*repeats, sample
                        assert data['end_live_bytes'] == 0 and data['build_mode'] == 'safe', sample
                        assert data['elapsed_ns'] > 0, sample
                for engine in args.engines:
                    records = [s['record'] for s in report['samples'] if s['rows']==rows and s['phase']==phase and s['engine']==engine and not s['warmup']]
                    report['summary'].append(dict(engine=engine, phase=phase, rows=rows,
                        median_ns=statistics.median(r['elapsed_ns'] for r in records),
                        peak_live_bytes=max(r['peak_live_bytes'] for r in records),
                        allocations=max(r['allocations'] for r in records)))
        report.update(status='passed', completed=True)
    except BaseException as error:
        report.update(status='failed', error=str(error))
        raise
    finally:
        save()


if __name__ == '__main__':
    main()
