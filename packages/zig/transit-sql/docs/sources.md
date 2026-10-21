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
`workspace` is the existing `Workspace.Config`: SQL name, typed source definition
and finite page/segment/result-byte budgets. The [Query reference](../../../../docs/reference/queries.md)
describes the source and requester owners. These owners and their policies must
already exist; loading a source declaration does not provision or grant them.

A source caller uses a dedicated native principal and sequence. It cannot share
any account worker, Table coordinator or other source's sequenced principal.
Its login role must equal the SQL account's login role; its selected role must
equal the database binding's role. Current credentials, database rights, source
policy, requester identity and source definition are checked separately.
Changing a source's connection, key, definition or budgets changes its binding
fingerprint and cannot reinterpret previously admitted work.

Interactive source queries acquire a fresh leased snapshot for each execution.
Prepared metadata does not hold a snapshot or permission. Results preserve
logical values and source basis, including missing/type-error/conflict states.
Session loss interrupts the result; it does not reopen a different snapshot.

Set `execution: captured` in the native connection file for durable source reads.
The service publishes the exact compiled bundle in the account ledger, then
drives the existing Query owner using published signed requests. A dedicated
recovery task continues accepted work after the console disconnects. Query
manifests and current authorization govern retained result reads.

`.status all` pages account operations. `.status token:<hex>` finds an original
admission; `.resume captured:<id>` advances its exact saved work and displays a
complete retained result when available. It never reopens parameter files or
recompiles SQL. A source definition changed since admission fails visibly.
Cancellation settles a published request before asking the Query owner to cancel.
An incomplete initial bundle can be cancelled without dispatching a query.

Each account admits at most its configured number of unsettled operations and
retained logical bytes. Captured queries reserve 1 MiB each. Publication and
result pages are bounded independently of retained history. A source lane blocks
new submissions while its preceding published request is unresolved; unrelated
sessions and source result reads retain their own transports.
