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
definition = "d9c9be6cf8ac63f1003a2d98ab3076936e28cea6a7278e620fe8b869530fc4d4"
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
    "lease": None,
    "transaction": None,
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
        "copied_from": None, "projection": None,
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
        + bytes(122)
    )
    assert len(retained_grant) == 433
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
    edge = {"source": source_definition, "dependent": {"kind": "captured", "interpretation": dependent_definition}, "privileges": 1, "foreign_key": None}
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
                       "spec": {"document": {"document": 91, "type_revision": 1, "limits": {"record_bytes": 4096, "staging_bytes": 16384, "staging_records": 4}}}}
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
    # Independent native-intent digest and signed lifecycle envelope. A rename
    # needs no fabricated binary schema and retains full-width original IDs.
    def native_name(value):
        encoded = value.encode()
        return {"len": len(encoded), "bytes": list(encoded) + [0] * (63 - len(encoded))}

    log_intent = {"kind": "queue", "namespace": 1, "name": native_name("jobs"), "action": {"rename": native_name("jobs_v2")}}
    log_digest = hashlib.sha256(b"transit.catalog.log.intent.v1\0" + canonical(log_intent)).digest()
    log_binding = {"definition": definition,
                   "identity": {"scope": request_input["connection"]["scope"], "principal": 4, "operation": 2**64 - 1},
                   "target": source_definition["object"], "action": "rename",
                   "expected_definition": source_definition, "expected_data": None,
                   "intent": list(log_digest), "prerequisite": None}
    log_input = {**request_input, "action": {"log_admit": {"binding": log_binding, "kind": "queue", "namespace": 1, "name": "jobs", "action": {"rename": "jobs_v2"}}}}
    log_claim = {**claim, "context": list(hashlib.sha256(b"transit.table.direct.request.v1\0" + canonical(log_input)).digest())}
    log_request = {**log_input, "proof": {"claim": log_claim, "signature": key.sign(hashlib.sha256(b"transit.authorization.subject.v1\0" + canonical(log_claim)).digest())}}
    log_fixture = {"request": log_request, "public_key": public_key, "intent_digest": list(log_digest)}

    kv_intent = {"kind": "kv", "namespace": 1, "name": native_name("state"), "action": {"rename": native_name("renamed_state")}}
    # DDL intent hashing uses the native canonical representation: fixed u8
    # arrays are strings, including all zero padding. The signed wire request
    # independently uses public JSON arrays for those same names.
    kv_digest_intent = copy.deepcopy(kv_intent)
    kv_digest_intent["name"]["bytes"] = bytes(kv_intent["name"]["bytes"]).decode()
    kv_digest_intent["action"]["rename"]["bytes"] = bytes(kv_intent["action"]["rename"]["bytes"]).decode()
    kv_digest = hashlib.sha256(b"transit.catalog.ddl.intent.v1\0" + canonical(kv_digest_intent)).digest()
    kv_binding = {**log_binding, "intent": list(kv_digest)}
    kv_declaration = {"binding": kv_binding, "namespace": 1, "name": native_name("state"), "action": {"rename": native_name("renamed_state")}}
    def signed_kv(action):
        envelope = {**request_input, "action": action}
        selected_claim = {**claim, "context": list(hashlib.sha256(b"transit.table.direct.request.v1\0" + canonical(envelope)).digest())}
        return {**envelope, "proof": {"claim": selected_claim, "signature": key.sign(hashlib.sha256(b"transit.authorization.subject.v1\0" + canonical(selected_claim)).digest())}}
    kv_declaration_request = signed_kv({"kv_declaration": {"declaration": kv_declaration, "command": "admit", "steps": 1}})
    kv_changes = [{"remove": {"base64": base64.b64encode(b"\0key").decode()}}]
    kv_mutation_digest = hashlib.sha256(b"transit.kv.mutation.v1\0" + canonical(kv_changes)).digest()
    kv_mutation = {"binding": {**kv_binding, "action": "insert", "intent": list(kv_mutation_digest)}, "changes": kv_changes}
    kv_mutation_request = signed_kv({"kv": {"mutate": kv_mutation}})
    kv_fixture = {"declaration": kv_declaration_request, "mutation": kv_mutation_request, "public_key": public_key,
                  "intent_digest": list(kv_digest), "mutation_digest": list(kv_mutation_digest)}

    stream_work = {"consume": {
        "target": {"definition": definition, "interpretation": source_definition, "partition": 1},
        "operation": log_binding["identity"], "group": None, "from": 0, "until": None, "timestamp": None,
    }}
    stream_input = {**request_input, "action": {"stream": {"mutate": {"work": stream_work, "payload": None}}}}
    stream_claim = {**claim, "context": list(hashlib.sha256(b"transit.table.direct.request.v1\0" + canonical(stream_input)).digest())}
    stream_request = {**stream_input, "proof": {"claim": stream_claim, "signature": key.sign(hashlib.sha256(b"transit.authorization.subject.v1\0" + canonical(stream_claim)).digest())}}
    stream_digest = hashlib.sha256(b"transit.catalog.stream.operation.v1\0" + bytes.fromhex(definition) + canonical(stream_work)).digest()
    stream_fixture = {"request": stream_request, "public_key": public_key, "intent_digest": list(stream_digest)}
    wait_input = {**request_input, "action": {"stream": {"wait": {"consume": stream_work["consume"], "milliseconds": 1000}}}}
    wait_claim = {**claim, "context": list(hashlib.sha256(b"transit.table.direct.request.v1\0" + canonical(wait_input)).digest())}
    wait_request = {**wait_input, "proof": {"claim": wait_claim, "signature": key.sign(hashlib.sha256(b"transit.authorization.subject.v1\0" + canonical(wait_claim)).digest())}}
    wait_fixture = {"request": wait_request, "public_key": public_key, "intent_digest": list(stream_digest)}
    queue_work = {"claim": {
        "target": stream_work["consume"]["target"], "operation": log_binding["identity"],
        "maximum": 16, "lease_ms": 1000,
    }}
    queue_input = {**request_input, "action": {"queue": {"mutate": {"work": queue_work, "payload": None}}}}
    queue_claim = {**claim, "context": list(hashlib.sha256(b"transit.table.direct.request.v1\0" + canonical(queue_input)).digest())}
    queue_request = {**queue_input, "proof": {"claim": queue_claim, "signature": key.sign(hashlib.sha256(b"transit.authorization.subject.v1\0" + canonical(queue_claim)).digest())}}
    queue_digest = hashlib.sha256(b"transit.catalog.queue.operation.v1\0" + bytes.fromhex(definition) + canonical(queue_work)).digest()
    queue_fixture = {"request": queue_request, "public_key": public_key, "intent_digest": list(queue_digest)}
    queue_wait_input = {**request_input, "action": {"queue": {"wait": {"claim": queue_work["claim"], "milliseconds": 1000}}}}
    queue_wait_claim = {**claim, "context": list(hashlib.sha256(b"transit.table.direct.request.v1\0" + canonical(queue_wait_input)).digest())}
    queue_wait_request = {**queue_wait_input, "proof": {"claim": queue_wait_claim, "signature": key.sign(hashlib.sha256(b"transit.authorization.subject.v1\0" + canonical(queue_wait_claim)).digest())}}
    queue_wait_fixture = {"request": queue_wait_request, "public_key": public_key, "intent_digest": list(queue_digest)}
    queue_release_work = {"release": {
        "operation": {**log_binding["identity"], "operation": 2**64-2},
        "claim": {"claim": queue_work["claim"], "accepted": {"partition": 91, "next_lsn": 11},
                  "observed_ms": 100, "expires_ms": 1100, "rows": 2,
                  "leases": {"bytes": 1024, "sha256": [49]*32}},
    }}
    queue_release_input = {**request_input, "action": {"queue": {"mutate": {"work": queue_release_work, "payload": None}}}}
    queue_release_claim = {**claim, "context": list(hashlib.sha256(b"transit.table.direct.request.v1\0" + canonical(queue_release_input)).digest())}
    queue_release_request = {**queue_release_input, "proof": {"claim": queue_release_claim, "signature": key.sign(hashlib.sha256(b"transit.authorization.subject.v1\0" + canonical(queue_release_claim)).digest())}}
    queue_fixture["release_request"] = queue_release_request
    queue_fixture["release_intent_digest"] = list(hashlib.sha256(b"transit.catalog.queue.operation.v1\0" + bytes.fromhex(definition) + canonical(queue_release_work)).digest())

    branch_intent = {
        "connection": request_input["connection"], "namespace": 1,
        "operation": 2**64 - 1, "name": native_name("trial"),
        "source": {"interpretation": source_definition, "manifest": None,
                   "checkpoint_lsn": 0, "accepted": {"partition": 9, "next_lsn": 2**64 - 1}},
        "mode": "full_data",
    }
    branch_key = {"definition": definition, "connection": request_input["connection"],
                  "account": [19] * 32, "token": [23] * 16}
    branch_input = {**request_input, "action": {"branch": {"create": {
        "key": branch_key, "intent": branch_intent,
        "budget": {"limits": {"operations": 1000000, "bytes": 4294967296, "pending": 1024}, "bytes": 4608},
    }}}}
    branch_claim = {**claim, "context": list(hashlib.sha256(b"transit.table.direct.request.v1\0" + canonical(branch_input)).digest())}
    branch_request = {**branch_input, "proof": {"claim": branch_claim, "signature": key.sign(hashlib.sha256(b"transit.authorization.subject.v1\0" + canonical(branch_claim)).digest())}}
    branch_fixture = {"request": branch_request, "public_key": public_key,
                      "intent_digest": list(hashlib.sha256(b"transit.catalog.table-branch.v1\0" + canonical(branch_intent)).digest())}

    history_intent = {
        "connection": request_input["connection"], "namespace": 1, "operation": 2**64 - 1,
        "selection": {"content": {"bytes": 512, "sha256": [25] * 32}, "count": 2, "descriptors": 0},
        "common": None,
    }
    history_input = {**request_input, "action": {"historical_catalog": {"acquire": {
        "key": branch_key, "intent": history_intent,
        "budget": {"limits": {"operations": 1000000, "bytes": 4294967296, "pending": 1024}, "bytes": 4608},
    }}}}
    history_claim = {**claim, "context": list(hashlib.sha256(b"transit.table.direct.request.v1\0" + canonical(history_input)).digest())}
    history_request = {**history_input, "proof": {"claim": history_claim, "signature": key.sign(hashlib.sha256(b"transit.authorization.subject.v1\0" + canonical(history_claim)).digest())}}
    history_snapshot = {
        "definition": definition,
        "owner": {"scope": request_input["connection"]["scope"], "principal": 4, "operation": 2**64 - 1},
        "branch": 1, "catalog_root": history_intent["selection"]["content"],
        "sources_root": {"bytes": 768, "sha256": [26] * 32}, "source_count": 2,
        "consistency": {"independent": {}},
    }
    history_selector = (b"THSNAP01" + bytes.fromhex(definition)
                        + struct.pack("<6Q", 42, 3, 2**64 - 1, 4, 2**64 - 1, 1)
                        + struct.pack("<Q", 512) + bytes([25] * 32)
                        + struct.pack("<Q", 768) + bytes([26] * 32)
                        + struct.pack("<QBQQ", 2, 2, 0, 0) + bytes(104))
    assert len(history_selector) == 297
    history_fixture = {"request": history_request, "public_key": public_key,
                       "intent_digest": list(hashlib.sha256(b"transit.catalog.history.v1\0" + canonical(history_intent)).digest()),
                       "snapshot": history_snapshot, "selector": history_selector.hex()}


    common_cut = {"transaction": {"scope": request_input["connection"]["scope"], "principal": 4, "operation": 2**64 - 2},
                  "acquired": {"partition": 1, "next_lsn": 17},
                  "sources": {"bytes": 1024, "sha256": [27] * 32}, "source_count": 3}
    common_intent = {**history_intent, "common": {"key": branch_key, "cut": common_cut}}
    common_input = {**history_input, "action": {"historical_catalog": {"acquire": {
        **history_input["action"]["historical_catalog"]["acquire"], "intent": common_intent}}}}
    common_claim = {**claim, "context": list(hashlib.sha256(b"transit.table.direct.request.v1\0" + canonical(common_input)).digest())}
    common_request = {**common_input, "proof": {"claim": common_claim, "signature": key.sign(hashlib.sha256(b"transit.authorization.subject.v1\0" + canonical(common_claim)).digest())}}
    common_selector = (history_selector[:176] + bytes([3]) + bytes(16)
                       + struct.pack("<8Q", 42, 3, 2**64 - 1, 4, 2**64 - 2, 1, 17, 1024)
                       + bytes([27] * 32) + struct.pack("<Q", 3))
    assert len(common_selector) == 297
    common_history_fixture = {"request": common_request, "public_key": public_key,
        "intent_digest": list(hashlib.sha256(b"transit.catalog.history.v1\0" + canonical(common_intent)).digest()),
        "snapshot": {**history_snapshot, "consistency": {"common_transaction": common_cut}},
        "selector": common_selector.hex()}

    # Independent metadata-only acquisition, including its zero-Table selector.
    metadata_intent = copy.deepcopy(history_intent)
    metadata_intent['selection']['count'] = 0
    metadata_intent['selection']['descriptors'] = 1
    metadata_input = {**history_input, 'action': {'historical_catalog': {'acquire': {
        **history_input['action']['historical_catalog']['acquire'], 'intent': metadata_intent}}}}
    metadata_claim = {**claim, 'context': list(hashlib.sha256(b'transit.table.direct.request.v1\0' + canonical(metadata_input)).digest())}
    metadata_request = {**metadata_input, 'proof': {'claim': metadata_claim, 'signature': key.sign(hashlib.sha256(b'transit.authorization.subject.v1\0' + canonical(metadata_claim)).digest())}}
    metadata_history_fixture = {'request': metadata_request, 'public_key': public_key,
        'intent_digest': list(hashlib.sha256(b'transit.catalog.history.v1\0' + canonical(metadata_intent)).digest()),
        'snapshot': {**history_snapshot, 'source_count': 0},
        'selector': (history_selector[:168] + bytes(8) + history_selector[176:]).hex()}

    # Canonical foreign interpretation constructed independently from public
    # primitive byte layouts. No production encoder supplies these expected bytes.
    from query.logical.fuze_types import descriptor
    table_definition = b'transit.table.schema.v1.2026-11-01.semantics'
    column_id = 2**64 - 2
    column_type = descriptor('int64')
    table_bytes = (b'FTS1' + bytes([len(table_definition)]) + table_definition
        + struct.pack('<QQQH', 7, 1, 2**64 - 1, 1)
        + struct.pack('<QB', column_id, 6) + b'amount'
        + struct.pack('<H', len(column_type)) + column_type
        + struct.pack('<BIBH', 0, 0, 0, 0))
    captured_bytes = bytes.fromhex('123d1a3d')
    captured_content = dict(bytes=len(captured_bytes), sha256=list(hashlib.sha256(captured_bytes).digest()))
    native_name = dict(len=9, bytes=list(b'mainframe' + bytes(54)))
    payload = dict(schema=dict(base64=base64.b64encode(table_bytes).decode()), sources=[],
        body=dict(foreign=dict(record_bytes=2, fields=[dict(column=column_id, offset=0, bytes=2, encoding='comp_3')],
            malformed='type_error', input=dict(content=captured_content, availability='retained', provenance='file:///never-refetched'))))
    interpretation_intent = dict(kind='foreign', namespace=1, name=native_name, action=dict(create=dict(owner=0, payload=payload)))
    intent_hash = hashlib.sha256(b'transit.catalog.interpretation.intent.v1\0' + canonical(interpretation_intent)).digest()
    interpretation_binding = dict(definition=definition, identity=read_binding['owner'], target=read_binding['interpretation']['object'],
        action='create', expected_definition=None, expected_data=None, intent=list(intent_hash), prerequisite=None)
    interpretation_input = {**request_input, 'action': {'descriptor': {'declaration': dict(request=dict(binding=interpretation_binding, intent=interpretation_intent), command='preview', steps=1)}}}
    interpretation_claim = {**claim, 'context': list(hashlib.sha256(b'transit.table.direct.request.v1\0' + canonical(interpretation_input)).digest())}
    interpretation_request = {**interpretation_input, 'proof': dict(claim=interpretation_claim, signature=key.sign(hashlib.sha256(b'transit.authorization.subject.v1\0' + canonical(interpretation_claim)).digest()))}
    interpretation_value = dict(definition=definition, object=read_binding['interpretation']['object'], revision=1,
        properties=dict(namespace=1, authorization=17, name=native_name), retired=False, **payload)
    interpretation_bytes = b'TCDESC01' + bytes.fromhex(definition) + canonical(interpretation_value)
    interpretation_fixture = dict(request=interpretation_request, public_key=public_key, value=interpretation_value,
        artifact_hex=interpretation_bytes.hex(), digest=list(hashlib.sha256(interpretation_bytes).digest()),
        schema_digest=list(hashlib.sha256(table_bytes).digest()), input_hex=captured_bytes.hex())

