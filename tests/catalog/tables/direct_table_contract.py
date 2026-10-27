"""Independent signed request vectors and reflected direct Table envelope checks."""
from runner.paths import ROOT
import copy
import base64
import hashlib
import json
import struct
from pathlib import Path
import sys
import tempfile

import jsonschema
from interfaces.http.serving import Key

root = ROOT
definition = "c28797e8d36912bfca884567bf72256f7304e0e64ed278b90894d7e22b311914"
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
    lower_key, upper_key, after_key = b"a\0", b"z\xff", b"m\0"
    interval_digest = hashlib.sha256(
        b"transit.table.key-range.v1\0" + bytes.fromhex(definition)
        + b"\x01" + struct.pack(">H", len(lower_key)) + lower_key
        + b"\x02" + struct.pack(">H", len(upper_key)) + upper_key
    ).digest()
    range_input = {**request_input, "action": {"key_range": {
        "snapshot": borrow_binding["target"]["snapshot"],
        "interval": {"lower": {"key": {"base64": base64.b64encode(lower_key).decode()}, "inclusive": True},
                     "upper": {"key": {"base64": base64.b64encode(upper_key).decode()}, "inclusive": False}},
        "after": {"source": borrow_binding["target"]["snapshot"]["handle"]["content"],
                  "interval": list(interval_digest), "after": {"base64": base64.b64encode(after_key).decode()}},
        "limits": {"rows": 3, "encoded_bytes": 4096},
    }}}
    range_claim = {**claim, "context": list(hashlib.sha256(b"transit.table.direct.request.v1\0" + canonical(range_input)).digest())}
    range_request = {**range_input, "proof": {"claim": range_claim,
        "signature": key.sign(hashlib.sha256(b"transit.authorization.subject.v1\0" + canonical(range_claim)).digest())}}
    range_fixture = {"request": range_request, "public_key": public_key}

    projection_source = borrow_binding["target"]["snapshot"]["handle"]["content"]
    projection_bytes = (b"transit.table.projected-cursor.v1\0" + bytes.fromhex(definition)
                        + struct.pack("<Q", projection_source["bytes"])
                        + bytes(projection_source["sha256"]) + bytes([3, 0, 2, 127]))
    projection_input = {**request_input, "action": {"column_scan": {
        "snapshot": borrow_binding["target"]["snapshot"], "columns": [0, 2, 127],
        "after": {"source": {"bytes": len(projection_bytes), "sha256": list(hashlib.sha256(projection_bytes).digest())},
                  "after": list(struct.pack(">QQI", 4, 10, 2))},
        "limits": {"rows": 3, "encoded_bytes": 4096},
    }}}
    projection_claim = {**claim, "context": list(hashlib.sha256(b"transit.table.direct.request.v1\0" + canonical(projection_input)).digest())}
    projection_request = {**projection_input, "proof": {"claim": projection_claim,
        "signature": key.sign(hashlib.sha256(b"transit.authorization.subject.v1\0" + canonical(projection_claim)).digest())}}
    projection_fixture = {"request": projection_request, "public_key": public_key}

    # Signing/cursor fixture only: schema-bound FQP1 admission is tested in Zig.
    filter_fingerprint = bytes([29] * 32)
    filter_bytes = (b"transit.table.filtered-cursor.v1\0" + bytes.fromhex(definition)
                    + struct.pack("<Q", projection_source["bytes"])
                    + bytes(projection_source["sha256"]) + filter_fingerprint)
    filter_input = {**request_input, "action": {"filter_scan": {
        "snapshot": borrow_binding["target"]["snapshot"],
        "plan": {"base64": base64.b64encode(b"FQP1-envelope-fixture").decode()},
        "fingerprint": list(filter_fingerprint),
        "after": {"source": {"bytes": len(filter_bytes), "sha256": list(hashlib.sha256(filter_bytes).digest())},
                  "after": list(struct.pack(">QQI", 4, 10, 2))},
        "limits": {"rows": 3, "encoded_bytes": 4096},
    }}}
    filter_claim = {**claim, "context": list(hashlib.sha256(b"transit.table.direct.request.v1\0" + canonical(filter_input)).digest())}
    filter_request = {**filter_input, "proof": {"claim": filter_claim,
        "signature": key.sign(hashlib.sha256(b"transit.authorization.subject.v1\0" + canonical(filter_claim)).digest())}}
    filter_fixture = {"request": filter_request, "public_key": public_key}

    dependent_definition = {"object": {"scope": {"realm": 42, "resource": 9, "catalog": 8}, "branch": 1, "object": 99}, "revision": 2**64 - 1, "digest": [4] * 32}
    source_definition = {"object": {"scope": request_input["connection"]["scope"], "branch": 1, "object": 2**64 - 2}, "revision": 2**64 - 3, "digest": [3] * 32}
    edge = {"source": source_definition, "dependent": {"kind": "captured", "interpretation": dependent_definition}, "privileges": 1}
    dependency_binding = {"definition": definition, "connection": request_input["connection"], "operation": 2**64 - 1, "edge": edge, "action": "register", "authority": "dependent"}
    dependency_input = {**request_input, "action": {"dependency_operation": {"binding": dependency_binding, "command": "accept"}}}
    dependency_context = hashlib.sha256(b"transit.table.direct.request.v1\0" + canonical(dependency_input)).digest()
    dependency_claim = {**claim, "context": list(dependency_context)}
    dependency_request = {**dependency_input, "proof": {"claim": dependency_claim, "signature": key.sign(hashlib.sha256(b"transit.authorization.subject.v1\0" + canonical(dependency_claim)).digest())}}
    edge_bytes = (struct.pack(">6Q", 42, 3, 2**64 - 1, 1, 2**64 - 2, 2**64 - 3) + bytes([3] * 32)
                  + bytes([3]) + struct.pack(">6Q", 42, 9, 8, 1, 99, 2**64 - 1) + bytes([4] * 32) + struct.pack(">Q", 1))
    assert len(edge_bytes) == 169
    edge_digest = hashlib.sha256(b"transit.catalog.dependency.v1\0" + edge_bytes).digest()
    dependency_fixture = {"request": dependency_request, "public_key": public_key, "edge_digest": list(edge_digest)}
    resource_create = {"namespace": 1, "name": {"len": 6, "bytes": [*b"values", *([0] * 57)]}, "owner": 19, "writer": 17,
                       "owned": False, "deadline_ms": None, "history_ms": None,
                       "spec": {"kv": {"value_type": "int64", "nullable": False, "key_encoding": "native_bytes", "value_encoding": "fvl1"}}}
    resource_binding = {"definition": definition, "connection": request_input["connection"], "operation": 2**64 - 1,
                        "object": {"scope": request_input["connection"]["scope"], "branch": 1, "object": 2**64 - 2},
                        "expected": None, "action": {"create": resource_create}}
    resource_input = {**request_input, "action": {"resource_operation": {"binding": resource_binding, "command": "admit", "steps": 1, "signed_allocation": None}}}
    resource_claim = {**claim, "context": list(hashlib.sha256(b"transit.table.direct.request.v1\0" + canonical(resource_input)).digest())}
    resource_request = {**resource_input, "proof": {"claim": resource_claim, "signature": key.sign(hashlib.sha256(b"transit.authorization.subject.v1\0" + canonical(resource_claim)).digest())}}
    resource_definition = {"object": resource_binding["object"], "revision": 1, "namespace": 1, "name": resource_create["name"], "authorization": 20,
                           "resource": 21, "allocating_principal": 4, "allocation": {"sequence": 22}, "creation": resource_create}
    resource_digest = hashlib.sha256(b"transit.catalog.native-resource.v1\0" + canonical(resource_definition)).digest()
    resource_fixture = {"request": resource_request, "public_key": public_key, "resource": resource_definition, "digest": list(resource_digest)}

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
validator.validate(range_request)
validator.validate(projection_request)
validator.validate(filter_request)
for columns in ("abc", [0] * 129):
    invalid = copy.deepcopy(projection_request)
    invalid["action"]["column_scan"]["columns"] = columns
    assert not validator.is_valid(invalid)
