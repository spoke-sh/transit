# Transit application browser primitives

Private M23 package shared by Board and generated applications. Wire types and
CSP-compatible structural validators derive from the Zig application owner's
public types. The package provides presentation selection, a bounded diagram
projection, pure theme editing and exact publication generation keys. It does not
parse SQL, submit operations or grant authority. Complete semantic validation
and canonical SQL remain in `transit-station-app`.

`decodeDefinition` checks structural shape and supported component/revision
versions before rendering. A valid shape is not a valid reference graph or a
source permission. Keep pending native operations in their existing shared owner
when a new interface generation replaces a renderer; a generation key only fences
late UI work. Integration and browser publication qualification remain in progress.