request = {**request_input, "proof": {"claim": claim, "signature": signature}}
fixture = {
    "request": request,
    "context": list(context),
    "public_key": public_key,
    "binary": {"bytes": [0, 255, 128, 1], "base64": "AP+AAQ=="},
}
validator = jsonschema.Draft202012Validator({**schema, "$ref": "#/$defs/Request"})
validator.validate(request)
validator.validate(branch_request)
validator.validate(history_request)
validator.validate(common_request)
validator.validate(metadata_request)
validator.validate(interpretation_request)
missing_common = copy.deepcopy(history_request)
del missing_common["action"]["historical_catalog"]["acquire"]["intent"]["common"]
assert not validator.is_valid(missing_common)
for field in ("key", "cut"):
    invalid_common = copy.deepcopy(common_request)
    del invalid_common["action"]["historical_catalog"]["acquire"]["intent"]["common"][field]
    assert not validator.is_valid(invalid_common), field
for field in ("connection", "namespace", "operation", "name", "source", "mode"):
    invalid = copy.deepcopy(branch_request)
    del invalid["action"]["branch"]["create"]["intent"][field]
    assert not validator.is_valid(invalid), field
validator.validate(wait_request)
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
validator.validate(log_request)
validator.validate(kv_declaration_request)
validator.validate(kv_mutation_request)
for field in ("binding", "namespace", "name", "action"):
    invalid = copy.deepcopy(kv_declaration_request)
    del invalid["action"]["kv_declaration"]["declaration"][field]
    assert not validator.is_valid(invalid), field
