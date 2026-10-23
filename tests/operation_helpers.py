"""Locate the private native library test driver, never the installed CLI."""
import os
from pathlib import Path


def operations():
    path = Path(os.environ.get('TEST_TRANSIT_OPERATIONS',
                Path(__file__).resolve().parents[1] / 'zig-out/tests/operation-fixture'))
    if not path.is_file():
        raise RuntimeError('Build the test-operation-fixture target before this proof')
    return str(path.resolve())
