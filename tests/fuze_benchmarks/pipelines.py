"""Freeze and compare typed owned-row pipelines against an independent oracle."""
import argparse
import json
import os
from pathlib import Path
import platform
import statistics
import subprocess
from vector import command, digest, ROOT

CASES = ['int64', 'uint64', 'float64', 'boolean', 'eager', 'sum', 'utf8', 'nested']


def expected(case, rows):
    selected = [i for i in range(rows) if i % 13 and i % 17 and (
        i % 2 == 0 if case in ['boolean', 'utf8'] else
        i % 101 >= 50 and i * 3 - 7 < 6000 if case == 'eager' else
        True if case == 'nested' else i % 101 >= 50)]
    checksum = sum(i * 3 - 7 for i in selected)
    return (1, len(selected)) if case == 'nested' else (1, checksum) if case == 'sum' else (len(selected), checksum)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--engines', nargs='+', choices=['scalar', 'batch', 'simd', 'parallel1', 'parallel2', 'parallel4'], default=['scalar'])
    args = parser.parse_args()
    affinity = sorted(os.sched_getaffinity(0))
    cpu = affinity[0]
    report = dict(definition='transit.vector.pipelines.v1', status='running', completed=False,
                  revision=command('git', 'rev-parse', 'HEAD'),
                  tracked_dirty=bool(command('git', 'status', '--porcelain', '--untracked-files=no')),
                  binary_sha256=digest(args.binary), driver_sha256=digest(__file__),
                  fixture_sha256=digest(ROOT / 'tests/fuze_benchmarks/pipeline_fixture.zig'),
                  cpu=cpu, parallel_affinity=affinity[:4], cpuinfo=Path('/proc/cpuinfo').read_text().split('\n\n')[0],
                  platform=platform.platform(), compiler=command('zig', 'version'),
                  lock_sha256=digest(ROOT / 'flake.lock'), samples=[], summary=[])

    def save():
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2) + '\n')

    save()
    try:
        for case in CASES:
            for rows, repeats in [(8, 100), (4096, 20)]:
                count, checksum = expected(case, rows)
                for repetition in range(10):
                    for engine in args.engines[::1 if repetition % 2 else -1]:
                        result = subprocess.run([str(args.binary.resolve()), engine, 'pipeline', str(rows), str(repeats), case],
                            capture_output=True, text=True, timeout=120,
                            preexec_fn=lambda: os.sched_setaffinity(0, affinity[:4] if engine.startswith('parallel') else {cpu}))
                        sample = dict(case=case, engine=engine, rows=rows, repetition=repetition,
                                      warmup=repetition == 0, exit_code=result.returncode,
                                      stdout=result.stdout, stderr=result.stderr)
                        report['samples'].append(sample)
                        save()
                        assert result.returncode == 0, sample
                        data = json.loads(result.stdout)
                        sample['record'] = data
                        assert data['count'] == count * repeats and data['checksum'] == checksum * repeats, sample
                        assert data['end_live_bytes'] == 0 and data['build_mode'] == 'safe', sample
                        assert data['elapsed_ns'] > 0, sample
                for engine in args.engines:
                    records = [s['record'] for s in report['samples'] if s['case'] == case and s['rows'] == rows and s['engine'] == engine and not s['warmup']]
                    report['summary'].append(dict(case=case, engine=engine, rows=rows,
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
