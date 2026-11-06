# CREATE SOURCE

**Typed parser and reference grammar; execution is not installed.** A SOURCE
declares HTTP ingestion into an existing retained Stream. It does not create
that Stream, grant permissions, start polling or become a relation for SELECT.

## Syntax

```text
CREATE SOURCE name FROM HTTP CONNECTION connection_name
  INTO STREAM destination
  WITH (method = 'GET', path = '/feed', poll_interval = '5m',
        request_timeout = '10s', response_max_bytes = 4194304);
```

The destination is a structural dependency, expressed by `INTO STREAM`.
`capture_stream`, `read_mode`, `poll_ms` and `timeout_ms` are not options.
The earlier reference-only query-adapter form without INTO has been removed.

The dedicated typed parser accepts HTTP GET with all five options, each exactly
once. Unknown, missing, duplicate and mistyped options reject. Durations use
positive unsigned integers and `ms`, `s`, `m`, `h` or `d`; conversion to
milliseconds rejects overflow. `response_max_bytes` is a positive integer, not a
quoted string. The path must be origin-relative and cannot replace the
connection's authority. These checks neither bind catalog objects nor establish
capacity or dispatch authority. The broader reference grammar accepts connector
identifiers and option names without semantic validation.

## Example

This example is parser input only. Installed SQL does not execute it:

```sql
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
```

The destination schema is explicit: non-null `capture_id UUID`,
`source_sequence UINT64`, `observed_at TIMESTAMPTZ`, `http_status INTEGER`,
`body_ref BINARY`, `body_bytes UINT64` and `body_sha256 BINARY`. Binding must
resolve stable column IDs, match exact types and reject extra columns, defaults,
partition routing and compaction. Large response bodies belong in retained
chunked capture storage; `body_ref` is not a URL, bearer capability or an inline
4 MiB value. The pure `SourceBinding` validator checks a supplied schema and
policy; live catalog binding and capture storage remain unimplemented.

## Lifecycle and current interface

These forms have typed parsing and reference grammar, without installed execution:

```sql
AUTHORIZE SOURCE quake_feed;
ACTIVATE SOURCE quake_feed;
SHOW SOURCES;
SHOW SOURCE quake_feed;
DESCRIBE SOURCE quake_feed;
SUSPEND SOURCE quake_feed;
RESUME SOURCE quake_feed;
RETIRE SOURCE quake_feed;
DROP SOURCE quake_feed;
```

`EXPLAIN CREATE SOURCE ...` accepts the same declaration. Parsing and inspection
must never send a request. The [source contract](../../../../contracts/SOURCE_V1.md)
defines the required lifecycle, original-attempt fencing, complete capture,
Stream disclosure and common publication boundary. Its neutral validators do not
implement durable scheduling or authorize effects. Activation remains unavailable
until those owners and their recovery proofs are integrated.

SOURCE supplies raw HTTP observations. Latest-success selection, JSON decoding,
Table replacement and downstream alerts are separate computations. A complete
HTTP response need not be valid application data; a failed or partial capture
must not masquerade as an empty successful feed.

Use the existing [connector APIs](../connectors.md) for recorded remote effects
and configured [query sources](../queries.md#source-declarations) for executable
reads. Knowing a source name grants neither dispatch nor read rights.

Source: [`createSource`, `sourceCommand`](../../../../contracts/sql/TransitExtensions.g4)
and [`SourceSql`](../../../../packages/zig/transit-sql/src/SourceSql.zig).
See also [CREATE CONNECTION](create-connection.md), [streaming and effects](streaming.md)
and [syntax](syntax.md).
