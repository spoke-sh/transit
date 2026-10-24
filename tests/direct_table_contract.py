"""Independent signed request vectors and reflected direct Table envelope checks."""
import copy
import base64
import hashlib
import json
import struct
from pathlib import Path
import sys
import tempfile

import jsonschema
from serving import Key

root = Path(__file__).resolve().parents[1]
definition = "b840e71bde2e36fc2c83d773e3bb13bbf9c44c15d3d46b955beed1f8fda84a00"
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
    "delegation": None,
    "closure": None,
    "borrow": None,
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
    read_binding = {
        "definition": definition, "connection": request_input["connection"], "executor": 9,
        "interpretation": {"object": {"scope": request_input["connection"]["scope"], "branch": 1, "object": 7}, "revision": 2, "digest": [3] * 32},
        "expected": {"partition": 9, "next_lsn": 10},
        "selection": "exact",
        "owner": {"scope": request_input["connection"]["scope"], "principal": 4, "operation": 2**64 - 1},
        "retention": "snapshot", "purpose": [11] * 32,
    }
    delegation_context = hashlib.sha256(b"transit.table.read-delegation.v1\0" + canonical(read_binding)).digest()
    delegated_claim = {**claim, "context": list(delegation_context)}
    delegated_proof = {"claim": delegated_claim, "signature": key.sign(hashlib.sha256(b"transit.authorization.subject.v1\0" + canonical(delegated_claim)).digest())}
    delegated_input = {**request_input, "action": {"pin": {"object": read_binding["interpretation"]["object"], "owner": read_binding["owner"], "expected": read_binding["expected"], "selection": "exact"}}, "delegation": {"binding": read_binding, "proof": delegated_proof}}
    executor_context = hashlib.sha256(b"transit.table.direct.request.v1\0" + canonical(delegated_input)).digest()
    executor_claim = {**claim, "principal": 9, "context": list(executor_context)}
    executor = Key(Path(directory), "public-executor-key", 31)
    delegated_request = {**delegated_input, "proof": {"claim": executor_claim, "signature": executor.sign(hashlib.sha256(b"transit.authorization.subject.v1\0" + canonical(executor_claim)).digest())}}
    # Canonical retained grant: explicit definition/epoch and original signature.
    # Redundant object/claim scope fields are constrained to the connection.
    retained_grant = (
        b"TRG1" + bytes.fromhex(definition)
        + struct.pack("<QQQQQQBQ", 42, 3, 2**64 - 1, 1, 5, 4, 0, 0)
        + struct.pack("<QQQ", 9, 7, 2) + bytes([3] * 32)
        + struct.pack("<QQQBB", 9, 10, 2**64 - 1, 0, 1) + bytes([11] * 32)
        + struct.pack("<Q", 1) + delegation_context + bytes(delegated_proof["signature"])
    )
    assert len(retained_grant) == 311
    delegated_fixture = {"request": delegated_request, "caller_key": public_key, "executor_key": executor.public,
                         "retained_grant": base64.b64encode(retained_grant).decode()}
    borrow_binding = {"executor": 10, "target": {"snapshot": {"object": read_binding["interpretation"]["object"], "handle": {"owner": read_binding["owner"], "content": {"bytes": 128, "sha256": [12] * 32}}}}, "purpose": [13] * 32}
    borrow_context = hashlib.sha256(b"transit.table.borrowed-read.v1\0" + retained_grant + canonical(borrow_binding)).digest()
    borrow_claim = {**delegated_claim, "context": list(borrow_context)}
    borrow = {"binding": borrow_binding, "signature": key.sign(hashlib.sha256(b"transit.authorization.subject.v1\0" + canonical(borrow_claim)).digest())}
    borrowed_input = {**delegated_input, "action": {"snapshot": borrow_binding["target"]["snapshot"]}, "borrow": borrow}
    borrower_claim = {**claim, "principal": 10, "context": list(hashlib.sha256(b"transit.table.direct.request.v1\0" + canonical(borrowed_input)).digest())}
    borrower = Key(Path(directory), "public-borrower-key", 32)
    borrowed_request = {**borrowed_input, "proof": {"claim": borrower_claim, "signature": borrower.sign(hashlib.sha256(b"transit.authorization.subject.v1\0" + canonical(borrower_claim)).digest())}}
    borrowed_fixture = {"request": borrowed_request, "caller_key": public_key, "executor_key": borrower.public}
    current_input = {
        **request_input,
        "action": {"read_current": {
            "namespace": 1, "interpretation": read_binding["interpretation"],
            "expected": read_binding["expected"],
            "selection": {"rows": {
                "after": {"origin": 2**64 - 1, "operation": 2**64 - 2, "ordinal": 2**32 - 1},
                "limits": {"rows": 3, "encoded_bytes": 4096},
            }},
        }},
    }
    current_context = hashlib.sha256(b"transit.table.direct.request.v1\0" + canonical(current_input)).digest()
    current_claim = {**claim, "context": list(current_context)}
    current_request = {**current_input, "proof": {
        "claim": current_claim,
        "signature": key.sign(hashlib.sha256(b"transit.authorization.subject.v1\0" + canonical(current_claim)).digest()),
    }}
    current_fixture = {"request": current_request, "public_key": public_key}

