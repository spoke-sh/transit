# Combined Table query/writer v1

`transit-query`'s `TableQueryWriter` composes the existing finite source and
Table mutation owners in one Station activation. Its caller requests, query
results and mutation results retain their existing contracts. The host installs
its handler and input guard together. It owns one existing native resource and
one typed Table; configuration never creates native grants or acquires ownership.

Configuration contains a complete `TableMutationWriter.Configuration`, one
query requester PID, its request resource, an explicit initial query `allow` flag
and finite query limits. The initializer is a nonzero native principal. All
identities and schemas use the existing owners' validation. Initial configuration
is immutable; current query and mutation policies are separate observed state.

## Initialization and readiness

Send the exact initializer cast from the configured initializer before exposing
caller ingress. The first turn creates the empty Table, stores the mutation
writer configuration and records the combined configuration in `staged` phase.
With Station's descriptor this uses four mutations. It atomically emits one
configuration-bound continuation to itself. Existing Table or source behavior
metadata rejects; this operation cannot adopt a separately initialized host.

The authenticated self continuation installs revision-one mutation and query
policies, the shared query source configuration, and the `ready` phase in four
mutations. No query or mutation runs through this host before that commit.
Repeated initializer casts and repeated completed continuations are no-ops.
A restart needs fresh fenced ownership and the exact original configuration;
accepted continuation output is durable and can be delivered again. The shared
Station host retains exact pending commits on ambiguous transport outcomes.

While staged, external inputs receive a separate `busy` mutation input
disposition. Process calls receive a `UQF1` admission failure with code `writer_not_ready`; other process inputs
receive a query input disposition. They do not apply rows, create query jobs or
replace terminal results. Configuration mismatch, poisoned reads and corruption
propagate, without consuming the input as a user rejection.

Readiness governs this host's dispatch. Native readers with existing resource
grants can observe the committed empty Table between the two phases. Provision
caller access after readiness when that intermediate metadata must be hidden.
The startup `service.ready` event still means activation readiness, not completion
of this durable initialization. `TableQueryWriter.phase(reader)` reads its state
under current resource authority and validates the supplied configuration.

## Routing and independent policy

After readiness, external mutation casts and mutation policy changes use
`TableMutationWriter`. Process query calls/cancellations and authenticated self
continuations use `UnifiedBehavior.Source`. Unsupported frame kinds are rejected
by the guard before Station's reply/timeout handlers run. Query read permission
does not grant mutation permission; native grants apply independently to both.

`QueryPolicyChange` is an initializer-only cast containing the resource, expected
previous revision and complete `UnifiedRecords.Policy`. Peer, request resource
and source declaration must match the configured source. A changed policy must
advance the expected revision by exactly one; an identical current policy is a
no-op. Revocation uses `allow=false`. Limits can change within the existing finite
query bounds. The mutation policy and Table data do not change. Existing query
jobs and result readers retain their current-policy checks; a changed query
policy does not rewrite an earlier query result.

Administrative rejection uses the existing `TME1` input disposition: `denied`,
`invalid_command`, `identity_conflict` or `stale_policy`. These are input outcomes,
not successful mutations. Query-origin rejections use the existing query input
disposition key. Current read grants apply to all observations.

## Exact encodings

All integers below are contiguous little-endian. Magic bytes are included in
the stated lengths. `TableMutationRecords.key('q',0,0)` owns the combined state.
Missing, truncated, trailing, unknown phase and mismatched configuration fields
reject. No old stored profile is inferred or converted.

| Value | Encoding |
| --- | --- |
| Configuration `TQC1`, at most 119 bytes | writer configuration length u8, complete `TMW1`, peer u64, requests u64, allow u8 (0/1), pages u64, segments u64, result_bytes u64 |
| State `TQW1`, at most 124 bytes | phase u8 (`staged=1`, `ready=2`), complete configuration |
| Initialize `TQI1`, 44 bytes | resource u64, SHA-256 of `transit.table.query.writer.v1` + NUL + complete configuration |
| Continue `TQR1`, 44 bytes | same resource and digest; accepted only from this PID |
| Query policy change `TQG1`, 138 bytes | resource u64, expected revision u64, complete 118-byte declaration-target `UQA1` |

Mutation uploads use Publication domain `table_mutation`; finite result records
use `query_result`. Equal full-width numeric namespaces cannot alias their
budgets, records, immutable indexes or cleanup. Request uploads remain in the
requester's `query_request` domain. Resident limits stay at four mutations per
turn, 256-byte values and the source's bounded adapter/Arrow workspaces. Durable
jobs, inputs and dispositions have no automatic expiry.

See [Table mutations](TABLE_MUTATION_V1.md), [finite queries](UNIFIED_QUERY_V1.md)
and the [executed proof ledger](../tests/README.md) for their contracts and evidence.
