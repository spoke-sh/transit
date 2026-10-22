# 1. Storage and query performance

[Roadmap](README.md) · [Issue #76](https://github.com/spoke-sh/transit/issues/76)

Reduce remaining end-to-end costs before adding storage-heavy historical and
branching features. The [performance reference](../reference/performance.md)
describes measurements; the [storage reference](../reference/storage.md) owns
existing block publication, concurrent requests and reclamation.

## Remaining work

1. Reproduce matched current-source controls. Attribute statement ingestion,
   gateway coordination, schema resolution, source reads, vector execution,
   publication and completion separately.
2. Bound and batch larger statement ingress and remove redundant coordination.
   Preserve accepted operation identity through lost responses and permission
   changes; retries must not become new writes.
3. Compare durable row, column and index layouts for scans, point/range access,
   composite keys, wide/nested values and mutations. Select formats from evidence,
   with bounded pages, caches and candidates.
4. Add workload-specific indexes and statistics with explicit identity,
   invalidation, recovery and current-authorization contracts.
5. Separate row count, retained history, cache size, readers, skew and value width.
   Measure offered-load capacity and control latency under slow storage, quotas
   and maintenance.

## Completion evidence

Require independently verified values/counts, matched ReleaseSafe controls, raw
samples, sufficient observations for percentiles and explicit remaining regressions.
Report requests/bytes, memory and retained storage alongside latency.

Qualify lost receipts, denial after buffering, schema/name reuse, atomic visibility,
fencing, storage pressure and incomplete-result rejection through affected callers.
Tighten regression ceilings only after attributable end-to-end improvements.
