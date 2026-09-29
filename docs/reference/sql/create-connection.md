# CREATE CONNECTION

**Grammar only.** This statement describes a named connector configuration.
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

The option names above illustrate the grammar; they are not an implemented SQL
configuration schema. The reference parser does not check unknown or duplicate
options, resolve the credential binding or validate destination policy.

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

Source: [`createConnection`, `connectionOptions`, `secretRef`](../../../contracts/sql/TransitExtensions.g4).
