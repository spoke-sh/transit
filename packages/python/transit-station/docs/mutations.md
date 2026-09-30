# Table mutation callers

`transit_station.mutations.Client` and `AsyncClient` expose bounded SQL INSERT,
primary-key UPDATE and DELETE through the shared Zig mutation caller. An
explicitly provisioned writer/resource/Table connection and principal seed are
required. The writer must expose the mutation operation and authorize the caller
through its separate policy; query access alone does not enable writes.

```python
from transit_client import ProcessRef, ResourceRef
from transit_station import mutations

connection = mutations.Connection(writer, resource, table_id)
with mutations.Client(url, principal, seed_file, connection) as client:
    metadata = client.describe()
    compiled = client.compile_sql("items", "UPDATE items SET value=12 WHERE id=7", namespace)
```

`writer` and `resource` are realm-qualified `ProcessRef` and `ResourceRef` values.
Namespace is an application-selected positive uint64. `Compiled` owns canonical
request bytes and a complete `Reference`; persist both unchanged before upload.
It neither reserves the row nor proves admission. One Table batch has at most
three rows and the [shared mutation rules](../../../../contracts/TABLE_MUTATION_V1.md)
define types, conflicts, atomicity and current authority checks.

Call `prepare_next(compiled)` for one stage, persist its opaque `Prepared.data`,
then call `submit(prepared)`. Submission returns an admitted input position.
On `UncertainOperation`, retain `error.recovery` and resubmit the identical
`Prepared` bytes, including after replacing the client. Do not recompile or
select another stage while the original send is unresolved. Observe that input
as `Observation.PROCESSED`, then check `rejection(prepared, position)` before
preparing a successor. A separate input rejection cannot overwrite a request's
terminal status.

A null next command requires `status(compiled.reference)`: `Phase.APPLIED`,
`REJECTED` and `CANCELLED` are distinct. `affected_rows` is the durable result
only at application; an admission receipt is not a row count. `prepare_apply`
and `prepare_cancel` expose explicit controls. Cancellation cannot undo applied
rows. Policy or native-grant denial remains an error or recorded outcome under
the shared contract, never an automatic new command.

Descriptions, compiled values, prepared bytes and status data are owned Python
values. Saved command bytes remain opaque; references and schema commitments
confer no authority. Current native read grants gate all observations.

Each client owns one bounded native worker with the required stack. Overlap
rejects with `Busy`; there is no implicit upload loop, retry queue or principal
sequence coordinator. `close` joins active work. Async methods have the same
names and use `await`; cancellation of an await leaves the native operation
owned until it finishes. Use `async with` or await `close()` to join destruction,
and retain recovery bytes independently of host tasks. Importing the module
loads no key and creates no caller.
