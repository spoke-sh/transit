"""Compare bounded host workers through real captured-file pipelines."""
import argparse
import itertools
import json
import os
from pathlib import Path
import statistics
import tempfile
import performance.query.run as run


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    cpus = sorted(os.sched_getaffinity(0))[:4]
    if len(cpus) < 4:
        parser.error('Provide four distinct CPU cores for the worker comparison')
    report = dict(definition='transit.vector.file-workers.v1', completed=False, status='running',
                  revision=run.git('rev-parse', 'HEAD'),
                  tracked_dirty=bool(run.git('status', '--porcelain', '--untracked-files=no')),
                  binary_sha256=run.digest(args.binary), driver_sha256=run.digest(Path(__file__)),
                  affinity=cpus, samples=[], fixtures=[], summary=[])

    def save():
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2) + '\n')

    save()
    try:
        with tempfile.TemporaryDirectory(prefix='transit-workers-', dir='/var/tmp') as directory:
            root = Path(directory)
            for shape, query in itertools.product(['narrow', 'sparse'], ['filter', 'count', 'count-values']):
                fixture = run.fixture(root, shape, 4096)
                report['fixtures'].append(dict(shape=shape, query=query, files=fixture['files']))
                for repetition in range(10):
                    for workers in ([1, 2, 4] if repetition % 2 else [4, 2, 1]):
                        config = run.config(fixture, 'explicit', 4096, 8, False, query)
                        config.update(experimental_batch=True, compute_rows=256, compute_bytes=262144, workers=workers)
                        pages = run.condition(fixture['paths'], 'warm_input')
                        # The ordinary harness pins its launcher to one core;
                        # taskset expands this measured worker process to four.
                        sample = run.invoke(['taskset', '-c', ','.join(map(str, cpus)), str(args.binary.resolve())],
                                            config, fixture, root, 'transit', 120, cpus[0])
                        sample.update(workers=workers, shape=shape, query=query, repetition=repetition,
                                      warmup=repetition == 0, input_pages=pages)
                        report['samples'].append(sample)
                        save()
                        assert sample['exit_code'] == 0 and not sample.get('validation_error') and not sample['timeout'], sample
                for workers in [1, 2, 4]:
                    rows = [next(r for r in s['records'] if r.get('phase') == 'scan_convert_execute')
                            for s in report['samples'] if s['shape'] == shape and s['query'] == query
                            and s['workers'] == workers and not s['warmup']]
                    report['summary'].append(dict(shape=shape, query=query, workers=workers,
                        median_ns=statistics.median(r['elapsed_ns'] for r in rows),
                        first_ns=statistics.median(r['first_batch_ns'] for r in rows),
                        peak_live_bytes=max(r['peak_live_bytes'] for r in rows)))
        report.update(completed=True, status='passed')
    except BaseException as error:
        report.update(status='failed', error=str(error))
        raise
    finally:
        save()


if __name__ == '__main__':
    main()
