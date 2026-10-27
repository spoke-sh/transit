"""Installed Station callbacks for all five authenticated negative query results."""
import argparse
import importlib
import os
from pathlib import Path

import sdk.sdk_station_runner as sdk_station_runner

FAMILIES = ('python', 'node', 'rust', 'ruby', 'c', 'java', 'dotnet', 'beam')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--native-prefix', type=Path, required=True)
    parser.add_argument('--node', type=Path, required=True)
    parser.add_argument('--artifacts', type=Path, default=Path('.cache/bindings/Debug'))
    parser.add_argument('--family', choices=FAMILIES, action='append')
    args = parser.parse_args()
    native = args.native_prefix.resolve()
    artifacts = args.artifacts.resolve()
    previous = os.environ.get('TRANSIT_TEST_QUERY_FAILURES_ONLY')
    os.environ['TRANSIT_TEST_QUERY_FAILURES_ONLY'] = '1'
    try:
        for family in args.family or FAMILIES:
            package = 'wheels' if family == 'python' else family
            importlib.import_module(f'sdk.consumers.{family}.{family}_station_sdk').run(
                str(args.node.resolve()), str(native / 'bin/transit-admin'),
                str(native / 'lib/libtransit_client.so'), str(artifacts / package),
                execute=sdk_station_runner.run)
    finally:
        if previous is None:
            os.environ.pop('TRANSIT_TEST_QUERY_FAILURES_ONLY', None)
        else:
            os.environ['TRANSIT_TEST_QUERY_FAILURES_ONLY'] = previous


if __name__ == '__main__':
    main()
