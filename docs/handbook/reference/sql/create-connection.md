# CREATE CONNECTION

**Native cohosted SQL supports durable HTTP connection declarations.** A
CONNECTION names an HTTP origin. Publication stores metadata and grants no
credentials, network access or effect authority. It does not contact the origin.

## Syntax

```sql
CREATE CONNECTION usgs TO HTTP (endpoint = 'https://earthquake.usgs.gov');
SHOW CONNECTIONS;
SHOW CONNECTION usgs;
DESCRIBE CONNECTION usgs;
DROP CONNECTION usgs RESTRICT;
```

The installed profile accepts exactly one `endpoint` option. The origin has at
most 2,048 ASCII bytes and excludes user credentials, a query, fragment and a
non-root path. Names share the current schema namespace with other Catalog
objects. Reusing an occupied name is a conflict. Bare DROP has the same RESTRICT
behavior; a connection referenced by a SOURCE cannot be dropped.

Creation requires schema CREATE and selection of the declaration's owner through
native authorization. Metadata requires CONNECTION inspection; binding a SOURCE
requires CONNECTION use. These rights remain separate. Inspecting a SOURCE's
reference does not disclose the connection's endpoint or confer its permissions.

SHOW and DESCRIBE return ordinary SQL result sets containing exact definition
identity, the original name and owner, and the current Catalog observation.
Listings are bounded, current-policy pages; they are not an atomic data snapshot.
The original creation receipt remains attributable after DROP and name reuse.

## Scope

The native console uses the same Catalog owner as typed callers. Migration files
reject connector declarations before admission. Explicit transactions,
PostgreSQL/MySQL, Flight SQL, standalone services and query-source sessions do not
execute these declarations. Board remains read-only.

The broader reference grammar permits other connector identifiers, options and
`SECRET('credential_reference')`. Those forms are not installed connection
configuration. HTTP polling, secret resolution and transport/TLS routing require
the separate execution integration. Existing [connector APIs](../connectors.md)
retain their own recorded-intent and authorization contracts.

Source: [`createConnection`, `sourceCommand`](../../../../contracts/sql/TransitExtensions.g4)
and [SOURCE_V1](../../../../contracts/SOURCE_V1.md).
See [CREATE SOURCE](create-source.md) for binding an existing Stream.
