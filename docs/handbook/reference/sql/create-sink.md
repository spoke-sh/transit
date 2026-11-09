# CREATE SINK

**Native cohosted SQL publishes bounded HTTP sink declarations.** A sink names
an application effect target with an exact connection dependency and its own
native authority. Publication, explicit role authorization, desired activation,
inspection, retirement and restricted DROP are implemented. Application HTTP
dispatch remains unavailable.

## Syntax

```text
CREATE SINK name INTO HTTP CONNECTION connection_name WITH (
  method = 'POST', path = '/token', request_encoding = 'form',
  accept = 'application/json', response = 'protected_json',
  capture = 'redacted_metadata', request_timeout = '5s',
  response_max_bytes = 65536, follow_redirects = FALSE,
  max_attempts = 1, unknown_outcome = 'retain'
);
```

All options shown are required except `request_encoding`, which defaults to
`none` for GET. POST requires `form`; GET requires `none`. An optional
`user_agent` supplies an ASCII header value. Duplicate and unknown options
reject before admission. The sink has no polling executor or destination Stream.
It requires an existing connection and current permission to use it.

Paths retain exact origin-relative bytes and cannot override the connection's
origin. Accept and User-Agent values contain one through 256 printable ASCII
bytes. Request timeouts are positive integers with `ms`, `s`, `m`, `h` or `d`,
with overflow checked. Response budgets range from one byte through 64 KiB.
Only protected JSON responses, redacted metadata capture, one attempt, no
redirects and retained unknown outcomes are accepted. These options describe the
future dispatch boundary; they do not authorize a request or resolve secrets.

## Examples

These statements publish and inspect a declaration without sending HTTP:

```sql
CREATE CONNECTION remote_api TO HTTP (endpoint = 'https://example.test');
CREATE SINK profile INTO HTTP CONNECTION remote_api WITH (
  method = 'GET', path = '/profile', accept = 'application/json',
  user_agent = 'Example', response = 'protected_json',
  capture = 'redacted_metadata', request_timeout = '5s',
  response_max_bytes = 65536, follow_redirects = FALSE,
  max_attempts = 1, unknown_outcome = 'retain'
);
SHOW SINKS;
DESCRIBE SINK profile;
```

## Inspection, retirement and recovery

`SHOW SINK name` and `DESCRIBE SINK name` expose the immutable definition,
connection dependency, selected `executor_role`, current control epoch and Catalog position. Listings and
metadata use the same bounded, current-authority owner as
[SOURCE inspection](create-source.md#inspection-retirement-and-drop).
`EXPLAIN CREATE SINK ...` checks the exact proposal without allocating an
identity, reserving work or sending HTTP. Inspection is separate from `use`.

Authorize a published sink with an explicit existing role, then activate it:

```sql
AUTHORIZE SINK profile AS ROLE CURRENT_ROLE;
ACTIVATE SINK profile;
SUSPEND SINK profile;
RESUME SINK profile;
```

The shared SQL role forms accept a role name, `CURRENT_ROLE`/`CURRENT_USER` or
`SESSION_USER`; `PUBLIC` is invalid. Authorization resolves the name once and
retains its nonzero native ID. Activation and resumption check permission to
select that role. Suspension and retirement require administrative authority;
they do not require assuming the dispatch role. A later control cannot replace
the selected role. Each transition requires the observed control epoch.

`active` records desired activation. Until dispatch is installed, inspection
continues to report `execution_supported = false` and `never_run`. These controls
create no grants and make no HTTP request. Worker placement and current
connection, secret and effect authorization remain separate requirements.

The declared sink protects its connection from DROP. Retire the sink before
removing it:

```sql
RETIRE SINK profile;
DROP SINK profile RESTRICT;
DROP CONNECTION remote_api RESTRICT;
```

SQL recovery retains the original typed request and outcome across lost replies,
restart and name reuse. Reusing an accepted token cannot create a replacement
sink or substitute a different role. Migration-file installation is not yet supported.

## Meaning and current interface

Sinks are separate from Table and KV mutations. There is no `INSERT INTO sink`
or `SELECT INTO` binding. Use the existing [effect APIs](../connectors.md) for
supported HTTP/gRPC operations. A declaration or `use` grant alone cannot
permit dispatch, repeat an uncertain effect or promise remote cancellation.

Source: [typed SQL parser](../../../../packages/zig/transit-sql/src/SourceSql.zig),
[reference grammar](../../../../contracts/sql/TransitExtensions.g4) and
[application sink contract](../../../../contracts/SOURCE_V1.md#application-http-sinks).
