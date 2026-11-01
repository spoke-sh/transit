# transit-spatial

Pure Zig spatial interpretation and computation, exported as `transit_spatial`.
The library has no storage, transport, clock or authorization dependency. Its
only dependency is the public protocol for the shared definition identity.

`Reference` validates explicit local planar, Web Mercator and WGS84 coordinate
descriptors. SRID 0 requires a stable local-frame identity, units and axes.
`requireSame` rejects mixed frames, units, axes, precision or reference systems;
`requirePlanar` rejects geographic and
wrong-dimension operands. Geographic descriptors do not enable geodesic kernels.

`encode`, `decode` and `fingerprint` implement the canonical definition-bound
`SPR1` envelope without allocation. Encoding validates before changing output;
decoding rejects foreign definitions and noncanonical fields. See the
[spatial contract](../../../contracts/SPATIAL_V1.md) for byte layout and limits.

`Predicates` provides exact determinant signs for 2D/3D orientation, incircle
and insphere. It uses an outward-rounded interval filter and bounded error-free
expansions, with explicit coordinate-domain and workspace refusals.

`Planar` validates borrowed XY rings and polygons, reports original edge witnesses,
classifies points/segments and computes area with exact accumulation. Binary-grid
normalization is explicit. Geometry stays immutable and caller-owned; every
variable loop consumes an explicit work budget. The contract describes the
strict simple-polygon profile and the distinction between exact predicates and
exact constructions.

Table column semantics can retain the exact `Reference` as metadata on opaque
BINARY columns. This does not interpret the payload or enable a spatial operator.
The computation APIs remain local library calls. Spatial Table types, SQL, Arrow values, persistent
spatial indexes and maintained spatial queries are unavailable.

Inside `nix develop`, run `zig build test` here for executable checks or
`zig build check` for compilation. Tests distinguish descriptor validation from
runtime admission and preserve refusal without partial output.
From the repository root, `just test::spatial` executes both Debug and ReleaseFast
units and compares the compiled kernels with independent Python rational geometry
and canonical-byte oracles. Fuze exposes this library as `Spatial`; that export
does not enable new logical types or SQL functions.
