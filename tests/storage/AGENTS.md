# Working on storage checks

Follow [test instructions](../AGENTS.md), the [storage index](README.md) and owning
storage/retention contracts. Identify the accepted mutation, durable boundary,
backend, bounded resident work and observable recovery result before adding a
schedule. Direct WAL/Table data does not use the application actor model.

Keep local and Ursula fixtures explicit. Generic harness helpers must not choose
a backend implicitly. Use disk-backed Ursula where required and retain local
WAL/object acceptance independently. Never substitute tmpfs or a model for a
physical-disk requirement.

Preserve original operation bytes and accepted progress across process death,
unavailability and capacity failure. Retention is opt-in; quotas and outages do
not authorize expiry or deletion. Keep expiry, reconciliation and physical cleanup
distinct. Do not raise cardinality limits, deadlines or residency to hide a failure.

Keep independent encoding/format expectations, page sizes, fault schedules and
saved seeds intact during moves. Use the shared Python launcher, explicit binary
paths and qualified helper imports. Native fixtures crossing owners require
explicit Zig modules with shared type identities. Run affected real backend,
restart, denied-read and failure schedules; compiler and oracle checks alone do
not establish durability. Retain failed state privately and record results through
the runner.
