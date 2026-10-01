"""Repeat installed Rust runner destruction with fresh malformed inputs."""
import argparse
from pathlib import Path
import tempfile
from rust_station_sdk import run
from sdk_station_runner import run as schedule


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cases', type=int, default=128)
    args = parser.parse_args()
    if not 1 <= args.cases <= 1024:
        parser.error('--cases must be in 1..1024')
    def batches(node, cli, library, install, label):
        # This is a host-lifetime proof, not a storage-capacity proof. Install
        # the consumer once, then verify independent bounded histories without
        # raising Ursula's quota or deleting accepted work inside a history.
        with tempfile.TemporaryDirectory(prefix='transit-rust-lifetime-') as temporary:
            consumer = install(Path(temporary))
            completed = 0
            while completed < args.cases:
                count = min(32, args.cases - completed)
                schedule(node, cli, library, lambda _: consumer, label,
                         decode_block_repetitions=count, failures_only=True)
                completed += count
                print(f'Rust lifetime: {completed}/{args.cases} cases verified with joined fixture cleanup.', flush=True)

    run('zig-out/bin/transit-node', 'zig-out/bin/rey-cli',
        'zig-out/lib/libtransit_client.so', '.cache/bindings/rust', execute=batches)


if __name__ == '__main__':
    main()