for field in ("binding", "changes"):
    invalid = copy.deepcopy(kv_mutation_request)
    del invalid["action"]["kv"]["mutate"][field]
    assert not validator.is_valid(invalid), field
validator.validate(stream_request)
validator.validate(queue_request)
validator.validate(queue_wait_request)
for field in ("claim", "milliseconds"):
    invalid = copy.deepcopy(queue_wait_request)
    del invalid["action"]["queue"]["wait"][field]
    assert not validator.is_valid(invalid), field
validator.validate(queue_release_request)
for field in ("operation", "claim"):
    invalid = copy.deepcopy(queue_release_request)
    del invalid["action"]["queue"]["mutate"]["work"]["release"][field]
    assert not validator.is_valid(invalid), field
for field in ("target", "operation", "maximum", "lease_ms"):
    invalid = copy.deepcopy(queue_request)
    del invalid["action"]["queue"]["mutate"]["work"]["claim"][field]
    assert not validator.is_valid(invalid), field
for field in ("target", "operation", "group", "from", "until", "timestamp"):
    invalid = copy.deepcopy(stream_request)
    del invalid["action"]["stream"]["mutate"]["work"]["consume"][field]
    assert not validator.is_valid(invalid), field
for field in ("binding", "kind", "namespace", "name", "action"):
    invalid = copy.deepcopy(log_request)
    del invalid["action"]["log_admit"][field]
    assert not validator.is_valid(invalid), field
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


