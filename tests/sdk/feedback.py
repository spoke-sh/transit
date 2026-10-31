"""Run one installed SDK boundary, retaining phase timings and the exact scope."""
import argparse
import subprocess

from harness.native_artifacts import prepare
from harness.phases import phase, recorder
from runner.capture import run
from runner.paths import ROOT
from sdk.consumer_registry import RAW_RUNNERS, RUNNERS
from sdk.sdk_station_runner import run as station_schedule


def execute(language, scope):
    if language == 'go' and scope in {'station', 'catalog'}:
        raise ValueError('Go currently owns the raw client boundary only')
    with phase('sdk-feedback', language) as evidence:
        evidence['scope'] = scope
        def task(name):
            run(['just', name], cwd=ROOT, log=recorder().directory / f'{scope}.log', result={}).check_returncode()
        if scope == 'full':
            task('bindings::python-test' if language == 'python' else f'bindings::{language}-sdk-test')
        elif scope == 'catalog':
            task(f'bindings::direct-catalog-{language}')
        else:
            task(f'bindings::{language}-build')
            clients, _ = prepare('clients', 'Debug')
            authority, _ = prepare('authority', 'Debug' if language == 'go' else 'ReleaseSafe')
            artifacts = ROOT / '.cache/bindings/Debug' / ('wheels' if language == 'python' else language)
            inputs = (str(authority / 'bin/transit-node'), str(clients / 'bin/transit-admin'),
                      str(clients / 'lib/libtransit_client.so'), artifacts)
            if scope == 'raw':
                RAW_RUNNERS[language](*inputs)
            else:
                RUNNERS[language](*inputs, execute=station_schedule)
    print(f'SDK feedback passed: {language}/{scope}; phase evidence: {recorder().directory}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('language', choices=RAW_RUNNERS)
    parser.add_argument('--scope', choices=('raw', 'station', 'catalog', 'full'), default='raw')
    args = parser.parse_args()
    if args.language == 'go' and args.scope in {'station', 'catalog'}:
        parser.error('Go currently owns the raw client boundary only')
    try:
        execute(args.language, args.scope)
    except subprocess.CalledProcessError as error:
        raise SystemExit(error.returncode if error.returncode > 0 else 128 - error.returncode)


if __name__ == '__main__':
    main()
