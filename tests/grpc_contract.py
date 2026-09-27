#!/usr/bin/env python3
"""Independent GRQ1/GRB1 and Publication commitments; no sockets or credentials."""
import hashlib
import json
import pathlib
import struct
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "packages/zig/transit-station-grpc/src/fixtures/request.json"


def digest(data):
    chain = hashlib.sha256(b"transit.station.publication.v1\0" + struct.pack("<II", 2, len(data))).digest()
    for index, offset in enumerate(range(0, len(data), 256)):
        part = data[offset:offset + 256]
        chain = hashlib.sha256(b"\x01" + chain + struct.pack("<IH", index, len(part)) + part).digest()
    return chain


def generate():
    schema = hashlib.sha256((ROOT / "tests/fixtures/grpc/peer.pb").read_bytes()).digest()
    metadata = {
        "version": 1,
        "method": "/transit.test.Peer/Bidi",
        "shape": "bidi",
        "descriptor_digest": schema.hex(),
        "metadata": [
            {"name": "x-label", "value": {"literal_hex": b"first".hex()}},
            {"name": "x-label", "value": {"literal_hex": b"second".hex()}},
            {"name": "x-data-bin", "value": {"literal_hex": bytes([0, 255, 128, 10]).hex()}},
            {"name": "authorization", "value": {"secret": {"binding": "peer-token", "version": 2**64-1}}},
        ],
    }
    encoded = json.dumps(metadata, separators=(",", ":"), ensure_ascii=False).encode()
    # Valid protobuf field 1 (UTF-8), field 2 (bytes), field 3 (u64 max), then an
    # empty message and a binary message. No protobuf normalization on capture.
    label = "café🌐".encode()
    messages = [b"\x0a" + bytes([len(label)]) + label + b"\x12\x03\x00\xff\x80\x18" + b"\xff" * 9 + b"\x01", b"", b"\x12\x02\x00\xff"]
    batch = b"GRB1" + struct.pack("<I", len(messages)) + b"".join(struct.pack("<I", len(m)) + m for m in messages)
    reference = b"GRQ1" + struct.pack("<QQI", 2**53-1, 2**64-1, len(encoded)) + digest(encoded) + struct.pack("<I", len(batch)) + digest(batch) + struct.pack("<QQIB", 2**64-1, 2**64-1, 2**32-1, 4) + schema
    return json.dumps({"metadata": encoded.decode(), "messages_hex": [m.hex() for m in messages], "batch_hex": batch.hex(), "reference_hex": reference.hex()}, indent=2, ensure_ascii=False) + "\n"


def generate_capture():
    def metadata(fields):
        return b"GRH1" + struct.pack("<I", len(fields)) + b"".join(
            struct.pack("<HI", len(k), len(v)) + k + v for k, v in fields)
    body = "café🌐".encode() + bytes(range(256))
    result = {
        "initial_hex": metadata([(b":status", b"200"), (b"content-type", b"application/grpc+proto"), (b"x-repeat", b"one"), (b"x-repeat", b"two"), (b"x-binary-bin", b"AP8=")]).hex(),
        "trailers_hex": metadata([(b"grpc-status", b"0")]).hex(),
        "message_hex": (b"GRM1" + struct.pack("<II", 0, len(body)) + hashlib.sha256(body).digest()).hex(),
        "half_close_hex": (b"GRS1" + struct.pack("<II", 1, 5)).hex(),
        "timing_hex": (b"GRT1" + struct.pack("<QQ", 2**64-1, 2**64-1)).hex(),
        "omission_hex": (b"GRO1" + struct.pack("<II", 1, 1)).hex(),
        "completion_hex": (b"GRC1" + struct.pack("<IIIIIB", 0, 1, 1, 5, len(body)+5, 1)).hex(),
        "body_hex": body.hex(),
    }
    return json.dumps(result, indent=2) + "\n"


def generate_service():
    reference = bytes.fromhex(json.loads(generate())["reference_hex"])
    def outcome(phase, status, chain):
        return (b"GRR1" + struct.pack("<BQQQQI", phase, 7, 2**64-1, 19, 20, status) + chain).hex()
    return json.dumps({
        "route_hex": (b"GRA1" + struct.pack("<QQQB", 9, 8, 2**64-1, 1) + reference).hex(),
        "outcome_ok_hex": outcome(1, 0, bytes([9])*32),
        "outcome_unknown_hex": outcome(2, 0, bytes(32)),
        "rejection_hex": (b"GRF1" + bytes([1])).hex(),
        "release_hex": (b"GRD1" + struct.pack("<QQ", 7, 2**64-1)).hex(),
        "released_hex": (b"GRK1" + struct.pack("<QQ", 7, 2**64-1)).hex(),
        "followup_hex": (b"GRU1" + struct.pack("<QQB", 7, 2**64-1, 1) + reference).hex(),
    }, indent=2) + "\n"


if __name__ == "__main__":
    if sys.argv[1:] not in ([], ["--write"]):
        raise SystemExit("usage: grpc_contract.py [--write]")
    for path, result in ((FIXTURE, generate()), (FIXTURE.with_name("capture.json"), generate_capture()), (FIXTURE.with_name("service.json"), generate_service())):
        if sys.argv[1:]:
            path.write_text(result)
        elif path.read_text() != result:
            raise SystemExit(f"gRPC fixture {path.name} differs; review and regenerate explicitly")
    if not sys.argv[1:]:
        print("gRPC request/capture fixtures: independent binary layouts and commitments verified")
