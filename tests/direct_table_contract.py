"""Independent signed request vectors and reflected direct Table envelope checks."""
import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile

import jsonschema
from serving import Key

root = Path(__file__).resolve().parents[1]
definition = "ca3da62f10ff4dbe279871b62429d49d235b7f821c23cf0dee497b02c683485b"
raw = sys.stdin.buffer.read()
schema = json.loads(raw)
jsonschema.Draft202012Validator.check_schema(schema)


def canonical(value):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode()


request_input = {
    "definition": definition,
    "connection": {
        "scope": {"realm": 42, "resource": 3, "catalog": 2**64 - 1},
        "branch": 1, "audience": 5, "principal": 4, "role": None,
    },
    "nonce": [7] * 16,
    "action": {"lookup": {"namespace": 1, "name": "evénts"}},
}
context = hashlib.sha256(b"transit.table.direct.request.v1\0" + canonical(request_input)).digest()
claim = {
    "definition": definition, "realm": 42, "principal": 4,
    "credential_epoch": 1, "role": None, "audience": 5,
    "context": list(context),
}
claim_digest = hashlib.sha256(b"transit.authorization.subject.v1\0" + canonical(claim)).digest()
with tempfile.TemporaryDirectory(prefix="transit-direct-contract-") as directory:
    key = Key(Path(directory), "public-test-key", 9)
    signature = key.sign(claim_digest)
    public_key = key.public
request = {**request_input, "proof": {"claim": claim, "signature": signature}}
fixture = {
    "request": request,
    "context": list(context),
    "public_key": public_key,
    "binary": {"bytes": [0, 255, 128, 1], "base64": "AP+AAQ=="},
}
validator = jsonschema.Draft202012Validator({**schema, "$ref": "#/$defs/Request"})
validator.validate(request)
for field in ("definition", "proof", "nonce"):
    invalid = copy.deepcopy(request)
    del invalid[field]
    assert not validator.is_valid(invalid), field
invalid = copy.deepcopy(request)
invalid["connection"]["scope"]["catalog"] = str(2**64 - 1)
assert not validator.is_valid(invalid)
invalid = copy.deepcopy(request)
invalid["nonce"] = "".join(chr(x) for x in invalid["nonce"])
assert not validator.is_valid(invalid)
invalid = copy.deepcopy(request)
invalid["definition"] = "0" * 64
assert not validator.is_valid(invalid)


def persist(path, content):
    if "--write" in sys.argv:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
    else:
        assert path.read_bytes() == content, f"Direct Table contract drift: {path}"


persist(root / "contracts/direct-table-v1.schema.json", raw)
persist(root / "packages/zig/transit-catalog/src/fixtures/direct-table-v1.json",
        (json.dumps(fixture, ensure_ascii=False, indent=2) + "\n").encode())
print("Direct Table: reflected envelopes, exact wide integers, mandatory proof/definition, independent signed request passed.")