request = {**request_input, "proof": {"claim": claim, "signature": signature}}
fixture = {
    "request": request,
    "context": list(context),
    "public_key": public_key,
    "binary": {"bytes": [0, 255, 128, 1], "base64": "AP+AAQ=="},
}
validator = jsonschema.Draft202012Validator({**schema, "$ref": "#/$defs/Request"})
validator.validate(request)
validator.validate(delegated_request)
validator.validate(borrowed_request)
validator.validate(current_request)
for field in ("interpretation", "expected", "selection"):
    invalid = copy.deepcopy(current_request)
    del invalid["action"]["read_current"][field]
    assert not validator.is_valid(invalid), field
for field in ("definition", "proof", "nonce", "delegation"):
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
persist(root / "packages/zig/transit-catalog/src/fixtures/direct-table-delegation-v1.json",
        (json.dumps(delegated_fixture, ensure_ascii=False, indent=2) + "\n").encode())

persist(root / "packages/zig/transit-catalog/src/fixtures/direct-table-borrow-v1.json",
        (json.dumps(borrowed_fixture, ensure_ascii=False, indent=2) + "\n").encode())
persist(root / "packages/zig/transit-catalog/src/fixtures/direct-table-current-read-v1.json",
        (json.dumps(current_fixture, ensure_ascii=False, indent=2) + "\n").encode())

# The native catalog intent uses its fixed 63-byte UTF-8 Name representation;
# the saved envelope uses the public JSON writer's exact array representation.
native_intent = {"namespace": 1, "name": {"len": 6, "bytes": "events" + "\0" * 57}, "action": {"drop": {}}}
intent_digest = hashlib.sha256(b"transit.catalog.ddl.intent.v1\0" + canonical(native_intent)).digest()
target = {"scope": request_input["connection"]["scope"], "branch": 1, "object": 7}
binding = {
    "definition": definition,
    "identity": {"scope": target["scope"], "principal": 4, "operation": 2**64 - 1},
    "target": target, "action": "drop",
    "expected_definition": {"object": target, "revision": 2, "digest": [3] * 32},
    "expected_data": {"partition": 9, "next_lsn": 10}, "intent": list(intent_digest), "prerequisite": None,
}
saved = {"definition": definition, "connection": request_input["connection"], "work": {"ddl": {"binding": binding, "namespace": 1, "name": "events", "action": {"drop": {}}}}}
saved_validator = jsonschema.Draft202012Validator({**schema, "$ref": "#/$defs/SavedIntent"})
saved_validator.validate(saved)
for field in ("definition", "connection", "work"):
    invalid = copy.deepcopy(saved)
    del invalid[field]
    assert not saved_validator.is_valid(invalid), field
saved_bytes = b"TDI1" + bytes.fromhex(definition) + canonical(saved)
persist(root / "packages/zig/transit-catalog/src/fixtures/direct-table-intent-v1.json",
        (json.dumps({"saved": saved, "base64": base64.b64encode(saved_bytes).decode()}, ensure_ascii=False, indent=2) + "\n").encode())
print("Direct Table: reflected envelopes, exact wide integers, mandatory proof/definition, independent signed request and saved intent passed.")
