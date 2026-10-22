# Contracts and schema downloads

These downloads are copied byte-for-byte from the repository's contract owners
when the handbook is built. Use the matching source revision and current
definition when implementing an integration. A downloaded schema describes
shape; it does not provide authorization or prove an operation can execute.
See [versioning and hard cutovers](versioning.md).

## HTTP and reactive descriptions

| Description | Download | Usage |
| --- | --- | --- |
| Application Serving OpenAPI | [serving.openapi.json](../../../packages/zig/transit-serving/api/openapi.json) | [Serving HTTP](openapi.md) |
| Board OpenAPI | [board.openapi.json](../../../contracts/transit-board-v1.openapi.json) | [Board API](board-api.md) |
| Reactive AsyncAPI | [reactive.asyncapi.json](../../../packages/zig/transit-serving/api/asyncapi.json) | [Reactive channels](asyncapi.md) |

The reference pages render operations, messages and field tables from these
same sources. They do not collect credentials or send live requests.

## Native messages and configuration

| Description | Download | Exact contract |
| --- | --- | --- |
| Native protocol types | [transit-v1.schema.json](../../../contracts/transit-v1.schema.json) | [Native v1](../../../contracts/TRANSIT_V1.md), [signed HTTP](../../../contracts/SERVICE_V1.md) |
| SQL session routes and messages | [sql-session-v1.schema.json](../../../contracts/sql-session-v1.schema.json) | [SQL sessions](../../../contracts/SQL_SESSION_V1.md) |
| Table mediation messages | [table-service-v1.schema.json](../../../contracts/table-service-v1.schema.json) | [Table service](../../../contracts/DECLARATIVE_CATALOG_V1.md) |
| Configuration service messages | [configuration-v1.schema.json](../../../contracts/configuration-v1.schema.json) | [Configuration](../../../contracts/CONFIGURATION_V1.md) |
| Setting keys, defaults and bounds | [configuration-settings-v1.json](../../../contracts/configuration-settings-v1.json) | [Configuration reference](configuration.md) |
| Structured diagnostics | [diagnostic-v1.schema.json](../../../contracts/diagnostic-v1.schema.json) | [Diagnostics](../../../contracts/DIAGNOSTICS_V1.md) |
| Application installation | [application-installation-v1.schema.json](../../../contracts/application-installation-v1.schema.json) | [Installation](../../../contracts/APPLICATION_INSTALLATION_V1.md) |

These are native schema documents, not OpenAPI routes. Follow each owner's
encoding, canonicalization and compatibility rules in addition to validating
message structure. Fixed byte arrays, signed values and logical SQL cells must
retain their specified representation.

Wire specifications, signing fixtures, SDK ABI declarations, SQL grammars and
upstream protocol pins remain in the [contract directory](../../../contracts).
The [interface map](interfaces.md) connects each public surface to its usage
reference and internals. Generated files are updated by their owners; the site
does not maintain an independent protocol definition.