# Independent fixed-width accepted-interpretation directory value. This oracle
# uses only struct packing, never the production codec. Fixture content is MIT.
def accepted_interpretation_fixture():
    revision, frontier = 2**53 + 1, 2**64 - 1
    scope = dict(realm=42, resource=3, catalog=2**64 - 1)
    stored = dict(kind="table", interpretation=dict(object=dict(scope=scope, branch=1, object=7), revision=revision, digest=[3]*32),
                  content=dict(bytes=104, sha256=[3]*32), schema_fingerprint=[4]*32, retired=False)
    value = dict(declaration=stored, next_lsn=frontier, origins=dict(digest=[5]*32, location=[6]*32))
    encoded = (struct.pack("<7Q", 42, 3, 2**64 - 1, 1, 7, revision, 104)
               + bytes([3]*32) + bytes([4]*32) + bytes([0])
               + struct.pack("<Q", frontier) + bytes([1]) + bytes([5]*32) + bytes([6]*32))
    assert len(encoded) == 194
    return dict(value=value, hex=encoded.hex())


persist(root / "packages/zig/transit-storage/src/fixtures/accepted-interpretation-v1.json",
        (json.dumps(accepted_interpretation_fixture(), indent=2) + "\n").encode())


# Independent signed projection preparation includes both exact declarations.
projection_stored = accepted_interpretation_fixture()["value"]["declaration"]
schema_projection_input = {**request_input, "action": {"schema_projection": {"prepare": {"source": projection_stored, "target": projection_stored}}}}
schema_projection_claim = {**claim, "context": list(hashlib.sha256(b"transit.table.direct.request.v1\0" + canonical(schema_projection_input)).digest())}
with tempfile.TemporaryDirectory(prefix="transit-schema-projection-contract-") as directory:
    signing_key = Key(Path(directory), "public-test-key", 9)
    schema_projection_request = {**schema_projection_input, "proof": {"claim": schema_projection_claim,
        "signature": signing_key.sign(hashlib.sha256(b"transit.authorization.subject.v1\0" + canonical(schema_projection_claim)).digest())}}
