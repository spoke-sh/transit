"""Qualify release SDK artifacts through the existing isolated consumer owners."""
import argparse
import json
import os
from pathlib import Path

from sdk.consumer_registry import RAW_RUNNERS, RUNNERS


def run(packages, runtime, languages):
    packages, runtime = packages.resolve(), runtime.resolve()
    manifest = json.loads((packages / 'sdk-manifest.json').read_text())
    assert manifest['target'] in ('x86_64-linux-gnu.2.28', 'aarch64-linux-gnu.2.28')
    os.environ['TRANSIT_SDK_TEST_MANIFEST'] = str(packages / 'sdk-manifest.json')
    native = packages / 'native'
    node, admin = runtime / 'bin/transit-node', native / 'bin/transit-admin'
    for language in languages:
        artifacts = packages / ('wheels' if language == 'python' else language)
        RAW_RUNNERS[language](str(node), str(admin), str(native / 'lib/libtransit_client.so'), str(artifacts))
        if language in RUNNERS:
            RUNNERS[language](str(node), str(admin), str(native / 'lib/libtransit_client.so'),
                              str(artifacts), str(native / 'bin/transit-station-http-worker'))
        print(f'Release SDK installed raw/available Station consumers passed: {language}', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('packages', type=Path)
    parser.add_argument('runtime', type=Path)
    parser.add_argument('--language', action='append', choices=RAW_RUNNERS)
    args = parser.parse_args()
    run(args.packages, args.runtime, args.language or list(RAW_RUNNERS))
