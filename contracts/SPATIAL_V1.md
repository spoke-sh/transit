# Spatial interpretation and computation v1

## Scope

`transit-spatial` supplies deterministic, allocation-free spatial interpretation
and computation. `Reference` is an offline descriptor with canonical bytes and
a content fingerprint. It is independent of logical shape and physical codec.
It does not add spatial types to Table schemas, SQL, native values, Arrow or
indexes, publish a CRS registry or authorize access. Those owners reject spatial
data until their complete type/value/consumer cutover.

This new descriptor family binds the existing mandatory shared Transit definition.
Existing native messages, stored types and ABIs retain their current bytes.
Subsequent incompatible changes to this encoding or its interpretation require
the shared-definition review in the [versioning policy](../docs/handbook/reference/versioning.md).
Readers never supply a current definition for a missing or foreign field.

## Coordinate references

Every descriptor explicitly supplies definition, SRID, axes, manifold, linear
unit in nanometers, vertical datum and precision. There are no field defaults.
Dimensions follow the axes. Local SRID 0 is valid with explicit units; it does
not mean an unknown CRS. No descriptor performs a coordinate transformation.

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

`Reference.encode` writes exactly 56 bytes. All integer fields below are little
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

Decoding rejects wrong length/magic, foreign definitions, unknown tags, nonzero
reserved bytes, noncanonical exact exponents and invalid combinations. The
definition bytes are checked before interpreting the remaining descriptor.
`fingerprint` computes SHA-256 over ASCII `transit.spatial.reference.v1`, one
zero byte, and all 56 encoded bytes. Physical layout, allocator identity and
runtime addresses do not enter the commitment.

The descriptor owns no buffers or resources. Returned decoded values are plain
values; encoded slices borrow caller output. A fingerprint identifies these
rules, not a live catalog definition, retained snapshot or permission.
