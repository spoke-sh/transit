# CREATE CONNECTION

**Reference grammar and a limited typed parser; execution is not installed.**
This statement describes a named connector configuration.
The console, Board query workspace and Flight SQL do not execute it, resolve
credentials or open a connection.

## Syntax

```text
CREATE CONNECTION name TO connector_kind (option = option_value [, ...]);
option_value := 'text' | SECRET('credential_reference')
```

`name`, `connector_kind` and option names are identifiers. The option list is
required and nonempty. The grammar accepts any connector-kind identifier, such
as `HTTP` or `GRPC`; it does not establish support for an arbitrary connector.
Values are strings or secret references, never bare numbers or booleans.

## Example

This example illustrates syntax only:

```sql
CREATE CONNECTION remote_api TO HTTP (
  endpoint = 'https://api.example.test',
  token = SECRET('service_token')
);
```

The example above illustrates the broader reference grammar. The separate
`SourceSql` typed parser accepts only HTTP with one `endpoint` origin option;
it rejects credentials, a query/fragment and a non-root path in that origin.
It does not support the illustrated token option. Neither parser publishes a
connection or validates dispatch authority.

## Meaning and current interface

A connection declaration represents reusable connector configuration, separate
from an authorized effect attempt. `SECRET` names a credential binding and must
not contain a resolved credential. Recording configuration cannot grant dispatch
authority or make a remote retry safe.

Use the existing [connector APIs](../connectors.md) and their owning HTTP/gRPC
configuration instead. [Security](../security.md#effects-and-secrets) defines
credential resolution and capture rules. [CREATE SOURCE](create-source.md) and
[CREATE SINK](create-sink.md) reference connection names in the grammar, but do
not execute those APIs.

Source: [`createConnection`, `connectionOptions`, `secretRef`](../../../../contracts/sql/TransitExtensions.g4).
