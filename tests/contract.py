"""Check the committed contract is exactly regenerated from the public Zig types."""
import json
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
actual = sys.stdin.buffer.read()
growth = sys.argv[1:] == ["--growth"]
assert not sys.argv[1:] or growth, "unsupported contract check arguments"
expected = (root / ("contracts/transit-v3.schema.json" if growth else "contracts/transit-v2.schema.json")).read_bytes()
if actual != expected:
    raise SystemExit("Public contract drift: run just contract::generate and review the change")
contract = json.loads(actual)
if growth:
    assert contract["x-transit"]["version"] == 3
    assert contract["x-transit"]["request_domain"] == "transit.request.v3\0"
    assert contract["x-transit"]["query_domain"] == "transit.query.v3\0"
    assert set(contract["$defs"]) == {"Request", "SignedRequest", "Query", "SignedQuery", "Response", "Receipt", "ErrorResponse"}
    principal = contract["$defs"]["Request"]["properties"]["principal"]
    assert principal["x-transit-bits"] == 64 and principal["maximum"] == 2**53 - 1
    print("Growing-profile development JSON Schema matches the Zig contract.")
    raise SystemExit(0)
assert contract["x-transit"]["version"] == 2
assert bytes.fromhex(contract["x-transit"]["signing_domain_hex"]) == b"rey.transit.request.v2\0"
assert set(contract["$defs"]) == {"Request", "SignedRequest", "View", "Receipt", "ErrorResponse", "InspectionQuery", "SignedInspectionQuery", "InspectionPage", "StateCommand", "StateQuery", "SignedStateQuery", "StatePage", "DeliveryQuery", "SignedDeliveryQuery", "DeliveryStatus"}
print("Public protocol JSON Schema matches the Zig contract.")
