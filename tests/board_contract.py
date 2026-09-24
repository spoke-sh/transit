"""Generated OpenAPI drift, resource routes, security and response-schema links."""
import json
from pathlib import Path
import sys
actual = sys.stdin.buffer.read()
expected = (Path(__file__).resolve().parents[1] / "contracts/board-v1.openapi.json").read_bytes()
if actual != expected:
    raise SystemExit("Board OpenAPI drift: run just board::generate")
spec = json.loads(actual)
assert spec["openapi"] == "3.1.1"
assert spec["security"] == [{"bearer": []}, {"session": []}]
assert spec["paths"]["/api/v1/session"]["post"]["security"] == [{"bearer": []}]
for path, methods in spec["paths"].items():
    assert path.startswith("/api/v1/")
    assert set(methods) == ({"post"} if path.endswith(("/session", "/logout")) else {"get"})
    for route in methods.values():
        for status in route["responses"].values():
            ref = status["content"]["application/json"]["schema"]["$ref"]
            assert ref.startswith("#/components/schemas/") and ref.rsplit("/", 1)[1] in spec["components"]["schemas"]
print("Board OpenAPI matches Zig-owned responses and read-only routes.")
