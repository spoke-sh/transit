"""Generated OpenAPI drift, resource routes, security and response-schema links."""
from runner.paths import ROOT
import json
from pathlib import Path
import sys
actual = sys.stdin.buffer.read()
expected = (ROOT / "contracts/transit-board-v1.openapi.json").read_bytes()
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
    requests = {'/api/v1/query': 'UnifiedQueryRequest', '/api/v1/relational': 'RelationalRequest',
                '/api/v1/catalog': 'CatalogRequest', '/api/v1/sql-read': 'SqlReadRequest'}
    query = path in requests
    assert set(methods) == ({"post"} if query else {"get"})
    if query:
        request = requests[path]
        assert methods["post"]["requestBody"]["content"]["application/json"]["schema"]["$ref"] == f"#/components/schemas/{request}"
    for route in methods.values():
        for status in route["responses"].values():
            ref = status["content"]["application/json"]["schema"]["$ref"]
            assert ref.startswith("#/components/schemas/") and ref.rsplit("/", 1)[1] in spec["components"]["schemas"]
print("Board OpenAPI matches Zig-owned responses and inspection routes and the separate query contract.")
