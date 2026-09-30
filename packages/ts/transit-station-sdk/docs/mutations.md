# Table mutation callers

`mutations.Client` from `@transit/station` exposes bounded SQL INSERT,
primary-key UPDATE and DELETE through the shared Zig mutation caller. Supply an
explicit writer/resource/Table connection and credential. The writer must expose
that operation and authorize the caller through its separate mutation policy.
A read-query declaration or grant does not enable writes.

```typescript
import { mutations } from "@transit/station";

const connection = new mutations.Connection(writer, resource, tableId);
const client = await mutations.Client.open(config, credential, connection);
try {
  const metadata = await client.describe();
  const compiled = await client.compileSql(
    "items",
    "UPDATE items SET value=12 WHERE id=7",
    namespace,
  );
  await saveCompiled(compiled.request, compiled.reference.data);
} finally {
  await client.close();
}
```

`writer` and `resource` are realm-qualified `ProcessRef` and `ResourceRef` values;
`credential` is a `Credential` in that realm. `config` selects `native_v1`, the
URL, optional `timeoutMs` and optional `nativeHost`. The installed native Station
host is the default. Each client owns one child and one active operation.
Opening checks the exact generated contract definition; a v1 label alone does
not establish compatibility with another build.
Importing starts no child and reads no credential.

Namespace is a positive uint64 `bigint`. `Compiled` owns the canonical request
bytes and complete `Reference`; persist both unchanged before upload. Getters
return copies of byte arrays. Compiling does not reserve rows or prove admission.
The [shared mutation contract](../../../../contracts/TABLE_MUTATION_V1.md)
defines the three-row limit, scalar types, atomicity and current authority gates.

Call `prepareNext(compiled)` for one stage and persist the opaque `Prepared.data`
string before `submit(prepared)`. Submission returns an `AdmissionReceipt`, not
an applied row count. `mutations.Uncertain` retains the original `prepared`
object. Recreate the client if needed and resubmit those exact saved bytes;
do not recompile, parse/re-encode the saved text or choose another stage while
its admission is unresolved. Invalid or missing submit responses also preserve
uncertainty. Generated runtime schemas validate the native response boundary.

After admission, wait for `observe(prepared, receipt.position)` to return
`"processed"`, then inspect `rejection(prepared, receipt.position)` before
preparing a successor. Processing may record a separate input rejection while
leaving the mutation request unchanged. `prepareNext` returning `undefined`
requires `status(compiled.reference)` to distinguish applied, rejected and
cancelled outcomes. Only the durable applied result establishes `affectedRows`.
`prepareApply(reference)` and `prepareCancel(reference)` expose explicit controls;
cancellation cannot undo rows already applied.

Descriptions, references, prepared text and statuses are owned host values.
References and schema commitments confer no authority; observations require
current native read grants. Overlapping work rejects with `Busy`. There is no
implicit upload loop, retry queue or principal sequence coordinator. Dropping a
promise does not cancel native work; `close()` joins the active operation and
child before releasing ownership. Retain saved recovery data independently of
host tasks.
