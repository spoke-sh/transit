# Catalog query owner v1

`transit-query.CatalogQueryOwner` composes the public general Table lifecycle
owner and finite durable query engine in one Station activation. Install both
its handler and input guard. Its configuration is the exact
`TableCatalogRecords.Configuration`; no Table is selected by position, and
configuration creates neither native grants nor process ownership.

## Initialization and delegation

Initialize through `TableControl.Command.initialize` authenticated as the
configured catalog administrator. Catalog configuration, initial schema,
input disposition and Station descriptor fit the four-write turn. Query ingress
requires that committed configuration and its exact realm/resource/owner.
Changed configuration, poisoned reads and incompatible records propagate without
inventing a successful input disposition.

Requester delegation is a separate administrator cast. `PolicyChange` encodes
`CQG1`, expected previous revision u64 little-endian, and the complete 126-byte
catalog-target `UQA1` policy. The total is 138 bytes. The policy checks the shared
current definition before interpreting its target. Its revision must equal the
expected revision plus one; the previous revision may be zero only when there is
no policy for that requester. An exact current policy is idempotent. Missing or
foreign definitions, truncation, trailing bytes and declaration targets reject.

The policy binds requester PID, request resource, catalog scope, owner, explicit
expected original principal, allow flag and finite page/segment/byte limits. Only native
external input from the configured administrator may change it; a process with
the same numeric ID is not that principal. Scope and owner must match this
catalog. A stale expected revision records `stale_policy`; changed scope/owner
records `identity_conflict`; unauthorized input records `denied`. Successful
changes record `policy_applied`. All dispositions bind the original payload and
input position using the catalog's existing disposition format. Changed evidence
at an occupied input rejects. Policy plus disposition requires two writes.

The committed mapping cannot authenticate a user. A Table query carries a
signed original-subject proof bound to its immutable bytes, coordinator and
intended requester/resource. Capture, continuation and disclosure authenticate
that proof and require current CONNECT, schema USAGE and Table SELECT. The
expected principal must equal the verified principal. Table data privileges and
owner-only lifecycle changes remain independent. Revoking query delegation changes neither Table rows nor
catalog mutation permissions.

## Routing and recovery

Native process calls use the authenticated requester policy before request-body
access. One mapping may select any current authorized Table in its catalog;
the declaration binds its stable object, immutable metadata and complete schema.
Each admission retains one exact source cut. Four writes publish its initial
result budget, checkpoint, correlation index and job; no private initialization
can share that turn.

Cancellation indexes accepted work by the authenticated requester and original
correlation. Revocation does not erase that control identity. Only a native
self input may advance a query continuation. Foreign continuations receive an
input disposition and cannot alter job progress. Table commands and lifecycle
controls route to `TableBehavior`; SQL editing never dispatches these actions.

The [state query contract](UNIFIED_QUERY_V1.md) owns exact request/result bytes,
retained cuts, recomputation, publication, current disclosure, cancellation and
cleanup. The [Table lifecycle contract](TABLE_DDL_V1.md) owns Table lifecycle
and row mutation. Neither published chunks nor a private turn are committed
acceptance. Worker replacement still needs fresh fenced native ownership and
the host's exact saved commit recovery.
