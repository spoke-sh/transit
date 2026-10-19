"""Check the committed contract is exactly regenerated from the public Zig types."""
import json
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[1]
actual = sys.stdin.buffer.read()
if sys.argv[1:] == ["--installation"]:
    expected = (root / "contracts/application-installation-v1.schema.json").read_bytes()
    if actual != expected:
        raise SystemExit("Application installation contract drift: run just contract::generate")
    assert json.loads(actual)["$id"] == "urn:transit:application-installation:v1"
    print("Application installation schema matches the public client types.")
    raise SystemExit(0)
assert not sys.argv[1:], "unsupported contract check arguments"
expected = (root / "contracts/transit-v1.schema.json").read_bytes()
if actual != expected:
    raise SystemExit("Public contract drift: run just contract::generate and review the change")
contract = json.loads(actual)
assert contract["x-transit"]["version"] == 1
assert contract["x-transit"]["request_domain"] == "transit.request.v1\0"
assert contract["x-transit"]["query_domain"] == "transit.query.v1\0"
definition = contract["x-transit"]["definition"]
assert len(definition) == 64 and all(c in '0123456789abcdef' for c in definition)
for name in ("Request", "Query", "Response"):
    assert contract["$defs"][name]["properties"]["definition"]["enum"] == [definition]
assert "definition" in contract["$defs"]["Response"]["required"]
assert set(contract["$defs"]) == {"Request", "SignedRequest", "CommandEnvelope", "BlockResponse", "Query", "SignedQuery", "Response", "Receipt", "ErrorResponse"}
envelope = contract['$defs']['CommandEnvelope']['properties']
assert 'definition' in envelope['request']['required']
body = envelope['blocks']['anyOf'][0]
assert body['type'] == 'string' and body['contentEncoding'] == 'base64'
assert body['maxLength'] == 174764
assert set(route['path'] for route in contract['x-transit']['routes']) == {'/v1/command', '/v1/query', '/v1/blocks'}
principal = contract["$defs"]["Request"]["properties"]["principal"]
assert principal["x-transit-bits"] == 64 and principal["maximum"] == 2**53 - 1
print("Native v1 JSON Schema matches the Zig contract.")