validator.validate(schema_projection_request)
for field in ("source", "target"):
    invalid = copy.deepcopy(schema_projection_request)
    del invalid["action"]["schema_projection"]["prepare"][field]
    assert not validator.is_valid(invalid), field
persist(root / "packages/zig/transit-catalog/src/fixtures/direct-schema-projection-v1.json",
        (json.dumps({"request": schema_projection_request, "public_key": public_key}, indent=2) + "\n").encode())


# Independent language-neutral history oracle: all u64 identities remain decimal
# strings, while native authority IDs remain bounded JSON numbers.
def history_host_scope(value):
    return dict(realm=value["realm"], resource=value["resource"], catalog=str(value["catalog"]))


def history_host_operation(value):
    return dict(scope=history_host_scope(value["scope"]), principal=value["principal"], operation=str(value["operation"]))


def history_host_content(value):
    return dict(bytes=str(value["bytes"]), sha256=bytes(value["sha256"]).hex())


def history_host_directory(value):
    return dict(content=history_host_content(value["content"]), count=str(value["count"]), descriptors=str(value["descriptors"]))


def history_host_key(value):
    connection = value["connection"]
    return dict(definition=value["definition"], connection=dict(connection, scope=history_host_scope(connection["scope"]), branch=str(connection["branch"])),
                account=bytes(value["account"]).hex(), token=bytes(value["token"]).hex())


def history_host_cut(value):
    return dict(transaction=history_host_operation(value["transaction"]), acquired={k: str(v) for k, v in value["acquired"].items()},
                sources=history_host_content(value["sources"]), source_count=str(value["source_count"]))


common_acquire = common_history_fixture["request"]["action"]["historical_catalog"]["acquire"]
common_intent = common_acquire["intent"]
common_snapshot = common_history_fixture["snapshot"]
history_host_key_value = history_host_key(common_acquire["key"])
history_host = dict(
    acquire=dict(key=history_host_key_value,
                 intent=dict(definition=definition, connection=history_host_key_value["connection"], namespace=common_intent["namespace"], operation=str(common_intent["operation"]),
                             selection=history_host_directory(common_intent["selection"]),
                             common=dict(key=history_host_key(common_intent["common"]["key"]), cut=history_host_cut(common_intent["common"]["cut"]))),
                 budget=dict(operations="1000000", bytes="4294967296", pending="1024", charge_bytes="4608")),
    snapshot=dict(selector=common_history_fixture["selector"], definition=definition, owner=history_host_operation(common_snapshot["owner"]), branch=str(common_snapshot["branch"]),
                  catalog_root=history_host_content(common_snapshot["catalog_root"]), sources_root=history_host_content(common_snapshot["sources_root"]), source_count=str(common_snapshot["source_count"]),
                  consistency=dict(common_transaction=history_host_cut(common_snapshot["consistency"]["common_transaction"]))),
)
persist(root / "packages/zig/transit-catalog/src/fixtures/direct-history-host-v1.json", (json.dumps(history_host, indent=2) + "\n").encode())


