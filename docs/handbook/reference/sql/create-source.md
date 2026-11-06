# CREATE SOURCE

**Native cohosted SQL supports durable SOURCE declarations and inspection.**
A SOURCE declares HTTP ingestion into an existing Stream. Publication records
`published`, epoch one, with `execution_supported = false` and `never_run`.
Polling and capture execution are not installed.

## Syntax and binding

```text
CREATE SOURCE name FROM HTTP CONNECTION connection_name
  INTO STREAM destination
  WITH (method = 'GET', path = '/feed', poll_interval = '5m',
        request_timeout = '10s', response_max_bytes = 4194304);
```

The destination is a structural dependency expressed by `INTO STREAM`.
`capture_stream`, `read_mode`, `poll_ms` and `timeout_ms` are not options.
All five HTTP options are required exactly once. Durations are positive unsigned
integers with `ms`, `s`, `m`, `h` or `d`; conversion rejects overflow.
`response_max_bytes` is a positive integer literal. The origin-relative path
cannot replace the connection's authority. Validation grants no execution capacity.

The selected SQL database binding must contain an explicit `source_executor`
principal. For a local console, configure `sql.native.source_executor` before
creating its account; network accounts use `sql.accounts[].source_executor`.
Omission rejects CREATE SOURCE before admission. The binding is part of the
account's identity and cannot be changed by editing an existing account's saved
configuration. Transit does not substitute the submitting caller or grant the
executor permissions, credentials or dispatch authority.

## Example

With the executor configured, these statements publish declarations:

```sql
CREATE STREAM quake_captures (
  capture_id UUID NOT NULL,
  source_sequence UINT64 NOT NULL,
  observed_at TIMESTAMPTZ NOT NULL,
  http_status INTEGER NOT NULL,
  body_ref BINARY NOT NULL,
  body_bytes UINT64 NOT NULL,
  body_sha256 BINARY NOT NULL
);
CREATE CONNECTION usgs TO HTTP (endpoint = 'https://earthquake.usgs.gov');
CREATE SOURCE quake_feed
  FROM HTTP CONNECTION usgs
  INTO STREAM quake_captures
  WITH (
    method = 'GET',
    path = '/earthquakes/feed/v1.0/summary/all_day.geojson',
    poll_interval = '5m',
    request_timeout = '10s',
    response_max_bytes = 4194304
  );
SHOW SOURCE quake_feed;
```

The seven non-null columns are matched by name and exact logical type,
independently of physical order. Binding freezes their stable column IDs and
rejects additional columns, defaults, partition routing and compaction. The
initial profile requires HTTP GET, branch one, the same Catalog and one Stream
partition. SOURCE neither creates the destination nor changes its schema,
retention or grants. `body_ref` is a future retained capture descriptor, not an
inline response body, URL or bearer capability.

## Inspection, retirement and DROP

```sql
SHOW SOURCES;
SHOW SOURCE quake_feed;
DESCRIBE SOURCE quake_feed;
RETIRE SOURCE quake_feed;
DROP SOURCE quake_feed RESTRICT;
DROP CONNECTION usgs RESTRICT;
```

`EXPLAIN CREATE SOURCE ...` resolves and checks the same proposal, including its
executor and exact dependencies, without allocating an identity, reserving work,
staging bytes, registering a permission object or sending an HTTP request.

SHOW/DESCRIBE are ordinary typed SQL results. Exact metadata includes the
immutable definition, executor, dependency identities, current control epoch and
Catalog position. Poll and publication positions remain absent. Listings scan
at most 32 Catalog entries and return at most four summaries per native page;
SQL consumes these pages with bounded buffers. Current rights are checked before
disclosure, including repeated and terminal batches. These are live Catalog
observations, not an atomic snapshot of concurrently changing names.

Creation requires schema CREATE, ownership selection, CONNECTION use and Stream
inspection/append rights. SQL name resolution also requires CONNECTION inspection;
the typed publication request can bind a known definition using CONNECTION use.
SOURCE metadata requires its own inspection grant.
Publication reserves one registered SOURCE writer per destination object;
ordinary Stream producers retain their existing append semantics. Changing a
bound Stream definition invalidates an unpublished proposal. A published source
retains its original binding and reports `definition_changed` instead of following
a replacement. It continues to prevent dependency DROP.

RETIRE changes `published` to `retired` and increments the epoch without changing
the immutable definition. It retains the name, dependency edges and writer slot.
DROP requires retirement, no dependents and no outstanding original work, then
removes live visibility and releases the edges and slot. Bare DROP also means
RESTRICT; CASCADE is unsupported. The destination Stream remains intact.
Original receipts and definitions remain attributable after DROP and name reuse.
Commands report original applied/rejected/cancelled outcomes with no data-row
counts. A lost response is resolved through the original token, never by
reparsing accepted SQL against new names.

## Execution boundary

AUTHORIZE, ACTIVATE, SUSPEND and RESUME have typed syntax but reject before
admission at both SQL and typed Catalog boundaries. No operation in this profile
polls, appends a capture row or creates a capture body. A SOURCE is not a SELECT
relation. Explicit transactions, PostgreSQL/MySQL, Flight SQL, standalone services
and query-source sessions do not execute this profile.

Latest-success selection, JSON decoding, current-Table replacement and alerts
remain separate work. Existing [connector APIs](../connectors.md) and configured
[query sources](../queries.md#source-declarations) retain their own execution
contracts. See [SOURCE_V1](../../../../contracts/SOURCE_V1.md) for exact identities,
limits, authority and the future capture/publication gates.

Source: [`createSource`, `sourceCommand`](../../../../contracts/sql/TransitExtensions.g4)
and [`SourceSql`](../../../../packages/zig/transit-sql/src/SourceSql.zig).
See also [CREATE CONNECTION](create-connection.md) and [streaming and effects](streaming.md).