validator.validate(dependency_request)
validator.validate(resource_request)
for field in ("definition", "connection", "operation", "object", "expected", "action"):
    invalid = copy.deepcopy(resource_request)
    del invalid["action"]["resource_operation"]["binding"][field]
    assert not validator.is_valid(invalid), field
for field in ("owned", "deadline_ms", "history_ms", "spec"):
    invalid = copy.deepcopy(resource_request)
    del invalid["action"]["resource_operation"]["binding"]["action"]["create"][field]
    assert not validator.is_valid(invalid), field
for field in ("definition", "connection", "operation", "edge", "action", "authority"):
    invalid = copy.deepcopy(dependency_request)
    del invalid["action"]["dependency_operation"]["binding"][field]
    assert not validator.is_valid(invalid), field
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
persist(root / "packages/zig/transit-catalog/src/fixtures/direct-table-filter-v1.json",
        (json.dumps(filter_fixture, ensure_ascii=False, indent=2) + "\n").encode())
persist(root / "packages/zig/transit-catalog/src/fixtures/direct-table-projection-v1.json",
        (json.dumps(projection_fixture, ensure_ascii=False, indent=2) + "\n").encode())
persist(root / "packages/zig/transit-catalog/src/fixtures/direct-table-key-range-v1.json",
        (json.dumps(range_fixture, ensure_ascii=False, indent=2) + "\n").encode())
