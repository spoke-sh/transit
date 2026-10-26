"""Run the declared small growth matrix; preserve every repeat independently."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import time

from runner.paths import ROOT


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('growing')
    parser.add_argument('node')
    parser.add_argument('caller')
    parser.add_argument('--repeat', type=int, default=2)
    parser.add_argument('--output', type=Path, default=ROOT / '.cache/verification/scale')
    args = parser.parse_args()
    if not 1 <= args.repeat <= 10:
        parser.error('repeat must be 1..10')
    matrix = json.loads((ROOT / 'tests/performance/scale/scale.json').read_text())['qualification_matrix']
    args.output.mkdir(parents=True, exist_ok=True)
    evidence = dict(version=1, status='inconclusive', repeat=args.repeat, samples=[],
                    revision=subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip())
    try:
        for repeat in range(args.repeat):
            for case in matrix:
                destination = args.output / f"{case['name']}-{repeat}.json"
                if case['kind'] == 'authority':
                    command = [sys.executable, '-B', str(ROOT / 'tests/storage/local/growing.py'), args.growing]
                else:
                    command = [sys.executable, '-B', str(ROOT / 'tests/runner/launch.py'), str(ROOT / 'tests/performance/load/growing_load.py'), args.node, args.caller]
                command += [*case['args'], '--output', str(destination)]
                started = time.monotonic()
                subprocess.run(command, cwd=ROOT, check=True, timeout=1800)
                result = json.loads(destination.read_text())
                assert result['status'] == 'passed', destination
                if case['kind'] == 'authority':
                    for phase in result['phases']:
                        assert phase['cache_bytes'] > 0
                        assert phase['cache_bytes'] == result['phases'][0]['cache_bytes']
                    if case.get('exceeds_cache'):
                        assert result['phases'][0]['retained_value_bytes'] > result['phases'][0]['cache_bytes']
                    assert all(phase['created_pages'] == 0 for phase in result['phases'] if phase['phase'] in ('recover', 'trim_recover'))
                evidence['samples'].append(dict(case=case['name'], repeat=repeat, artifact=destination.name,
                                                seconds=round(time.monotonic() - started, 3)))
        evidence['status'] = 'passed'
    finally:
        (args.output / 'evidence.json').write_text(json.dumps(evidence, indent=2) + '\n')


if __name__ == '__main__':
    main()
