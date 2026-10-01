"""Alternate identical specialized-path drivers against frozen control/candidate."""
import argparse
import json
import os
from pathlib import Path
import statistics
import subprocess
import run


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('control', type=Path)
    parser.add_argument('candidate', type=Path)
    parser.add_argument('--control-revision', required=True)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--repetitions', default=9, type=int)
    args = parser.parse_args()
    if not 3 <= args.repetitions <= 30: parser.error('Select 3 to 30 repetitions')
    cpu = min(os.sched_getaffinity(0))
    report = dict(definition=run.DEFINITION, completed=False, status='running', samples=[], summary=[],
        control_revision=args.control_revision, candidate_revision=run.git('rev-parse', 'HEAD'),
        dirty=bool(run.git('status', '--porcelain')), cpu=cpu, host_load=os.getloadavg(),
        lock_sha256=run.digest(run.ROOT/'flake.lock'), driver_sha256=run.digest(Path(__file__).with_name('six.zig')),
        binaries={name: dict(path=str(path.resolve()), sha256=run.digest(path)) for name, path in [('control', args.control), ('candidate', args.candidate)]})
    def save():
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2) + '\n')
    save()
    try:
        for repetition in range(args.repetitions + 1):
            for name in (('control', 'candidate') if repetition % 2 else ('candidate', 'control')):
                p = subprocess.run([report['binaries'][name]['path']], capture_output=True, text=True, timeout=120,
                    preexec_fn=lambda: os.sched_setaffinity(0, {cpu}))
                sample = dict(engine=name, repetition=repetition, warmup=repetition == 0, exit_code=p.returncode,
                    records=[json.loads(line) for line in p.stdout.splitlines()], stderr=p.stderr)
                report['samples'].append(sample); save()
                assert p.returncode == 0 and len(sample['records']) == 8
                assert all(r['build_mode'] == 'safe' and r['elapsed_ns'] > 0 for r in sample['records'])
        for index in range(8):
            pair = {}
            for name in ('control', 'candidate'):
                rows = [sample['records'][index] for sample in report['samples'] if sample['engine'] == name and not sample['warmup']]
                signatures = [{k:v for k,v in r.items() if k != 'elapsed_ns'} for r in rows]
                assert all(signature == signatures[0] for signature in signatures)
                pair[name] = dict(signature=signatures[0], raw_ns=[r['elapsed_ns'] for r in rows], median_ns=statistics.median(r['elapsed_ns'] for r in rows))
            assert pair['control']['signature'] == pair['candidate']['signature']
            report['summary'].append(dict(sql=pair['control']['signature']['sql'], **pair,
                candidate_control_ratio=pair['candidate']['median_ns']/pair['control']['median_ns']))
        report.update(completed=True, status='passed')
    except BaseException as error:
        report.update(status='failed', error=str(error), summary=[]); raise
    finally: save()


if __name__ == '__main__': main()