persist(root / "packages/zig/transit-catalog/src/fixtures/direct-history-metadata-v1.json", (json.dumps(metadata_history_fixture, ensure_ascii=False, indent=2) + "\n").encode())
persist(root / "packages/zig/transit-catalog/src/fixtures/direct-catalog-definition-v1.json", (json.dumps(interpretation_fixture, ensure_ascii=False, indent=2) + "\n").encode())
persist(root / "contracts/direct-table-v1.schema.json", raw)
persist(root / "packages/zig/transit-catalog/src/fixtures/direct-history-common-v1.json",
        (json.dumps(common_history_fixture, ensure_ascii=False, indent=2) + "\n").encode())
persist(root / "packages/zig/transit-catalog/src/fixtures/direct-history-v1.json",
        (json.dumps(history_fixture, ensure_ascii=False, indent=2) + "\n").encode())
persist(root / "packages/zig/transit-catalog/src/fixtures/direct-branch-v1.json",
        (json.dumps(branch_fixture, ensure_ascii=False, indent=2) + "\n").encode())
persist(root / "packages/zig/transit-catalog/src/fixtures/direct-kv-v1.json",
        (json.dumps(kv_fixture, ensure_ascii=False, indent=2) + "\n").encode())
persist(root / "packages/zig/transit-catalog/src/fixtures/direct-stream-v1.json",
        (json.dumps(stream_fixture, ensure_ascii=False, indent=2) + "\n").encode())
persist(root / "packages/zig/transit-catalog/src/fixtures/direct-queue-v1.json",
        (json.dumps(queue_fixture, ensure_ascii=False, indent=2) + "\n").encode())
persist(root / "packages/zig/transit-catalog/src/fixtures/direct-queue-wait-v1.json",
        (json.dumps(queue_wait_fixture, ensure_ascii=False, indent=2) + "\n").encode())
persist(root / "packages/zig/transit-catalog/src/fixtures/direct-stream-wait-v1.json",
        (json.dumps(wait_fixture, ensure_ascii=False, indent=2) + "\n").encode())
persist(root / "packages/zig/transit-catalog/src/fixtures/direct-log-v1.json",
        (json.dumps(log_fixture, ensure_ascii=False, indent=2) + "\n").encode())
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
native_intent = {"kind": "table", "namespace": 1, "name": {"len": 6, "bytes": "events" + "\0" * 57}, "action": {"drop": {}}}
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
# Client-token identity excludes a proposed target, operation, role and credential.
# Independent signing proves the complete request still binds all those fields.
token_key = {"definition": definition, "connection": request_input["connection"],
             "account": [11] * 32, "token": [12] * 16}
token_binding = {"key": token_key, "fingerprint": [13] * 32, "intent": {"table": native_reference}, "budget": {"limits": {"operations": 1000000, "bytes": 4294967296, "pending": 1024}, "bytes": 4608}}
token_input = {**request_input, "action": {"client_token": {"bind": token_binding}}}
token_claim = {**claim, "context": list(hashlib.sha256(b"transit.table.direct.request.v1\0" + canonical(token_input)).digest())}
with tempfile.TemporaryDirectory(prefix="transit-token-contract-") as directory:
    signing_key = Key(Path(directory), "public-test-key", 9)
    token_request = {**token_input, "proof": {"claim": token_claim,
        "signature": signing_key.sign(hashlib.sha256(b"transit.authorization.subject.v1\0" + canonical(token_claim)).digest())}}
validator.validate(token_request)
for field in ("definition", "connection", "account", "token"):
    invalid = copy.deepcopy(token_request)
    del invalid["action"]["client_token"]["bind"]["key"][field]
    assert not validator.is_valid(invalid), field
for field in ("fingerprint", "intent"):
    invalid = copy.deepcopy(token_request)
    del invalid["action"]["client_token"]["bind"][field]
    assert not validator.is_valid(invalid), field
token_digest = hashlib.sha256(b"transit.catalog.client-token.v1\0" +
    struct.pack("<4Q", 42, 3, 2**64 - 1, 4) + bytes([11] * 32) + bytes([12] * 16)).digest()
persist(root / "packages/zig/transit-catalog/src/fixtures/direct-client-token-v1.json",
        (json.dumps({"request": token_request, "public_key": public_key, "key_digest": list(token_digest)}, ensure_ascii=False, indent=2) + "\n").encode())

# A log declaration token commits to its complete canonical saved body before
# declaration admission. Content, account and the original binding are explicit.
saved_log = {"definition": definition, "connection": request_input["connection"], "work": log_input["action"]["log_admit"]}
saved_log_bytes = canonical(saved_log)
saved_log_validator = jsonschema.Draft202012Validator({**schema, "$ref": "#/$defs/SavedLogIntent"})
saved_log_validator.validate(saved_log)
for field in ("definition", "connection", "work"):
    invalid = copy.deepcopy(saved_log)
    del invalid[field]
    assert not saved_log_validator.is_valid(invalid), field
