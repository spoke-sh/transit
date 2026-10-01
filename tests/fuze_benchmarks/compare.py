"""Paired file-plan regression measurements with frozen binaries and checked results."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import platform
import statistics
import subprocess
import tempfile

import run


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline', type=Path, required=True)
    parser.add_argument('--baseline-revision', required=True)
    parser.add_argument('--candidate', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--query', choices=('all', 'filter', 'compound', 'count', 'sum'), default='filter')
    parser.add_argument('--rows', type=int, default=4096)
    parser.add_argument('--repetitions', type=int, default=3)
    parser.add_argument('--shapes', nargs='+', choices=run.SHAPES, default=list(run.SHAPES))
    parser.add_argument('--modes', nargs='+', choices=('explicit', 'sampled', 'full'), default=['explicit', 'sampled', 'full'])
    args = parser.parse_args()
    if not 4 <= args.rows <= 100_000_000 or not 3 <= args.repetitions <= 20:
        parser.error('Invalid workload budget')
    baseline_revision = run.git('rev-parse', args.baseline_revision + '^{commit}')
    cpu = min(os.sched_getaffinity(0))
    binaries = dict(baseline=args.baseline.resolve(), candidate=args.candidate.resolve())
    report = dict(
        definition='transit.fuze.file-comparison.v1', status='running', completed=False,
        timestamp_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
        baseline_revision=baseline_revision, candidate_revision=run.git('rev-parse', 'HEAD'),
        candidate_dirty=bool(run.git('status', '--porcelain')),
        diff_sha256=hashlib.sha256(subprocess.check_output(['git', 'diff', 'HEAD'], cwd=run.ROOT)).hexdigest(),
        source_sha256={str(path.relative_to(run.ROOT)): run.digest(path) for path in sorted((run.ROOT / 'packages/zig/transit-fuze/src').glob('*.zig'))},
        binaries={role: dict(path=str(path), sha256=run.digest(path)) for role, path in binaries.items()},
        driver_sha256=run.digest(__file__), harness_sha256=run.digest(Path(__file__).with_name('run.py')),
        lock_sha256=run.digest(run.ROOT / 'flake.lock'),
        compiler=subprocess.check_output(['zig', 'version'], text=True).strip(),
        platform=platform.platform(), cpu=cpu, load=os.getloadavg(),
        parameters=dict(rows=args.rows, repetitions=args.repetitions, shapes=args.shapes, modes=args.modes,
                        query=args.query, cache='warm_input', timeout_seconds=300, address_space_bytes=4 * 1024**3),
        limitations=[
            'Component measurement with the same source, schema and checked result; no durable transport.',
            'Warm input page-cache conditioning, new captures per sample; other host activity is not isolated.',
            'Compound uses a single-atom baseline with the same selected rows and a candidate six-instruction program.',
            'Compound ratios measure added operator work; they are not same-workload regression gate results.',
        ], fixtures=[], samples=[], summary=[])

    def save():
        args.output.parent.mkdir(parents=True, exist_ok=True)
        temporary = args.output.with_suffix('.tmp')
        temporary.write_text(json.dumps(report, indent=2) + '\n')
        temporary.replace(args.output)

    save()
    try:
        with tempfile.TemporaryDirectory(prefix='transit-file-comparison-', dir='/var/tmp') as temporary:
            directory = Path(temporary)
            for shape in args.shapes:
                fixture = run.fixture(directory, shape, args.rows)
                report['fixtures'].append(dict(shape=shape, files=fixture['files']))
                for mode in args.modes:
                    for repetition in range(args.repetitions):
                        for role in (('baseline', 'candidate') if repetition % 2 == 0 else ('candidate', 'baseline')):
                            query = 'filter' if role == 'baseline' and args.query == 'compound' else args.query
                            config = run.config(fixture, mode, args.rows, 8, False, query)
                            conditioning = run.condition(fixture['paths'], 'warm_input')
                            sample = run.invoke([str(binaries[role])], config, fixture, directory, 'transit', 300, cpu)
                            sample.update(role=role, shape=shape, mode=mode, repetition=repetition,
                                          conditioning=conditioning, configuration=config)
                            report['samples'].append(sample)
                            save()
                            if sample['exit_code'] or sample.get('validation_error') or sample['timeout']:
                                raise RuntimeError(f'{role}/{shape}/{mode} failed; see retained sample')
                    for phase in ('compile', 'scan_convert_execute'):
                        medians = {}
                        for role in binaries:
                            timings = [record['elapsed_ns'] for sample in report['samples']
                                       if (sample['role'], sample['shape'], sample['mode']) == (role, shape, mode)
                                       for record in sample['records'] if record.get('phase') == phase]
                            medians[role] = statistics.median(timings)
                        ratio = medians['candidate'] / medians['baseline']
                        report['summary'].append(dict(shape=shape, mode=mode, phase=phase, median_ns=medians,
                                                      ratio=ratio, same_workload=args.query != 'compound'))
                    print(f'{shape}/{mode}: {args.repetitions} pairs verified', flush=True)
        report.update(status='passed', completed=True)
    except BaseException as error:
        report.update(status='failed', completed=False, failure=f'{type(error).__name__}: {error}')
        raise
    finally:
        save()


if __name__ == '__main__':
    main()
