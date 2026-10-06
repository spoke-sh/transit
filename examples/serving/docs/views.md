# Live consumer placement

The live composition uses the real embedded Board and counter application,
`transit-serving-http`, one durable live requester, and a separate Table source.
Browser code is identical in native, Compose and reference placements. The
[reactive guide](reactive.md) owns the underlying transport/lease contract.

```sh
nix develop
just transit-board::install
just test::reactive-views
just test::reactive-views-lifecycle
just test::reactive-views-placement compose
just test::reactive-views-placement reference
```

Each task owns temporary state and cleans up its own services. Reference requires
the already prepared pinned infrastructure/runtime image and creates a separate
namespace. It does not update the default launcher installation. The browser
trusts only its fixture TLS certificates. Board uses an inspection principal
separate from the query/watch caller; the counter gets a separate scoped caller
permitted to render its bounded application snapshot. Both receive explicit
catalog inspect/read policies, independently of native resource grants. The
configured source carries the discovered immutable metadata and logical row
descriptor. Root credentials remain
with the fixture operator and are never mounted in the gateways or workers.

Compose runs static Zig binaries in the existing private client/storage networks.
The reference runs application/requester workers under fresh Substrate/gVisor
activations and gateways in egress-constrained pods. Replacing a native grant
starts a new principal incarnation, so registration reissues intended local and
foreign query-resource rights before claiming the next ownership generation.
Optional associations supply scope, not permissions.

TLS termination and browser supervision run on the operator host. The explicit
clock/expired-session observer also runs there under its dedicated non-root
identity. Compose places the delivery courier in a container; reference keeps
the courier on the operator as in the existing finite query/serving examples.
This is operator-controlled placement, not an automatic growing runtime controller.
Owned reference port-forwards keep their ports while pods restart; a stable URL
does not establish authority or extend a lease.

The physical proof stops workers, both gateways, the node and disk store after a
20-row query is completely verified. It then retrieves the same result through
a fresh authorized page read. A retained display alone cannot prove recovery.
The browser subsequently follows the submitted plan under a new finite refresh
identity. Lost admission replies preserve the exact original signed request.

The selected profile has four sessions/service, two/caller, one subscription per
session, at most eight starts per explicit Follow generation and one active query
per requester. It verifies a complete query a page at a time, discards those
prefixes, then rereads the visible page with current authority. The first Compose
schedule measured 7.2 seconds to a counter update and 102 seconds to a verified
20-row refresh; these are single-run observations, not freshness guarantees.
No retention opt-in is implicit: clock/control records and accepted results stay
retained. The [test ledger](../../../tests/README.md) owns current proof status,
failure schedules, durations and storage observations.

The extended reference schedule passed in 518.32 seconds (663.06 seconds with
packaging/placement): counter visibility 6,223 ms, same-result physical recovery
18,338 ms, and complete finite refresh 155,111 ms. Observed browser heaps were
10,397,376 bytes for Board and 4,637,604 bytes for the counter, below the fixture's
128 MiB per-page ceiling. It revoked only entry reads after verifying the last
candidate page and before the visible reread, then observed protected-state
clearance. The cold backend retained 504 objects / 57,849,285 bytes. These finite
measurements do not establish sustainable throughput or peak heap across all
browser execution.
