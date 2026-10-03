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

# Preparation failure uses a different identity-bound record, not an admission
# rejection. This independent encoding includes exact maximum+1 byte evidence.
preparation_layout = struct.Struct("<4s3QBB2B32s2B64sBQB B32sBQB B32s")
assert preparation_layout.size == 216
field = b"request.body_bytes"
cause = b"HttpRequestTooLarge"
preparation = {"record": preparation_layout.pack(b"EXP1", 7, 2**64 - 1, 12, 2, 3,
    len(field), 0, field, len(cause), 0, cause, 3, 65536, 0, 0, b"",
    3, 65537, 0, 0, b"").hex()}
preparation_path = root / "packages/zig/transit-exchange/src/preparation-failure-fixtures.json"
preparation_expected = json.dumps(preparation, indent=2) + "\n"
if "--write" in sys.argv:
    preparation_path.write_text(preparation_expected)
else:
    assert preparation_path.read_text() == preparation_expected, "EXP1 fixture drifted; review its owning contract"
    print("Preparation failures: independent 216-byte identity and original field/check/value fixture passed.")