invalid = {**saved_log, "definition": "0" * 64}
assert not saved_log_validator.is_valid(invalid)
log_reference = {"connection": request_input["connection"], "namespace": 1, "kind": "queue", "binding": log_binding,
                 "record": {"scope": {"definition": definition, "connection": request_input["connection"], "account": token_key["account"]},
                            "format": 0x4c444c31, "content": {"bytes": len(saved_log_bytes), "sha256": list(hashlib.sha256(saved_log_bytes).digest())}}}
log_reference_digest = hashlib.sha256(b"transit.catalog.log.binding.v1\0" + b"GIR1" + bytes.fromhex(definition) + canonical({"log": log_reference})).digest()
log_token_binding = {**token_binding, "intent": {"log": log_reference}}
log_token_input = {**request_input, "action": {"client_token": {"bind": log_token_binding}}}
log_token_claim = {**claim, "context": list(hashlib.sha256(b"transit.table.direct.request.v1\0" + canonical(log_token_input)).digest())}
with tempfile.TemporaryDirectory(prefix="transit-log-token-contract-") as directory:
    signing_key = Key(Path(directory), "public-test-key", 9)
    log_token_request = {**log_token_input, "proof": {"claim": log_token_claim,
        "signature": signing_key.sign(hashlib.sha256(b"transit.authorization.subject.v1\0" + canonical(log_token_claim)).digest())}}
validator.validate(log_token_request)
for field in ("connection", "namespace", "kind", "binding", "record"):
    invalid = copy.deepcopy(log_token_request)
    del invalid["action"]["client_token"]["bind"]["intent"]["log"][field]
    assert not validator.is_valid(invalid), field
persist(root / "packages/zig/transit-catalog/src/fixtures/direct-log-token-v1.json",
        (json.dumps({"request": log_token_request, "public_key": public_key, "bytes": {"base64": base64.b64encode(saved_log_bytes).decode()},
                     "digest": list(log_reference_digest)}, ensure_ascii=False, indent=2) + "\n").encode())

# A transaction has the same original-token owner, with a separate typed begin
# descriptor. This vector checks bytes/signatures, not selection acquisition.
transaction_begin = {
    "definition": definition,
    "identity": {"begin": binding["identity"], "branch": 1},
    "mode": "serializable", "selection": "explicit_objects",
    "objects": {"content": {"bytes": 512, "sha256": [31] * 32}, "count": 17},
    "catalog": {"partition": 1, "next_lsn": 19},
    "limits": {"resident_bytes": 65536, "workspace_bytes": 1048576,
               "participants": 100, "statements": 1000, "savepoints": 32},
}
transaction_reference = {"connection": request_input["connection"], "namespace": 1, "begin": transaction_begin}
transaction_binding = {**token_binding, "intent": {"transaction": transaction_reference}}
transaction_input = {**request_input, "action": {"client_token": {"bind": transaction_binding}}}
transaction_claim = {**claim, "context": list(hashlib.sha256(b"transit.table.direct.request.v1\0" + canonical(transaction_input)).digest())}
with tempfile.TemporaryDirectory(prefix="transit-transaction-contract-") as directory:
    signing_key = Key(Path(directory), "public-test-key", 9)
    transaction_request = {**transaction_input, "proof": {"claim": transaction_claim,
        "signature": signing_key.sign(hashlib.sha256(b"transit.authorization.subject.v1\0" + canonical(transaction_claim)).digest())}}
validator.validate(transaction_request)
for field in transaction_begin:
    invalid = copy.deepcopy(transaction_request)
    del invalid["action"]["client_token"]["bind"]["intent"]["transaction"]["begin"][field]
    assert not validator.is_valid(invalid), field
persist(root / "packages/zig/transit-catalog/src/fixtures/direct-transaction-v1.json",
        (json.dumps({"request": transaction_request, "public_key": public_key}, ensure_ascii=False, indent=2) + "\n").encode())

# Partition selection is signed independently of frozen-directory admission.
# Queue targets exercise the neutral shape; the owner checks declared ordinals.
target_object = {"scope": request_input["connection"]["scope"], "branch": 1, "object": 7}
selected_begin = {
    "key": token_binding["key"], "fingerprint": token_binding["fingerprint"],
    "operation": binding["identity"], "namespace": 1, "mode": "serializable",
    "selection": {"explicit_objects": [
        {"object": target_object, "kind": "queue", "partition": 0},
        {"object": target_object, "kind": "queue", "partition": 2**32 - 1},
    ]},
    "limits": transaction_begin["limits"], "budget": token_binding["budget"],
}
selected_input = {**request_input, "action": {"transaction": {"begin": selected_begin}}}
selected_claim = {**claim, "context": list(hashlib.sha256(b"transit.table.direct.request.v1\0" + canonical(selected_input)).digest())}
with tempfile.TemporaryDirectory(prefix="transit-transaction-selection-contract-") as directory:
    signing_key = Key(Path(directory), "public-test-key", 9)
    selected_request = {**selected_input, "proof": {"claim": selected_claim,
        "signature": signing_key.sign(hashlib.sha256(b"transit.authorization.subject.v1\0" + canonical(selected_claim)).digest())}}