persist(root / "packages/zig/transit-catalog/src/fixtures/direct-table-v1.json",
        (json.dumps(fixture, ensure_ascii=False, indent=2) + "\n").encode())
persist(root / "packages/zig/transit-catalog/src/fixtures/direct-table-delegation-v1.json",
        (json.dumps(delegated_fixture, ensure_ascii=False, indent=2) + "\n").encode())

persist(root / "packages/zig/transit-catalog/src/fixtures/direct-table-borrow-v1.json",
        (json.dumps(borrowed_fixture, ensure_ascii=False, indent=2) + "\n").encode())
persist(root / "packages/zig/transit-catalog/src/fixtures/direct-table-current-read-v1.json",
        (json.dumps(current_fixture, ensure_ascii=False, indent=2) + "\n").encode())
persist(root / "packages/zig/transit-catalog/src/fixtures/direct-dependency-v1.json",
        (json.dumps(dependency_fixture, ensure_ascii=False, indent=2) + "\n").encode())
persist(root / "packages/zig/transit-catalog/src/fixtures/direct-resource-v1.json",
        (json.dumps(resource_fixture, ensure_ascii=False, indent=2) + "\n").encode())

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

# Host references keep full-width storage identities in canonical decimal text.
# Native authorization identities remain bounded JSON integers.
native_reference = {
    "definition": definition, "connection": request_input["connection"],
    "namespace": 1, "binding": binding,
    "content": {"bytes": len(saved_bytes), "sha256": list(hashlib.sha256(saved_bytes).digest())},
}
host_reference = copy.deepcopy(native_reference)
host_reference["connection"]["scope"]["catalog"] = str(2**64 - 1)
host_reference["connection"]["branch"] = "1"
host_binding = host_reference["binding"]
host_binding["identity"]["scope"]["catalog"] = str(2**64 - 1)
host_binding["identity"]["operation"] = str(2**64 - 1)
for obj in (host_binding["target"], host_binding["expected_definition"]["object"]):
    obj["scope"]["catalog"] = str(2**64 - 1)
    obj["branch"] = str(obj["branch"])
    obj["object"] = str(obj["object"])
host_binding["expected_definition"]["revision"] = "2"
host_binding["expected_definition"]["digest"] = bytes([3] * 32).hex()
host_binding["expected_data"] = {"partition": "9", "next_lsn": "10"}
host_binding["intent"] = intent_digest.hex()
host_reference["content"] = {"bytes": str(len(saved_bytes)), "sha256": hashlib.sha256(saved_bytes).hexdigest()}
host_validator = jsonschema.Draft202012Validator({**schema, "$ref": "#/$defs/HostReference"})
host_validator.validate(host_reference)
host_action_validator = jsonschema.Draft202012Validator({**schema, "$ref": "#/$defs/HostAction"})
host_action_validator.validate({"admit": {"table": host_reference}})
def host_interpretation(value):
    result = copy.deepcopy(value)
    result["object"]["scope"]["catalog"] = str(result["object"]["scope"]["catalog"])
    for field in ("branch", "object"):
        result["object"][field] = str(result["object"][field])
    result["revision"] = str(result["revision"])
    result["digest"] = bytes(result["digest"]).hex()
    return result


host_edge = {"source": host_interpretation(source_definition),
             "dependent": {"kind": "captured", "interpretation": host_interpretation(dependent_definition)}, "privileges": 1}
