"""Measure clean, warm, SDK-edit and shared-native-edit Rust feedback in an isolated checkout."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

from capture import provenance, run, write_json

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--work-root', type=Path, default=Path('/var/tmp'))
    args = parser.parse_args()
    assert not subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT), 'Benchmark requires committed source'
    identity = provenance(ROOT)
    root = Path(tempfile.mkdtemp(prefix='transit-build-feedback-', dir=args.work_root))
    checkout, scratch = root / 'src', root / 'tmp'
    scratch.mkdir()
    destination = ROOT / '.cache/build-feedback' / root.name
    destination.mkdir(parents=True)
    report = dict(version=1, **identity, cases=[], completed=False,
                  cache_condition='Fresh checkout and Zig caches; pinned Nix binary substitutes remain available',
                  work_directory=str(root), local_sdk_warm_target_seconds=180)
    def checkpoint():
        write_json(destination / 'report.json', report)
    checkpoint()
    try:
        subprocess.run(['git', 'clone', '--quiet', '--local', '--no-hardlinks', str(ROOT), str(checkout)], check=True)
        subprocess.run(['git', 'checkout', '--quiet', '--detach', identity['revision']], cwd=checkout, check=True)
        environment = {key: value for key, value in os.environ.items()
                       if not key.startswith('TRANSIT_') and key not in {'CI_NATIVE_BUNDLE_DIR', 'CI_FEEDBACK_TASK', 'ZIG_GLOBAL_CACHE_DIR', 'ZIG_LOCAL_PKG_DIR'}}
        shell = ['nix', 'develop', '.#ci-bindings', '--command', 'env', f'TMPDIR={scratch}',
                 f'ZIG_GLOBAL_CACHE_DIR={root / "zig"}', f'ZIG_LOCAL_PKG_DIR={root / "zig/p"}']
        preparation = {}
        run([*shell, 'just', 'ci::dependencies'], cwd=checkout, env=environment,
            log=destination / 'prepare.log', result=preparation).check_returncode()
        report['preparation'] = preparation
        edits = {'sdk-edit': 'sdks/rust/transit-client/src/lib.rs',
                 'shared-native-edit': 'packages/zig/transit-client/src/root.zig'}
        for name in ('clean', 'warm-noop', 'sdk-edit', 'shared-native-edit'):
            # Independent edit cases share only compilation caches. Restore source
            # from the exact benchmark commit before applying the next mutation.
            subprocess.run(['git', 'reset', '--quiet', '--hard', identity['revision']], cwd=checkout, check=True)
            if name in edits:
                path = checkout / edits[name]
                with path.open('a') as output:
                    output.write('\n// Isolated build-feedback input mutation.\n')
            entry = dict(case=name, **provenance(checkout), source_edit=edits.get(name), completed=False)
            report['cases'].append(entry)
            checkpoint()
            before = set((checkout / '.cache/checks/phases').glob('*/*.json'))
            started = time.monotonic()
            try:
                run([*shell, 'just', 'bindings::feedback', 'rust'], cwd=checkout, env=environment,
                    log=destination / f'{name}.log', result=entry).check_returncode()
            finally:
                entry['seconds'] = round(time.monotonic() - started, 3)
                entry['warm_target_met'] = entry['completed'] and entry['exit_code'] == 0 and name != 'clean' and entry['seconds'] <= 180
                phases = destination / 'phases' / name
                for source in set((checkout / '.cache/checks/phases').glob('*/*.json')) - before:
                    target = phases / source.parent.name / source.name
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(source, target)
                checkpoint()
        report['completed'] = True
    finally:
        checkpoint()
        print(f'Build feedback evidence: {destination / "report.json"}', flush=True)
        if summary := os.getenv('GITHUB_STEP_SUMMARY'):
            with open(summary, 'a') as output:
                output.write('\n### Rust build feedback experiments\n\n| Case | Seconds | Passed | Warm target |\n| --- | ---: | --- | --- |\n')
                for entry in report['cases']:
                    output.write(f"| {entry['case']} | {entry.get('seconds')} | {entry['completed'] and entry.get('exit_code') == 0} | {entry.get('warm_target_met')} |\n")
        if report['completed']:
            shutil.rmtree(root)
        else:
            print(f'Incomplete benchmark; private checkout retained: {root}', flush=True)


if __name__ == '__main__':
    main()
