"""Repeat installed Rust runner destruction with fresh malformed inputs."""
import argparse
from functools import partial
from rust_station_sdk import run
from sdk_station_runner import run as schedule


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cases', type=int, default=128)
    args = parser.parse_args()
    if not 1 <= args.cases <= 1024:
        parser.error('--cases must be in 1..1024')
    run('zig-out/bin/transit-node', 'zig-out/bin/rey-cli',
        'zig-out/lib/libtransit_client.so', '.cache/bindings/rust',
        execute=partial(schedule, decode_block_repetitions=args.cases, failures_only=True))


if __name__ == '__main__':
    main()
