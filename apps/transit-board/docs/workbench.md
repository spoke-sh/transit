# Data workbench

Board presents catalog definitions, typed data and observed query results through
public Transit callers. Its built-in home opens Catalog. Published interfaces
keep their declared entry screen; Catalog and Workbook also have fixed routes.
Operations retains the atlas, resource/connector inspectors, finite Live,
relational recovery and application-definition controls with their existing
separate capabilities.

## Configure data access

Inspection remains read-only and uses its original principal. Data exploration
requires explicit connections; startup never copies a local owner's credentials
or grants data access. Every viewer admitted by Board's private deployment
boundary shares these configured connections. Keep keys and password files on
the service host.

For `transit server`, set `board.workbench_file` to a JSON file. The server resolves
the file path relative to its configuration directory. Standalone Board accepts
the same `workbench_file` or an inline `workbench` object, but not both. The file
is read at startup, is limited to 16 KiB, and has this shape:

```json
{
  "catalog": {
    "seed_file": "/private/board-data.seed",
    "connection": {
      "scope": { "realm": 42, "resource": 3, "catalog": "1" },
      "branch": "1",
      "audience": 5,
      "principal": 101,
      "role": null
    }
  },
  "sql": {
    "version": 1,
    "endpoint": "https://sql.internal:7443",
    "account": "board_reader",
    "database": "transit",
    "source": null,
    "authentication": "scram",
    "ca_file": "/private/sql-ca.pem",
    "password_file": "/private/board-sql.password",
    "request_timeout_ms": 2000
  }
}
```

Substitute provisioned identities and endpoints. Catalog reads use Board's
configured native upstream and require the corresponding current catalog/domain
grants. The catalog principal must differ from the inspection principal and use
the same realm. SQL uses the [public SQL client configuration](../../../packages/zig/transit-sql-client/README.md);
its service account owns authentication and source authorization. Absolute secret
paths avoid dependence on the service working directory. Either connection may be
omitted. An unavailable connection is visible in its workspace; Operations remains
available. Discovery does not provision schemas, Tables, grants or SQL accounts.

## Catalog and dataset exploration

Catalog reads eight authorized namespaces or Tables per page. Filtering applies
only to the current page. Continuations bind their selection and observed directory
position; changes require a fresh read. Definitions have stable scope, branch,
object, revision and digest identities. Dataset links retain that identity; a
changed definition cannot silently resolve to a replacement.

Dataset views expose declared logical types, codecs and collations, independently
observed row counts, metadata positions and registered relationship pages.
They do not infer relationships or a common snapshot. KV/Document projections
remain in Resources through their existing supported callers.

Preview is explicit. The catalog caller supplies quoted SQL and an exact expected
definition. The shared SQL client compares that definition with the executed
result's interpretation before disclosing rows. This is not an execution-time
definition pin. A mismatch refuses the preview; refresh the catalog selection.
The SQL connection must resolve the selected Table in its configured namespace.
A different namespace or source cannot substitute a same-named Table: the exact
definition comparison refuses that result.

## Workbook and results

A workbook is temporary in-memory presentation: up to four narrative/SQL cells,
explicit Run or Ctrl/Command+Enter, and one attached result per cell. Leaving the
route discards the workbook and closes results. There is no browser persistence,
sharing or durable workbook identity. Editing never executes a statement; an
earlier result stays visibly attached to its submitted SQL until the next Run.

The read adapter prepares through the SQL service, checks typed non-mutating,
row-returning semantics, and executes that same prepared handle. SELECT, SHOW,
DESCRIBE and EXPLAIN use the shared result lifecycle. Commands, writes, unbound
parameters and captured execution are refused. Existing application and finite
Live interfaces keep their separate authorities.

Four result readers are shared by the Board deployment. Each has a five-minute
absolute lifetime and a window of at most 100 rows with a 2 MiB value-allocation
budget. Metadata retains one bounded source chunk to recheck all held authority
subjects. Requests are limited to 64 KiB; result replies to 4 MiB. Byte-budget
exhaustion fails closed. A display limit is not query completion. Empty results,
verified result counts and incomplete prefixes are distinct.

Values preserve exact integers/decimals, logical types and all five cell states.
Column profiles count only the received window. Integer/decimal min/max,
distinct counts and distribution bins use exact arithmetic; unsupported ordering
or statistics are unavailable. Preview coverage is unknown and is never called a
random sample or whole-dataset profile.

Every result disclosure checks current source rights, including repeated and
terminal windows. Visible views revalidate every five seconds and clear on failed
observation or document hiding. Reopening visibility observes the original result;
it does not rerun SQL. Failed submissions/advances can check that original reader,
but cannot splice another snapshot. Closing stops local consumption and requests
cleanup; aborting an HTTP wait does not itself prove remote cancellation. Native
leases independently bound abandoned resources. Each result reports its own
canonical observation and verified completion; neither is a retention promise.
