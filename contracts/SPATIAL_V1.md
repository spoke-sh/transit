# Spatial interpretation and computation v1

## Scope

`transit-spatial` supplies deterministic, allocation-free spatial interpretation
and computation. `Reference` is an offline descriptor with canonical bytes and
a content fingerprint. It is independent of logical shape and physical codec.
It does not add spatial types to Table schemas, SQL, native values, Arrow or
indexes, publish a CRS registry or authorize access. Those owners reject spatial
data until their complete type/value/consumer cutover.

This new descriptor family binds the existing mandatory shared Transit definition.
Table column semantics may retain this exact descriptor on an opaque BINARY
column. That metadata is not a geometry type or execution capability; the
[Table schema contract](TABLE_SCHEMA_V1.md) owns its enclosing encoding.
Subsequent incompatible changes to this encoding or its interpretation require
the shared-definition review in the [versioning policy](../docs/handbook/reference/versioning.md).
Readers never supply a current definition for a missing or foreign field.

## Coordinate references

Every descriptor explicitly supplies definition, SRID, local-frame identity,
axes, manifold, linear unit in nanometers, vertical datum and precision. There
are no field defaults.
Dimensions follow the axes. Local SRID 0 is valid with explicit units; it does
not mean an unknown CRS. Its nonzero 16-byte `local_frame` identity names a fixed
origin and oriented coordinate frame chosen by the caller. Different sites or
independently positioned engineering frames require different identities, even
when their units, axes and precision match. Built-in CRS descriptors require a
zero local-frame field. This identity grants no authority and supplies no
transformation; callers must not reuse it for a changed frame.

| SRID | Axes | Manifold | Linear unit | Vertical datum |
| --- | --- | --- | --- | --- |
| 0 | `xy` | planar | Positive nanometers per coordinate unit | none |
| 0 | `xyz` | planar | Positive nanometers per coordinate unit | local |
| 3857 | `xy` | planar | 1,000,000,000 (meters) | none |
| 4326 | longitude, latitude in degrees | WGS84 ellipsoid | 0 (no linear axis) | none |
| 4979 | longitude, latitude in degrees; height in meters | WGS84 ellipsoid | 1,000,000,000 (height only) | WGS84 ellipsoid |

Other SRIDs reject. Datum, axes, manifold and units must match the entire row.
In particular, ellipsoidal height is not orthometric height. Descriptors for
geographic coordinates do not enable geodesic computation; `requirePlanar`
refuses them. Coordinate-domain validation belongs to the selected operation.

Precision is `exact` or a planar binary grid whose spacing is `2^exponent`
coordinate units, exponent -100 through 100. The grid origin is zero on every
axis. Geographic descriptors currently require exact precision. Selecting a grid
does not implicitly change an input. Conversion/normalization must be explicit.
Binary operations require identical complete descriptors, including precision.
No implicit unit conversion, reprojection, axis swap or grid change is permitted.

## Canonical reference bytes

`Reference.encode` writes exactly 72 bytes. All integer fields below are little
endian except the shared definition's 32 bytes, which retain their owning order.
Validation and output-capacity checks precede every output mutation.

| Offset | Width | Field |
| --- | --- | --- |
| 0 | 4 | ASCII `SPR1` |
| 4 | 32 | Mandatory current `Growth.definition_bytes` |
| 36 | 4 | SRID, u32 |
| 40 | 1 | Axes: xy=1, xyz=2, longitude_latitude=3, longitude_latitude_height=4 |
| 41 | 1 | Manifold: planar=1, wgs84_ellipsoid=2 |
| 42 | 1 | Vertical datum: none=0, local=1, wgs84_ellipsoid=2 |
| 43 | 1 | Precision: exact=0, binary_grid=1 |
| 44 | 8 | Linear unit nanometers, u64 |
| 52 | 2 | Signed grid exponent, i16; zero for exact |
| 54 | 2 | Zero reserved bytes |
| 56 | 16 | Local-frame identity; nonzero for SRID 0, zero for built-in CRS |

Decoding rejects wrong length/magic, foreign definitions, unknown tags, nonzero
reserved bytes, noncanonical exact exponents and invalid combinations. The
definition bytes are checked before interpreting the remaining descriptor.
`fingerprint` computes SHA-256 over ASCII `transit.spatial.reference.v1`, one
zero byte, and all 72 encoded bytes. Physical layout, allocator identity and
runtime addresses do not enter the commitment.

The descriptor owns no buffers or resources. Returned decoded values are plain
values; encoded slices borrow caller output. A fingerprint identifies these
rules, not a live catalog definition, retained snapshot or permission.

## Exact determinant predicates

