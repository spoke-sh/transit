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


if __name__ == "__main__":
    result = generate()
    if sys.argv[1:] == ["--write"]:
        FIXTURE.write_text(result)
    elif not sys.argv[1:]:
        if FIXTURE.read_text() != result:
            raise SystemExit("gRPC request fixture differs; review and regenerate explicitly")
        print("gRPC request fixture: independent binary layout and commitments verified")
    else:
        raise SystemExit("usage: grpc_contract.py [--write]")
