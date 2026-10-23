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

Neutral input is bounded to 256 KiB. The host owns durable record files and
schedules each explicit step through this shared lifecycle.

## Scoped changesets

`AuthorizationSet` reconciles explicit grant, membership and default-grant
intents. A document requires the current definition, realm, base policy revision,
managed scope and 1–32 intents. Scope lists protected objects, membership pairs
or creator/schema/domain default targets. Up to 32 scope entries are allowed.
Each intent must fall within that scope; duplicate targets for the same grantee
or membership pair reject. Names are already resolved to stable IDs.

The six intent tags are `grant`, `revoke`, `membership`, `revoke_membership`,
`default_grant` and `revoke_default`. They use the corresponding native action
fields (`revoke_privileges`, `revoke_role` and `revoke_defaults` for the removal
forms). Adds merge privileges under the original grantor; option removal and
RESTRICT/CASCADE remain explicit. Omitted entries never revoke permission.
Scope limits what the document can express; it grants no authority to its signer.

Preparation signs the complete document, principal and selected role, and
previews/prepares its first native change without dispatch. The preview describes
that first change only. Later intents are validated in order against the previous
published policy revision. Each change has a separate atomic publication; the
whole document is **not atomic**. An intervening policy revision rejects the
remaining work. No rebase, rollback or compensating mutation occurs implicitly.

The record retains every completed native outcome and one exact current change.
`next` first checkpoints a completed change, then prepares the next intent on a
subsequent invocation. `observe` and submission verify recorded completions
against the native ledger. Unknown sends use the same receipt recovery as an
individual change; changing the connection's selected role cannot replace the
document's sealed role. Key rotation can recover earlier receipts and sign later
steps using the principal's new credential. Saved documents are limited to
128 KiB. `Record.restore` requires an arena whose lifetime contains the record.

The neutral bridge's `changeset` action wraps the same prepare/restore/next/
submit/received/recover_pending/observe/abandon operations. A resolved current
candidate can be abandoned; earlier publications remain applied. Role creation,
credential changes, object provisioning and data changes have their own explicit
lifecycles and are not inferred from this grant document.
