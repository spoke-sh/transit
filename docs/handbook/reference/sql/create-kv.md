# CREATE KV

**Offline compiler; no publication.** Fuze's Zig `Declaration.compile` validates
this statement as a named KV definition and formats it for review. It does not
provision state, choose a writer or install a decoder. SQL query interfaces
reject it; CLI, Board and language SDKs have no administrative route for it.

## Syntax

```text
CREATE KV name (data_type);
data_type := INT64 | BOOL | UTF8 | BINARY
```

`name` is an identifier. Exactly one type token is required. This rule has no
key declaration, initial entries, nullability, retention options or
`IF NOT EXISTS` clause. It does not define a byte codec or an executable type
binding for the resource.

## Examples

These examples compile as offline definitions:

```sql
CREATE KV settings (UTF8);
CREATE KV counters (INT64);
```

## Meaning and current interface

The form describes a typed [KV object](../state.md). Its executable typed
interface is the [direct KV API](../../../../packages/zig/transit-catalog/docs/direct-kv.md):
explicit catalog declaration, atomic put/remove batches, point reads and retained
pins. These operations use `KVPartition` and current KV policy without a writer
PID. They are separate from this offline SQL form; the compiler does not submit
or execute a declaration.

Native private state used by Station retains its own resource and turn contract.
[Growing client operations](../../../../packages/zig/transit-client/docs/growing.md)
and [application installation](../applications.md#installation-and-bootstrap)
provision that state. Unified SQL's native KV source still needs an explicitly
declared decoder and schema; it does not implicitly query named direct KV.
See [query source profiles](../queries.md#source-declarations).
The [offline declaration contract](../../../../contracts/STATE_DECLARATION_V1.md)
defines owned names, complete-input validation, canonical formatting and bounds.

Source: [`createKv`, `dataType`](../../../../contracts/sql/TransitExtensions.g4).
