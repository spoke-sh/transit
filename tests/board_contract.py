"""Generated OpenAPI drift, resource routes, security and response-schema links."""
import json
from pathlib import Path
import sys
actual = sys.stdin.buffer.read()
expected = (Path(__file__).resolve().parents[1] / "contracts/transit-board-v1.openapi.json").read_bytes()
if actual != expected:
    raise SystemExit("Board OpenAPI drift: run just transit-board::generate")
spec = json.loads(actual)
assert spec["openapi"] == "3.1.1"
assert spec["security"] == []
assert "securitySchemes" not in spec["components"]
assert "Session" not in spec["components"]["schemas"]
assert "session_seconds" not in spec["components"]["schemas"]["Capabilities"]["properties"]
assert "/api/v1/session" not in spec["paths"] and "/api/v1/logout" not in spec["paths"]
for path, methods in spec["paths"].items():
    assert path.startswith("/api/v1/")
    assert set(methods) == {"get"}
    for route in methods.values():
        for status in route["responses"].values():
            ref = status["content"]["application/json"]["schema"]["$ref"]
            assert ref.startswith("#/components/schemas/") and ref.rsplit("/", 1)[1] in spec["components"]["schemas"]
print("Board OpenAPI matches Zig-owned responses and read-only routes.")
