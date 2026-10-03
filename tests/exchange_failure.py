"""Independent EXF1 worker-input and retained-failure layouts (no Zig decoder)."""
import json
from pathlib import Path
import struct
import sys

root = Path(__file__).resolve().parents[1]
layout = struct.Struct("<4s5QBBQ4IBB96sBQQIQ")
assert layout.size == 197
cause = b"ConnectionResetByPeer"
common = (4, 0, 0, 0, 0, 0, 0, len(cause), 0, cause)
fixture = {
    "request": layout.pack(b"EXF1", 7, 2**64 - 1, 0, 0, 0, *common, 1, 0, 0, 0, 0).hex(),
    "record": layout.pack(b"EXF1", 7, 2**64 - 1, 2, 65536, 12, *common, 2, 19, 20, 3, 1024).hex(),
}
path = root / "packages/zig/transit-exchange/src/failure-fixtures.json"
expected = json.dumps(fixture, indent=2) + "\n"
if "--write" in sys.argv:
    path.write_text(expected)
else:
    assert path.read_text() == expected, "EXF1 fixtures drifted; review the current contract cutover"
    print("Exchange failures: independent 197-byte admitted-input and retained-record fixtures passed.")
