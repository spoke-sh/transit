# transit-spatial

Pure Zig spatial interpretation and computation, exported as `transit_spatial`.
The library has no storage, transport, clock or authorization dependency. Its
only dependency is the public protocol for the shared definition identity.

`Reference` validates explicit local planar, Web Mercator and WGS84 coordinate
descriptors. SRID 0 requires units and axes. `requireSame` rejects mixed units,
axes, precision or reference systems; `requirePlanar` rejects geographic and
wrong-dimension operands. Geographic descriptors do not enable geodesic kernels.

`encode`, `decode` and `fingerprint` implement the canonical definition-bound
`SPR1` envelope without allocation. Encoding validates before changing output;
decoding rejects foreign definitions and noncanonical fields. See the
[spatial contract](../../../contracts/SPATIAL_V1.md) for byte layout and limits.

These are local library APIs. Spatial Table types, SQL, Arrow values, persistent
spatial indexes and maintained spatial queries are unavailable.

Inside `nix develop`, run `zig build test` here for executable checks or
`zig build check` for compilation. Tests distinguish descriptor validation from
runtime admission and preserve refusal without partial output.
