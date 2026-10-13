"""Sweep experimental file batches through the existing capture/scan harness."""
import argparse
import itertools
import json
import os
from pathlib import Path
import statistics
import tempfile
import run


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    report = dict(definition='transit.vector.files.v1', status='running', completed=False,
                  revision=run.git('rev-parse', 'HEAD'),
                  tracked_dirty=bool(run.git('status', '--porcelain', '--untracked-files=no')),
                  binary_sha256=run.digest(args.binary), driver_sha256=run.digest(Path(__file__)),
                  cpu=min(os.sched_getaffinity(0)), samples=[], fixtures=[], summary=[])
    def save():
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2)+'\n')
    save()
    try:
        with tempfile.TemporaryDirectory(prefix='transit-vector-', dir='/var/tmp') as directory:
            root = Path(directory)
            for shape, query in itertools.product(['narrow', 'sparse'], ['filter', 'count', 'count-values']):
                fixture = run.fixture(root, shape, 4096)
                report['fixtures'].append(dict(shape=shape, query=query, files=fixture['files']))
                for target, budget in itertools.product([64, 256, 1024], [65536, 262144, 1048576]):
                    groups = {'scalar': [], 'batch': []}
                    for repetition in range(3):
                        for engine in (['scalar', 'batch'] if repetition%2 else ['batch', 'scalar']):
                            config = run.config(fixture, 'explicit', 4096, 8, False, query)
                            config.update(experimental_batch=engine=='batch', compute_rows=target, compute_bytes=budget)
                            pages = run.condition(fixture['paths'], 'warm_input')
                            sample = run.invoke([str(args.binary.resolve())], config, fixture, root, 'transit', 120, report['cpu'])
                            sample.update(engine=engine, shape=shape, query=query, rows=target, bytes=budget, repetition=repetition, input_pages=pages)
                            report['samples'].append(sample)
                            save()
                            assert sample['exit_code']==0 and not sample.get('validation_error') and not sample['timeout'], sample
                            groups[engine].append(next(r for r in sample['records'] if r.get('phase')=='scan_convert_execute'))
                    report['summary'].append(dict(shape=shape, query=query, rows=target, bytes=budget,
                        pipeline_ratio=statistics.median(r['elapsed_ns'] for r in groups['batch'])/statistics.median(r['elapsed_ns'] for r in groups['scalar']),
                        scalar=groups['scalar'], batch=groups['batch']))
        report.update(status='passed', completed=True)
    except BaseException as error:
        report.update(status='failed', error=str(error))
        raise
    finally:
        save()


if __name__ == '__main__':
    main()
