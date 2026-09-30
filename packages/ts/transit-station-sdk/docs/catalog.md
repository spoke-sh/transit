# Catalog callers

`catalog.Client` from `@transit/station` exposes initialization, conditional policy,
named Table creation and exact saved-command recovery through the shared native
port. Provision the catalog host, native resource, ownership and caller grants
explicitly. Query connections do not enable catalog administration.

```typescript
import { ProcessRef, ResourceRef } from "@transit/client";
import { catalog } from "@transit/station";

const scope = new catalog.Scope(new ResourceRef(realm, resource), catalogId);
const connection = new catalog.Connection(new ProcessRef(realm, owner), scope);
const client = await catalog.Client.open(config, credential, connection);
try {
  const compiled = await client.compileSql(
    "CREATE TABLE items (id INT64 NOT NULL, value UTF8 NULL)",
    operationId,
    objectId,
    tableId,
  );
  const prepared = await client.prepareCreate(compiled.request);
  await savePrepared(prepared.data); // Application-owned durable persistence.
  const receipt = await client.submit(prepared);
} finally {
  await client.close();
}
```

`config` selects `native_v1`, the URL, optional `timeoutMs` and optional
`nativeHost`; `credential` is a `Credential` in the same realm. The installed
Station host is selected by default. Opening starts one owned child, loads its
supplied key and checks the exact contract definition and local capabilities.
Importing starts no process or credential access. URLs are at most 2048 UTF-8
bytes; timeout is 1–60000 milliseconds, default 5000.

`Scope.catalog`, `CreateTable.operation`, `CreateTable.objectId` and policy
revisions are full-width uint64 `bigint` values. Native IDs remain separately
bounded safe-integer numbers; the physical Table ID is a positive uint32.
`Schema` owns two frozen names and a `CellType`. Compilation requires an explicit
non-null int64 key and an explicitly nullable value. It is offline after caller
creation: no identity is reserved and no authority is granted. `Compiled.canonical`
returns a copy of current-definition record bytes for review; preparation takes
the complete typed `compiled.request`.

## Explicit preparation and outcomes

`prepareInitialize(new Configuration(scope, ownerRef, administrator))` prepares
the host's exact immutable configuration. `preparePolicy(new PolicyChange(
expectedRevision, policy))` prepares an administrator control. Construct `Policy`
with scope, principal, revision, inspect and create fields; expected revision
`0n` denotes an absent policy. The shared Zig owner validates successor revisions
and checks current metadata. The host rechecks authorization and conditions at
application. `describe()` reads currently authorized configuration and policy.

Every preparation returns an immutable `Prepared` with opaque canonical text in
`data`, bounded to 8192 bytes. Persist it unchanged before submission. Only
`submit()` dispatches, returning an `AdmissionReceipt`. Observe that exact saved
command and receipt position with `observe()`, then inspect separate outcomes.
`inputDisposition()` returns an initialization/policy/rejected-input outcome or
`undefined`; absence alone proves no outcome. `status(originalRequest)` returns
the original creation receipt or `undefined`. Only its `"applied"` outcome
establishes publication. Name, object and Table conflicts are distinct terminal
outcomes. Processing is separate from application; current catalog and native
rights still gate disclosure.

`catalog.Uncertain` retains the original `prepared` object. Recreate the client
if necessary and resubmit the identical saved text with the same connection and
credential. Do not parse/re-encode, re-sign or replace it while admission remains
unresolved. Missing or malformed success responses also preserve uncertainty.
Definite native rejections retain their status/code. Deleting local recovery data
or abandoning a promise does not cancel accepted work.

Generated runtime schemas validate both sides of the port. Public adapters also
validate canonical full-width values and original-request status matching.
Scope/schema/request/control objects are frozen; compiled byte getters return
copies and disposition payloads are owned arrays. One operation is active at a
time; overlap rejects with `Busy`. There is no retry queue, provisioning loop or
principal sequence coordinator. `close()` joins active work and the child before
releasing ownership. Keep recovery material independently of host promises.

The [catalog contract](../../../../contracts/DECLARATIVE_CATALOG_V1.md) owns atomic
publication, authority and recovery semantics. The [proof ledger](../../../../tests/README.md)
records installed-package recovery and injected malformed-host cases separately.