host_dependency = {"definition": definition, "connection": host_reference["connection"], "operation": str(2**64 - 1),
                   "edge": host_edge, "action": "register", "authority": "dependent"}
host_dependency_action = {"dependencies": {"operation": {"binding": host_dependency, "command": "accept"}}}
host_action_validator.validate(host_dependency_action)
for field in ("definition", "connection", "operation", "edge", "action", "authority"):
    missing = copy.deepcopy(host_dependency_action)
    del missing["dependencies"]["operation"]["binding"][field]
    assert not host_action_validator.is_valid(missing), field
numeric_dependency_operation = copy.deepcopy(host_dependency_action)
numeric_dependency_operation["dependencies"]["operation"]["binding"]["operation"] = 2**64 - 1
assert not host_action_validator.is_valid(numeric_dependency_operation)
dependency_cursor = {"definition": definition, "connection": host_reference["connection"],
                     "selection": {"dependents": host_edge["source"]["object"]}, "authority": "dependent",
                     "position": {"partition": str(2**64 - 1), "next_lsn": str(2**64 - 1)}, "after": edge_digest.hex()}
host_action_validator.validate({"dependencies": {"page": {"selection": dependency_cursor["selection"],
                                                         "authority": "dependent", "cursor": dependency_cursor}}})
host_resource = {"definition": definition, "connection": host_reference["connection"], "operation": str(2**64 - 1),
                 "object": host_edge["source"]["object"], "expected": None, "action": {"create": {
                     "namespace": 1, "name": "named_document", "owner": 19, "writer": 17, "owned": False,
                     "deadline_ms": None, "history_ms": None, "spec": {"document": {
                         "document": str(2**64 - 1), "type_revision": 1,
                         "limits": {"record_bytes": 4096, "staging_bytes": str(2**64 - 1), "staging_records": 4}}}}}}
host_resource_action = {"resources": {"operation": {"binding": host_resource, "command": "execute", "steps": 64}}}
host_action_validator.validate(host_resource_action)
for field in ("definition", "connection", "operation", "object", "expected", "action"):
    missing = copy.deepcopy(host_resource_action)
    del missing["resources"]["operation"]["binding"][field]
    assert not host_action_validator.is_valid(missing), field
numeric_document = copy.deepcopy(host_resource_action)
numeric_document["resources"]["operation"]["binding"]["action"]["create"]["spec"]["document"]["document"] = 2**64 - 1
assert not host_action_validator.is_valid(numeric_document)
host_namespace = {"definition": definition, "connection": host_reference["connection"], "operation": str(2**64 - 1),
                  "namespace": 43, "expected": None, "action": {"create": {"name": "host_namespace", "owner": 1}}}
host_namespace_action = {"administration": {"preview_namespace": host_namespace}}
host_action_validator.validate(host_namespace_action)
missing_namespace_definition = copy.deepcopy(host_namespace_action)
del missing_namespace_definition["administration"]["preview_namespace"]["definition"]
assert not host_action_validator.is_valid(missing_namespace_definition)
numeric_namespace_operation = copy.deepcopy(host_namespace_action)
numeric_namespace_operation["administration"]["preview_namespace"]["operation"] = 2**64 - 1
assert not host_action_validator.is_valid(numeric_namespace_operation)
host_cursor = {"definition": definition, "connection": host_reference["connection"], "selection": {"tables": 1},
               "position": {"partition": "9", "next_lsn": str(2**64 - 1)}, "after": str(2**64 - 1)}
