# Reactive description validators

These are unmodified official schema artifacts, checked offline with Python
`jsonschema` from the repository's locked Nixpkgs revision. `pins.json` pins each
artifact digest and schema identity. No runtime fetch resolves description refs.

- OpenAPI 3.2 schema/schema-base, 2026-08-30, and dialect/meta, 2026-02-26:
  https://spec.openapis.org/oas/ (OpenAPI Initiative, Apache-2.0).
- AsyncAPI 3.0.0 JSON Schema from `asyncapi/spec-json-schemas` tag `v6.8.1`:
  https://github.com/asyncapi/spec-json-schemas/tree/v6.8.1 (Apache-2.0).

The upstream schemas validate description structure. Runtime semantic checks and
independent peer traces additionally enforce signature scope, lifecycle, encoded
byte bounds and cursor compatibility. Neither a valid document nor a skipped
peer trace proves serving behavior. Board's OpenAPI 3.1 remains separate.