`Predicates.orient2d`, `orient3d`, `incircle` and `insphere` classify the exact
determinant of the supplied binary64 coordinates. Inputs must be finite, with
each coordinate zero or absolute magnitude in the inclusive range
`[2^-100, 2^100]`. Subnormals and nonzero coordinates outside that range reject;
they are not rounded to zero. Negative zero has the same geometric meaning as
positive zero. These numeric kernels do not infer a CRS from coordinates.

The fast path evaluates an outward-rounded interval. Only a strictly separated
interval establishes a sign. Otherwise, error-free `Two_Sum`, `Split` and
`Two_Product` operations and zero-eliminating expansion addition compute the
sign. The expansion algorithms follow
[Shewchuk's robust arithmetic](https://www.cs.cmu.edu/~quake/robust.html), with
strict binary64 rounding and no FMA contraction even in `ReleaseFast`. This
bounded composition is not a claim to port the specialized adaptive C routines
or match their performance. Each expansion has 64 components; exhaustion returns
`SpatialPredicateWorkspaceExceeded` before a partial sign can escape. It never
truncates an expansion or substitutes a tolerance. There is no heap allocation.

The coordinate restriction keeps split intermediates and products finite. Every
input is an integer multiple of `2^-152`; determinant degree is at most five.
Nonzero expansion products therefore remain at least `2^-760`, above binary64
underflow. The implementation uses strict operations rather than relying on the
build's default floating-point mode. Qualification must execute each target;
compilation alone does not establish its rounding behavior.

`orient2d(a,b,c)` is positive for counterclockwise points. `orient3d(a,b,c,d)`
is the sign of `det(a-d,b-d,c-d)`. `incircle` is positive inside the circle when
`a,b,c` are counterclockwise; `insphere` is positive inside the sphere when
`a,b,c,d` have positive orientation. Reversing orientation reverses those signs.
Zero means a zero determinant, including duplicate or degenerate inputs; it
does not prove a unique circle or sphere. The returned path (`interval` or
`exact`) is diagnostic and does not enter geometry identity.

Exact signs do not construct exact intersection coordinates. No noding,
overlay, repair, transformation or geodesic operation is supplied here.

## Planar rings and polygons

`Planar` admits XY planar references only. A `Ring` borrows a closed coordinate
slice with at least three edges; a `Polygon` borrows a validated shell and a
directory of validated holes. Callers construct them through `init` and keep
coordinates, references, bounds and the directory immutable for every borrow's
lifetime. No operation retains pointers beyond its returned borrowed value.
The native structs are not wire decoders: constructed fields are trusted after
validation, and callers must not forge or mutate them.

Ring validation rejects consecutive duplicate vertices, self-intersections,
touches between nonadjacent edges, adjacent backtracking and zero area. Polygon
validation rejects holes outside the shell, all touching/intersecting ring
boundaries, nested holes and different complete references. Both winding
directions are admitted. This deliberately strict simple-polygon profile is not
full OGC polygon validity. Structural errors report a bounded reason and original
ring/edge indices, without payloads; reference, coordinate and work refusals
leave that witness absent. Invalid construction returns no usable geometry.

`locate` returns `exterior`, `boundary` or `interior`; a hole interior is exterior
to its polygon. Half-open ray crossings and exact orientation avoid divisions
and count shared vertices once. Closed-segment classification distinguishes
`disjoint`, `touch`, `cross` and collinear `overlap`, including zero-length
segments. Boxes include their boundary and reject invalid coordinates/bounds
before producing a pruning answer. Boxes describe coordinate numbers only;
combining interpreted operands still requires identical references.

`Ring.signedArea` and `Polygon.area` accumulate exact dyadic products in a bounded
signed integer and round once to binary64. Polygon area subtracts exact absolute
hole areas before rounding. Units are coordinate units squared, never inferred
meters or ellipsoidal area. No input winding is changed. `normalizeCoordinate`
explicitly rounds to the descriptor's binary grid, nearest with ties to even;
grid validation rejects off-grid inputs instead of snapping them during ingestion.
Normalizing individual coordinates is not topology-preserving snap rounding or
geometry repair; the resulting shape must be validated again.

Variable loops charge a caller-owned `Budget` before each vertex, edge, candidate
pair or area contribution. Insufficient work returns `SpatialWorkExceeded`
without wrapping the counter; consumed work is not restored on failure. Ring
validation is quadratic in edges, point location and area are linear, and hole
validation can be quadratic across all edges. Coordinates remain caller-owned;
there is no fixed collection-cardinality cap, durable state or spill claim.
Expansion work is fixed and bounded per predicate. This scalar reference profile
does not establish query-level resource metering or vectorized throughput.
