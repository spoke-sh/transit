"""Check the committed contract is exactly regenerated from the public Zig types."""
import json
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
actual = sys.stdin.buffer.read()
expected = (root / "contracts/transit-v2.schema.json").read_bytes()
if actual != expected:
    raise SystemExit("Public contract drift: run just generate-contract and review the change")
contract = json.loads(actual)
assert contract["x-transit"]["version"] == 2
assert bytes.fromhex(contract["x-transit"]["signing_domain_hex"]) == b"rey.transit.request.v2\0"
assert set(contract["$defs"]) == {"Request", "SignedRequest", "View", "Receipt", "ErrorResponse"}
print("Public protocol JSON Schema matches the Zig contract.")