validator.validate(selected_request)
for field in ("object", "kind", "partition"):
    invalid = copy.deepcopy(selected_request)
    del invalid["action"]["transaction"]["begin"]["selection"]["explicit_objects"][0][field]
    assert not validator.is_valid(invalid), field
persist(root / "packages/zig/transit-catalog/src/fixtures/direct-transaction-begin-v1.json",
        (json.dumps({"request": selected_request, "public_key": public_key}, ensure_ascii=False, indent=2) + "\n").encode())

# KV workspace admission binds the original mutation and its exact private
# sequence to the same transaction token. The mutation digest is independently
# computed above; signing cannot substitute a new operation after uncertainty.
kv_stage = {"key": token_binding["key"], "basis": {"partition": 9, "next_lsn": 10},
            "sequence": 2, "work": kv_mutation}
kv_stage_input = {**request_input, "action": {"transaction": {"stage_kv": kv_stage}}}
kv_stage_claim = {**claim, "context": list(hashlib.sha256(b"transit.table.direct.request.v1\0" + canonical(kv_stage_input)).digest())}
with tempfile.TemporaryDirectory(prefix="transit-transaction-kv-contract-") as directory:
    signing_key = Key(Path(directory), "public-test-key", 9)
    kv_stage_request = {**kv_stage_input, "proof": {"claim": kv_stage_claim,
        "signature": signing_key.sign(hashlib.sha256(b"transit.authorization.subject.v1\0" + canonical(kv_stage_claim)).digest())}}
validator.validate(kv_stage_request)
for field in ("key", "basis", "sequence", "work"):
    invalid = copy.deepcopy(kv_stage_request)
    del invalid["action"]["transaction"]["stage_kv"][field]
    assert not validator.is_valid(invalid), field
persist(root / "packages/zig/transit-catalog/src/fixtures/direct-transaction-kv-v1.json",
        (json.dumps({"request": kv_stage_request, "public_key": public_key}, ensure_ascii=False, indent=2) + "\n").encode())
# Independent private log statement commitments bind the entire source guard,
# workspace revision and original operation, in addition to the signed envelope.
# This is a shape/signature vector; its payload is not an executable LogBatch.
log_work = {"append": {
    "target": stream_work["consume"]["target"],
    "operation": {**log_binding["identity"], "operation": 2**64 - 2},
    "kind": "stream", "producer": None, "rows": 1,
    "payload": {"bytes": 3, "sha256": list(hashlib.sha256(b"abc").digest())},
}}
log_work_digest = hashlib.sha256(b"transit.catalog.transaction.log.work.v1\0" + bytes.fromhex(definition) + canonical(log_work)).digest()
log_statement = {
    "statement": {"transaction": transaction_begin["identity"], "sequence": 2, "intent": list(log_work_digest)},
    "basis": {"partition": 9, "next_lsn": 10},
    "guard": {"kind": "stream", "source": {"target": log_work["append"]["target"], "accepted": {"partition": 91, "next_lsn": 3}, "retained_from": 0, "next": 0}, "changed_lsn": 2},
    "work": log_work,
}
log_statement_digest = hashlib.sha256(b"transit.catalog.transaction.log.statement.v1\0" + bytes.fromhex(definition) + canonical(log_statement)).digest()
log_statement_input = {**request_input, "action": {"transaction": {"log_statement": {"key": token_key, "request": log_statement, "execute": False}}}}
log_statement_claim = {**claim, "context": list(hashlib.sha256(b"transit.table.direct.request.v1\0" + canonical(log_statement_input)).digest())}
with tempfile.TemporaryDirectory(prefix="transit-transaction-log-contract-") as directory:
    signing_key = Key(Path(directory), "public-test-key", 9)
    log_statement_request = {**log_statement_input, "proof": {"claim": log_statement_claim,
        "signature": signing_key.sign(hashlib.sha256(b"transit.authorization.subject.v1\0" + canonical(log_statement_claim)).digest())}}
validator.validate(log_statement_request)
for field in ("statement", "basis", "guard", "work"):
    invalid = copy.deepcopy(log_statement_request)
    del invalid["action"]["transaction"]["log_statement"]["request"][field]
    assert not validator.is_valid(invalid), field
persist(root / "packages/zig/transit-catalog/src/fixtures/direct-transaction-log-v1.json",
        (json.dumps({"request": log_statement_request, "public_key": public_key,
                     "intent_digest": list(log_work_digest), "request_digest": list(log_statement_digest)}, ensure_ascii=False, indent=2) + "\n").encode())
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
             "dependent": {"kind": "captured", "interpretation": host_interpretation(dependent_definition)}, "privileges": 1, "foreign_key": None}
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
                     "position": {"partition": str(2**64 - 1), "next_lsn": str(2**64 - 1)}, "after": (struct.pack(">Q", 2**64 - 2) + b"\0" + edge_digest).hex()}
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
