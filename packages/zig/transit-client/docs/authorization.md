# Authorization administration

`AuthorizationClient` signs current authorization reads. `AuthorizationChange`
provides an explicit prepare/submit/observe lifecycle over the same native typed
actions. It owns no files, background loop or retry policy. Hosts retain records
and schedule bounded work. The [authorization contract](../../../../contracts/AUTHORIZATION_V1.md)
defines roles, privileges, staging, budgets and publication.

1. Read `.identity` through `AuthorizationClient.read` to obtain the current
   policy revision. Resolve names to stable IDs before preparing an action.
2. Call `AuthorizationChange.Client.prepare(revision, action)`. It performs a
   read-only preview and returns its evidence alongside a signed begin record.
   Inspect `preview.complete`: an incomplete preview requires further durable
   staging before dependency validation can finish. Preparation submits nothing.
3. Save `record.save(allocator)` durably before explicit `submit(record)`.
   Retain the exact pending bytes on a timeout, transport loss or uncertain
   result. Retrying that pending request cannot create a second native change.
4. Pass a successful native receipt to `record.received(receipt)` and persist
   the returned record. The begin receipt fixes the operation's durable ID.
5. Call `next(record)`. It returns the same pending record if an uncertain step
   remains, otherwise observes the original operation and prepares one bounded
   advance or publish. Save the returned record before submitting it.
6. A terminal result distinguishes `published` and `abandoned`. Publication
   changes one policy root. Observing a ready candidate does not grant access.

`observe` checks the original principal, policy basis and exact action against
the native operation ledger. `Record.restore` verifies the current definition
and signatures. Recovery does not resolve names again or replace a retained
begin. Concurrent policy changes reject with `StaleAuthorizationRevision`;
an explicit `abandon` can close a resolved, unpublished candidate. Revalidation
and a new change are separate actions, never an automatic retry.

The host must resolve an uncertain pending request before preparing abandonment.
Credential rotation may prevent resending an old signature; preserve its bytes
and call `recoverPending` with the principal's current credential. It queries
the receipt for the exact retained request body and returns an updated record
only if the native authority proves acceptance. An absent receipt leaves the
pending record unchanged; it does not authorize re-signing or replacing it.
Record restoration alone does not establish acceptance or current permission.
The native authority rechecks the original selected role on every advancing or
publishing command. Application files never grant rights.

Records are bounded to 32 KiB and contain public keys and signed operations, not
private keys. Prepared sequence numbers are not reservations: unrelated writes
by the same native principal can conflict, so the host serializes its submissions.
Multi-operation scripts have ordered, independent outcomes; this API does not
claim a transaction spanning multiple policy changes or domain owners.

`AuthorizationBridge` exposes the lifecycle as neutral `Connection`, `Action`
and `Result` values. Its connection requires the current definition. The shared
C ABI `transit_authorization_apply` returns an owned JSON buffer; the client host
accepts an `authorization` request containing the connection, action and private
seed-file reference. Only `submit` dispatches a command. `received` incorporates
a receipt; `restore`, `next`, `recover_pending`, `observe` and `abandon` preserve
the retained identity. Returned strings belong to the result arena/buffer.
Post-dispatch allocation failure remains an uncertain outcome.

Neutral input is bounded to 256 KiB. The [CLI guide](../../../../apps/transit-cli/docs/authorization.md)
describes private durable files and explicit bounded application of these steps.
