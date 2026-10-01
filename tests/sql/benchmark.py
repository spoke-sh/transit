"""Record reproducible pure-engine samples; never infer end-to-end SQL latency."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import statistics
import subprocess
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('binary', type=Path)
    parser.add_argument('--samples', type=int, default=5)
    parser.add_argument('--output', type=Path, default=Path('.cache/verification/sql/benchmark.json'))
    parser.add_argument('--control', type=Path, help='Frozen ReleaseSafe probe to alternate with the candidate')
    parser.add_argument('--control-revision', help='Source revision of the frozen control')
    parser.add_argument('--cpu', type=int, help='Pin both frozen probes to one available CPU')
    args = parser.parse_args()
    if not 1 <= args.samples <= 100:
        parser.error('--samples must be between 1 and 100')
    if bool(args.control) != bool(args.control_revision):
        parser.error('--control and --control-revision must be supplied together')
    if args.cpu is not None and (not hasattr(os, 'sched_getaffinity') or args.cpu not in os.sched_getaffinity(0)):
        parser.error('--cpu must name an available affinity CPU')
    pin = None if args.cpu is None else lambda: os.sched_setaffinity(0, {args.cpu})
    binary = args.binary.resolve()
    # One unrecorded warm-up, followed by independent processes with identical work.
    subprocess.run([binary], check=True, capture_output=True, text=True, preexec_fn=pin)
    samples = []
    control_samples = []
    control = args.control.resolve() if args.control else None
    if control:
        subprocess.run([control], check=True, capture_output=True, text=True, preexec_fn=pin)
    for sample_index in range(args.samples):
        runs = [(binary, samples)] + ([(control, control_samples)] if control else [])
        for executable, target in runs if sample_index % 2 == 0 else reversed(runs):
            result = subprocess.run([executable], check=True, capture_output=True, text=True, preexec_fn=pin)
            target.append([json.loads(line) for line in result.stdout.splitlines()])
    summary = []
    for index, first in enumerate(samples[0]):
        values = [sample[index]['elapsed_ns'] / sample[index]['iterations'] for sample in samples]
        assert all((sample[index]['phase'], sample[index]['case']) == (first['phase'], first['case']) for sample in samples)
        summary.append(dict(phase=first['phase'], case=first['case'],
                            median_ns=statistics.median(values), min_ns=min(values), max_ns=max(values)))
        if control:
            for sample in control_samples:
                assert len(sample) == len(samples[0])
                assert {k: v for k, v in sample[index].items() if k != 'elapsed_ns'} == {k: v for k, v in first.items() if k != 'elapsed_ns'}, 'control workload differs'
            control_values = [sample[index]['elapsed_ns'] / sample[index]['iterations'] for sample in control_samples]
            median = statistics.median(control_values)
            summary[-1].update(control_median_ns=median, control_min_ns=min(control_values),
                               control_max_ns=max(control_values), change_percent=(statistics.median(values) / median - 1) * 100)
    report = dict(version=1, timestamp=time.time(), revision=subprocess.check_output(
        ['git', 'rev-parse', 'HEAD'], text=True).strip(), dirty=bool(subprocess.check_output(
        ['git', 'status', '--porcelain'], text=True)), platform=platform.platform(),
        compiler=subprocess.check_output(['zig', 'version'], text=True).strip(),
        binary_sha256=hashlib.sha256(binary.read_bytes()).hexdigest(), optimization='ReleaseSafe',
        scope='pure compile and paged aggregate; excludes source I/O, authorization and transport',
        cpu=args.cpu, host_load=os.getloadavg() if hasattr(os, 'getloadavg') else None,
        driver_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        probe_sha256=hashlib.sha256(Path('tests/sql_bench.zig').read_bytes()).hexdigest(),
        lock_sha256=hashlib.sha256(Path('flake.lock').read_bytes()).hexdigest(),
        source_sha256={str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in sorted(Path('packages/zig/transit-fuze/src').glob('*.zig'))},
        source_diff=subprocess.check_output(['git', 'diff', 'HEAD', '--', 'packages/zig/transit-fuze/src'], text=True),
        samples=samples, summary=summary)
    if control:
        report['control'] = dict(revision=args.control_revision,
                               binary_sha256=hashlib.sha256(control.read_bytes()).hexdigest(), samples=control_samples)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(dict(output=str(args.output), summary=summary), indent=2))


if __name__ == '__main__':
    main()
