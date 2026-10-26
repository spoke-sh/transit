"""Current Station ABIs: native/port ownership, codecs, capture and host loss.

Installed language examples and cross-language continuation run through the
sdk-interop and per-language SDK tasks, against this same current authority.
"""
import os
import sys


def run(node, cli, library, raw_library, host):
    # A single CPU exposes native pool retirement races hidden by spare workers.
    affinity = os.sched_getaffinity(0) if hasattr(os, 'sched_getaffinity') else None
    try:
        if affinity:
            os.sched_setaffinity(0, {min(affinity)})
        from sdk.station_codec_host import run as codecs
        from sdk.station_growing_abi import run as turns
        from sdk.station_query_abi import run as capture
        codecs(host, library)
        turns(node, cli, library, raw_library, host)
        capture(node, cli, library, raw_library, host)
        from runtime.station.station_materialization import run as materialization
        from pathlib import Path
        import tempfile
        with tempfile.TemporaryDirectory(prefix="transit-materialization-libraries-") as directory:
            libraries = Path(directory)
            for name, source in (("station", library), ("client", raw_library)):
                (libraries / f"libtransit_{name}.so").symlink_to(Path(source).resolve())
            materialization(node, cli, libraries)
    finally:
        if affinity:
            os.sched_setaffinity(0, affinity)


if __name__ == '__main__':
    run(*sys.argv[1:])
