# Source bindings and captured queries

The SQL service exposes configured source names within an authenticated account
and database. An ordinary catalog session does not require a source declaration.
Explicit bindings support KV decoders, Table definitions and Document projections
through the existing Query interfaces. Select a binding with `source` in the
native console connection file. `context` and `.sources` report authorized names.

In `transit.yaml`, `sql.accounts[].sources_file` selects the declaration file for
a network account. `sql.native.sources_file` selects it for the managed local peer
account. Paths resolve relative to `transit.yaml`; source key references resolve
relative to their declaration file. Source files use YAML or JSON and contain
`version: 1`, the exact required `definition`, and a `sources` sequence.

Each source has `name`, `database`, `key_file`, `connection` and `workspace`.
`connection` is the existing `UnifiedClient.Connection`: realm, caller principal,
source process/resource, requester process/resource and selected role.
`workspace` is the existing `Workspace.Config`: SQL name, typed source definition,
finite page/segment/result-byte budgets and, for Tables, the capture worker's
native principal in `executor`. The [Query reference](../../../../docs/handbook/reference/queries.md)
describes the source and requester owners. These owners and their policies must
already exist; loading a source declaration does not provision or grant them.

A KV declaration has this shape (the numeric identities must be the observed
identities of your already-provisioned owners and login role):

```yaml
version: 1
definition: 491441b64b1f92bba9c351625cebf29dac5b3f41964c7a59bec791f5a32898c9
sources:
  - name: counters
    database: transit
    key_file: counters-caller.seed
    connection:
      realm: 46
      principal: 3002
      source: 81
      resource: 82
      requester: 79
      requests: 80
      role: null
    workspace:
      name: items
      source:
        version: 1
        resource: 82
        source:
          kv:
            prefix: ""
            key: {version: 1, type: utf8}
            value: {version: 1, type: int64}
      limits:
        pages: "1000"
        segments: "100"
        result_bytes: "1048576"
```

The exact definition is also published in the generated
[native contract schema](../../../../contracts/transit-v1.schema.json). A different
build's definition is rejected. Table declarations include their catalog scope,
branch, exact stored interpretation and full row type; Document declarations include an explicit
reference, optional expansion path and scalar projections. Those shapes follow
`Values.Source` in the [Query package](../../transit-query/README.md).

For a Table, `connection.resource` holds native query progress and
`workspace.source.resource` identifies the direct catalog's independent data
resource. The declaration supplies the Table audience and scope. Both public
services use the configured native endpoint, and the source caller's credential
and selected role authenticate direct reads. A source declaration neither creates
an actor-owned Table nor grants native raw-data access.

A source caller uses a dedicated native principal and sequence. It cannot share
an account database principal or another source's sequenced principal.
Its login role must equal the SQL account's login role; its selected role must
equal the database binding's role. Current credentials, database rights, source
policy, requester identity and source definition are checked separately.
Changing a source's connection, key, definition or budgets changes its binding
fingerprint and cannot reinterpret previously admitted work.

Interactive KV and Document source queries acquire a fresh leased snapshot for
each execution. Interactive Table sources acquire an explicit direct Table pin.
Catalog recovery slots retain its original request before acquisition and its closure
before release. Unchanged Table cuts can be reused through the bounded read cache. Recovery resolves the exact configured source connection and
current key; a removed connection or denied credential leaves cleanup pending.
Prepared metadata does not hold a snapshot or permission. Results preserve
logical values and source basis, including missing/type-error/conflict states.
Session loss interrupts the result; it does not reopen a different snapshot.

Native session callers request `execute.captured: true` for durable source reads.
The console uses interactive reads and has no captured execution setting.
For a Table, the service authorizes the exact current cut, executor and distinct
pin operation before publishing the bundle. The Query owner acquires and closes
that pin; recovery does not authorize another capture. The service publishes the
exact compiled bundle in the Catalog recovery index, then
drives the existing Query owner using published signed requests. A dedicated
recovery task continues accepted work after the caller disconnects. Query
manifests and current authorization govern retained result reads.

The native `operations` action pages account operations; `status` by token finds
an original admission. `resume` by captured-operation identity advances its exact
saved work and opens a retained result when available. These are native control
actions, not console commands. Resuming never reopens parameter files or
recompiles SQL. A source definition changed since admission fails visibly.
Cancellation settles a published request before asking the Query owner to cancel.
An incomplete initial bundle can be cancelled without dispatching a query.

Each account admits at most its configured number of unsettled operations and
retained logical bytes. Captured queries reserve 1 MiB each. Publication and
result pages are bounded independently of retained history. A source lane blocks
new submissions while its preceding published request is unresolved; unrelated
sessions and source result reads retain their own transports.
