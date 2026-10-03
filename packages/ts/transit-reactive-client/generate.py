"""Generate browser declarations from the Zig reactive and private-host schemas."""
import json
from pathlib import Path
import sys

root = Path(__file__).resolve().parents[3]
api = root / "packages/zig/transit-serving/api"
schemas = json.loads((api / "openapi.json").read_text())["components"]["schemas"]
schemas.update(json.loads((api / "client.json").read_text()))


def ts(schema):
    if "$ref" in schema: return schema["$ref"].rsplit("/", 1)[-1]
    if "const" in schema:
        return json.dumps(schema["const"])
    if "oneOf" in schema or "anyOf" in schema:
        return "(" + " | ".join(ts(item) for item in schema.get("oneOf", schema.get("anyOf"))) + ")"
    if "enum" in schema:
        return " | ".join(json.dumps(item) for item in schema["enum"])
    kind = schema["type"]
    if kind in ("integer", "number"): return "number"
    if kind in ("null", "boolean", "string"): return kind
    if kind == "array": return f"Array<{ts(schema['items'])}>"
    if kind == "object":
        return "{ " + "; ".join(f"{json.dumps(k)}{'' if k in schema.get('required', []) else '?'}: {ts(v)}" for k, v in schema.get("properties", {}).items()) + " }"
    raise ValueError(kind)


def clean(value):
    if isinstance(value, list): return [clean(item) for item in value]
    if isinstance(value, dict):
        if "$ref" in value and value["$ref"].startswith("#/components/schemas/"):
            return {"$ref": value["$ref"].rsplit("/", 1)[-1]}
        # Embedded SSE data is explicitly decoded and validated as ServerMessage
        # by the runtime parser. contentSchema is an annotation, not validation.
        return {k: clean(v) for k, v in value.items() if not k.startswith("x-transit-") and k not in ("contentSchema", "contentMediaType")}
    return value


outputs = {
    "types.ts": "// Generated from Zig-owned reactive schemas; do not edit.\n" + "\n".join(f"export type {name} = {ts(schema)};" for name, schema in schemas.items()) + "\n",
    "schemas.json": json.dumps(clean(schemas), separators=(",", ":")) + "\n",
}
for name, content in outputs.items():
    target = Path(__file__).parent / "src" / name
    if "--check" in sys.argv:
        if not target.exists() or target.read_text() != content:
            raise SystemExit(f"Reactive client drift: {target.relative_to(root)}")
    else:
        target.write_text(content)