host_listing = {"catalog": {"tables": {"namespace": 1, "cursor": host_cursor}}}
host_action_validator.validate(host_listing)
missing_cursor_definition = copy.deepcopy(host_listing)
del missing_cursor_definition["catalog"]["tables"]["cursor"]["definition"]
assert not host_action_validator.is_valid(missing_cursor_definition)
rounded_cursor = copy.deepcopy(host_listing)
rounded_cursor["catalog"]["tables"]["cursor"]["after"] = 2**64 - 1
assert not host_action_validator.is_valid(rounded_cursor)
host_saved = {"table": {"definition": definition, "namespace": 1, "bytes": saved_bytes.hex()}}
host_action_validator.validate({"load": host_saved})
host_action_validator.validate({"operation": {"reference": {"table": host_reference}, "command": "inspect", "steps": 1}})
typed_absence = {"prepare": {"definition": definition, "namespace": 1, "operation": str(2**64 - 1), "name": "absent", "action": {"drop": {"basis": None, "if_exists": True}}}}
host_action_validator.validate(typed_absence)
missing_typed_definition = copy.deepcopy(typed_absence)
del missing_typed_definition["prepare"]["definition"]
assert not host_action_validator.is_valid(missing_typed_definition)
host_basis = {
    "definition": definition, "connection": host_reference["connection"], "namespace": 1, "name": "events",
    "interpretation": {"interpretation": host_binding["expected_definition"], "content": {"bytes": "104", "sha256": "03" * 32}, "schema_fingerprint": "04" * 32, "retired": False},
}
host_bulk = {"prepare": {"definition": definition, "namespace": 1, "operation": "9", "name": "events", "action": {"mutate": {
    "basis": host_basis, "ingestion": "bulk", "mutation": {"predicate": None, "action": {"insert": [
        [{"column": "1", "value": {"cell": {"value": {"atom": {"signed": str(index)}}}}},
         {"column": "2", "value": {"cell": {"value": {"atom": {"utf8": "x" * 32768}}}}}]
        for index in range(9)
    ]}},
}}}}
assert len(canonical(host_bulk)) > 256 * 1024
host_action_validator.validate(host_bulk)
host_result_validator = jsonschema.Draft202012Validator({**schema, "$ref": "#/$defs/HostResult"})
host_result_validator.validate({"staged": {"table": host_reference}})
retention_owner = {"definition": definition, "connection": host_reference["connection"],
                   "object": host_binding["target"], "operation": str(2**64 - 1)}
retention_acquisition = {"owner": retention_owner, "expected": {"partition": "9", "next_lsn": str(2**64 - 1)}}
retention_snapshot = {"owner": retention_owner, "content": {"bytes": str(2**64 - 1), "sha256": "09" * 32}}
host_action_validator.validate({"retention": {"acquire": retention_acquisition}})
host_action_validator.validate({"retention": {"status": retention_owner}})
host_action_validator.validate({"retention": {"metadata": retention_snapshot}})
host_action_validator.validate({"retention": {"release": retention_snapshot}})
host_result_validator.validate({"retention": {"acquired": retention_snapshot}})
for field in ("definition", "connection", "object", "operation"):
    malformed = copy.deepcopy(retention_owner)
    del malformed[field]
    assert not host_action_validator.is_valid({"retention": {"status": malformed}}), field
rounded = copy.deepcopy(retention_snapshot)
rounded["content"]["bytes"] = 2**64 - 1
assert not host_action_validator.is_valid({"retention": {"release": rounded}})
host_action_validator.validate({"preview": {"definition": definition, "digest": "07" * 32}})
row_preview = {"preview": {"rows": {
    "binding": host_binding, "directory_position": {"partition": "1", "next_lsn": str(2**64 - 1)},
    "current": {"interpretation": host_basis["interpretation"], "position": {"partition": "9", "next_lsn": "10"}, "changed_lsn": "9", "row_count": str(2**64 - 1)},
    "reason": "none",
}}}
host_result_validator.validate(row_preview)
invalid_preview = copy.deepcopy(row_preview)
invalid_preview["preview"]["rows"]["current"]["row_count"] = 2**64 - 1
assert not host_result_validator.is_valid(invalid_preview)
invalid_preview = copy.deepcopy(row_preview)
invalid_preview["preview"]["rows"]["reason"] = "committed"
assert not host_result_validator.is_valid(invalid_preview)
for field in ("definition", "connection", "binding", "content"):
    invalid = copy.deepcopy(host_reference)
    del invalid[field]
    assert not host_validator.is_valid(invalid), field
invalid = copy.deepcopy(host_reference)
invalid["binding"]["identity"]["operation"] = 2**64 - 1
assert not host_validator.is_valid(invalid)
persist(root / "packages/zig/transit-catalog/src/fixtures/direct-table-host-reference-v1.json",
        (json.dumps({"native": native_reference, "host": host_reference}, ensure_ascii=False, indent=2) + "\n").encode())
print("Direct Table: reflected envelopes, exact wide integers, mandatory proof/definition, independent signed request and saved intent passed.")
