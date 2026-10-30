"""Check the committed contract is exactly regenerated from the public Zig types."""
from runner.paths import ROOT
import json
from pathlib import Path
import sys

root = ROOT
actual = sys.stdin.buffer.read()
if sys.argv[1:] == ["--data-lifecycle"]:
    import copy
    import jsonschema
    expected = (root / "contracts/data-lifecycle-v1.schema.json").read_bytes()
    assert actual == expected, "Data lifecycle schema drift: run just contract::generate"
    schema = json.loads(actual)
    jsonschema.Draft202012Validator.check_schema(schema)
    validator = jsonschema.Draft202012Validator(schema)
    fixture = json.loads((root / "packages/zig/transit-protocol/src/fixtures/data-lifecycle-v1.json").read_text())
    validator.validate(fixture)
    for path in (("binding",), ("commit", "binding"), ("snapshot",), ("resource_initialization",),
                 ("stream_queue", "append", "append", "target"),
                 ("stream_queue", "offset_commit", "coverage", "cut", "target"),
                 ("stream_queue", "settlement", "settlement", "lease", "target")):
        changed = copy.deepcopy(fixture)
        item = changed
        for name in path:
            item = item[name]
        del item['definition']
        assert not validator.is_valid(changed), f"missing definition accepted at {path}"
    changed = copy.deepcopy(fixture)
    changed['binding']['definition'] = '0' * 64
    assert not validator.is_valid(changed)
    assert fixture['binding']['identity']['operation'] == 2**64 - 1
    assert fixture['source_cut']['checkpoint_lsn'] < fixture['source_cut']['accepted']['next_lsn']
    print("Data lifecycle: reflected schema, independent fixture and mandatory definitions passed.")
    raise SystemExit(0)
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
assert set(contract["$defs"]) == {"Request", "SignedRequest", "CommandEnvelope", "BlockResponse", "Query", "SignedQuery", "Response", "Receipt", "ErrorResponse", "PayloadRequest", "PayloadResponse"}
envelope = contract['$defs']['CommandEnvelope']['properties']
assert 'definition' in envelope['request']['required']
body = envelope['blocks']['anyOf'][0]
assert body['type'] == 'string' and body['contentEncoding'] == 'base64'
assert body['maxLength'] == 174764
assert set(route['path'] for route in contract['x-transit']['routes']) == {'/v1/command', '/v1/query', '/v1/blocks', '/v1/payload'}
payload_request = contract['$defs']['PayloadRequest']
assert set(payload_request['required']) == {'operation', 'proof', 'body'}
assert payload_request['properties']['body']['contentEncoding'] == 'base64'
assert 'definition' in payload_request['properties']['proof']['properties']['claim']['required']
assert 'definition' in contract['$defs']['PayloadResponse']['required']
principal = contract["$defs"]["Request"]["properties"]["principal"]
assert principal["x-transit-bits"] == 64 and principal["maximum"] == 2**53 - 1
print("Native v1 JSON Schema matches the Zig contract.")
