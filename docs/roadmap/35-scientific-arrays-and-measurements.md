# 35. Scientific arrays, measurements and reproducible numerical computation

[Roadmap](README.md) · **Status:** Planned

Let applications declare measured and simulated datasets with named dimensions,
units, calibration and numerical fidelity, then inspect exactly which inputs and
interpretations produced a result. Qualify earth observation, climate and
scientific data cubes as the first application profile. The shared contracts also
serve audio, imaging, biology, video, robotics, [EDA/hardware waveforms and continuum thermal/IR-drop fields](42-hardware-design-rtl-and-eda-verification.md) and numerical experiments.

This is planned work. Existing array descriptors, spatial grids, codecs and
captured computations do not establish this lifecycle or executable syntax.

## Prerequisites and ownership

Start from the [data model](../handbook/reference/data-model.md),
[type semantics](../handbook/reference/sql/types.md),
[query execution](../handbook/reference/queries.md) and
[storage boundary](../handbook/reference/storage.md). Extend
[data identities](01-declarative-data-lifecycle.md),
[interpretation and historical catalogs](10-standards-and-catalogs.md),
[managed computations](12-sql-and-dataflows.md),
[resource control](13-data-structures-and-performance.md),
[spatial/raster/cochain types](17-geospatial-and-spatio-temporal-computing.md),
[foreign formats](18-multi-model-and-foreign-relations.md),
[waveform and simulation profiles](19-game-asset-pipelines-and-simulation-streaming.md),
[branches](20-branches-merges-and-restore.md) and
[retained investigations](28-published-resources-and-investigations.md).

Reuse the [data lifecycle](../../contracts/DATA_LIFECYCLE_V1.md),
[result lifecycle](../../contracts/SQL_RESULTS_V1.md) and
[investigation basis](../../contracts/INVESTIGATION_V1.md) contracts. Define
extensions before syntax, persistence or adapters. Fuze owns deterministic
numerical kernels; catalog, storage and computation owners retain authority and
publication. There is no new scientific database or application policy authority.
Earlier spatial, waveform and foreign-format owners keep their delivery gates;
this milestone generalizes their semantics for cross-domain composition.

## Delivery sequence

1. **Declare measurement interpretation independently of encoding.** Bind stable
   dataset/variable/axis identities, shape, coordinate variables, units, reference
   frame, sampling model, clock domain/calendar and calibration definition.
   Distinguish regular, irregular and categorical axes; points from cell bounds;
   absolute quantities from differences; observed time from ingest/knowledge time.
   A calibration has its own revision and validity interval. Correcting it creates
   a successor interpretation without relabeling earlier results. Preserve
   orthogonal logical types, semantic rules and physical codecs.
2. **Separate cell state, measurement quality and approximation.** Retain the
   five-state model for value interpretation. Attach separately typed evidence
   for saturation, dropout, interpolation, detection limits, uncertainty and
   model confidence. An observed clipped sample can remain a valid value.
   Define uncertainty units, coverage assumptions and correlations when an
   operator propagates them; an unexplained scalar confidence is insufficient.
   Sparse implicit zero, absent coordinate, masked measurement and SQL NULL must
   remain distinguishable through slicing, joins, aggregates and export.
3. **Deliver bounded named-axis dense and sparse arrays.** Specify chunk shape,
   coordinate selection, transposition, broadcasting/alignment rules and owned or
   borrowed batch lifetimes. Use paged directories and bounded tile workspaces;
   array cardinality is independent of resident memory. Preserve specialized
   waveform, raster, mesh and sparse-matrix layouts instead of forcing every
   workload through a generic cell representation. Qualify range reads, partial
   chunks and cross-chunk neighborhoods over existing storage owners.
4. **Define numerical and incremental operator contracts.** Classify dependencies
   as pointwise, finite window/halo, graph frontier or whole-input, with explicit
   boundary conditions, late-data policy and insert/update/retraction support.
   Bind reduction order, rounding, overflow, non-finite handling and reproducibility
   class. Lossless, bounded-error and perceptual codecs have different contracts;
   an algorithm name alone establishes none. Pruning must use proven conservative
   bounds under approximation or decline the optimization. Global normalization,
   iterative solvers and gated loudness require their actual dependency state.
   Incremental results must agree with finite recomputation under the declared
   equality/tolerance; otherwise use a bounded rebuild or typed refusal.
5. **Qualify shared kernels and adapters.** Start with axis slicing/alignment,
   reductions, resampling and bounded stencil operations, then selected masked
   sparse matrix/vector operations with explicit algebraic identities and fill
   behavior. Keep graph traversal, numeric matrix arithmetic and biological
   matrices independently qualified. Extend the foreign owner with selected
   Zarr/NetCDF-CF/GRIB2/COG profiles, plus a scoped astronomy profile such as FITS.
   Capture exact manifests, coordinate metadata, quality variables and source
   byte ranges. Unsupported calendars, units or compression modes reject
   explicitly. List format versions and supported read/write directions.
6. **Publish attributable numerical results.** Freeze source cuts or an explicitly
   non-atomic source vector, interpretation/calibration revisions, executable
   digest, parameters, environment, random seed where relevant, tolerance and
   budgets. Reuse the managed computation/result owners for acceptance, progress,
   recovery and complete publication. Define artifact retention and authorized
   reuse; content identity grants no access. Bitwise reproducibility, agreement
   within tolerance and statistical repeatability are distinct claims.

## First acceptance journey

An application declares a forecast cube with issue time, valid time, ensemble,
spatial coordinates and quality masks, then joins a bounded region to an exact
asset-table basis. It answers which facilities were exposed using information
available before an incident. A later correction produces a successor result;
the original knowledge cut remains inspectable. Show missing ensemble members,
incomplete capture, interpolation and approximation without presenting them as
complete exact observations.

The companion calibrated-sensor journey captures samples, applies a versioned
calibration, derives features, revises the calibration and identifies affected
results. The full synchronized replay and physical-action boundary belong to
[Robotics](38-robotics-and-sensor-replay.md).

## Completion evidence

- Compare native and foreign arrays with independent value/coordinate oracles,
  including unit conversion, irregular axes, non-Gregorian calendars, sparse
  zeros, quality masks and calibration changes across validity boundaries.
- Compare tiled and incremental execution with whole-input reference results for
  every declared operator, including halos, retractions, empty inputs, catastrophic
  cancellation, non-finite values and conservative pruning near error bounds.
- Exercise datasets larger than RAM/cache, budget refusal/spill, cancellation,
  missing source chunks, lost acceptance replies and restart during publication.
  Partial staging or a finite display window cannot establish complete coverage.
- Recheck current rights for source metadata, cached artifacts and buffered or
  terminal results. Prove retained interpretations survive rename/compaction and
  fail explicitly when their source retention is unavailable.
- Record decoded bytes, range reads, warm allocations, resident/spill storage,
  error, time to first usable output and verified completion under mixed load.
  Publish actual format/operator support and exclusions with their public owners.

## Primary references

- [Zarr core specification](https://zarr-specs.readthedocs.io/en/latest/v3/core/index.html)
  for chunked arrays and named dimensions.
- [CF conventions](https://cfconventions.org/cf-conventions/cf-conventions.html)
  for coordinates, calendars, units and ancillary quality evidence.
- [GraphBLAS](https://graphblas.org/) for sparse algebra; an API reference does not
  add an upstream runtime dependency or prove incremental support.
- [zfp compression modes](https://zfp.readthedocs.io/en/release1.0.0/modes.html)
  for the distinction between reversible and bounded-error profiles.
