# Transit application browser primitives

Private M23 package shared by Board and generated applications. Wire types and
CSP-compatible structural validators derive from the Zig application owner's
public types. The package provides presentation selection, a bounded diagram
projection, pure theme editing and exact publication generation keys. Its optional operator adapter prepares signatures through the shared Zig host,
forwards exact signed submissions and retains uncertain recovery. It does not
parse SQL or grant authority. Complete semantic validation
and canonical SQL remain in `transit-station-app`.

`decodeDefinition` checks structural shape and supported component/revision
versions before rendering. A valid shape is not a valid reference graph or a
source permission. Keep pending native operations in their existing shared owner
when a new interface generation replaces a renderer; a generation key only fences
late UI work. The actual native Board browser proof qualifies editing and publication recovery;
interface-driven shell replacement and physical placements remain in progress.
See the [operator and recovery guide](docs/operator.md) for trust, admission and
unknown-outcome distinctions.

`ApplicationTransportError` preserves the primary HTTP status/code and an owned,
validated optional `diagnostic`. `diagnosticInvalid` reports malformed detail
without replacing that primary error. Both operator requests and interface
acquisitions use this boundary. Diagnostic actions describe recovery; the client
does not dispatch them automatically, and failed submissions retain the exact
pending signature in `OperatorSession`.
