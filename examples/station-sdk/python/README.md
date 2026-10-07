# Python Station SDK examples

The [Table workflow](../TABLES.md) records each mutation's global admission
position as its operation identity. Mailbox admitted/consumed counts are ordinals,
not those identities. Retained Table handles continue to read their original
schema and row cut after a later queued update completes.

`transit-sdk-examples` is an installable application package. It uses only the
public `transit_client` and `transit_station` APIs. [Shared codecs](../README.md)
define its counter, u64-state and query formats; malformed, unsupported and
out-of-range values are rejected at ingress and encoding.

From `nix develop`, run `just bindings::python-build`, then install
`transit-sdk-examples==0.2.0` from `.cache/bindings/wheels` using pip's
`--no-index --find-links` options into a consumer environment. The dependency
chain installs both public SDKs and their version-matched native artifacts.

`transit-python-counter service.json service --commits 1` runs the counter;
`transit-python-counter requester.json requester --commits 1` runs its requester.
Configuration is explicit JSON with `url`, `profile: "native_v1"`, `realm`,
`principal`, `pid`, `generation`, `seed_file` and `peer`. Provision each process,
its grant/ownership and a `data` resource association first. The example selects
`fence_on_restart`; obtain fresh ownership after a host exits. Use the configured
courier to deliver outputs. Admission, committed turns and replies are separate.

`Counter` handles typed `Add` casts and `Read` calls. `Requester` records its
correlation under `request` and later checks the native reply's peer/correlation
before committing `observed`; no Python future or object field needs to survive.
Use `encode_cast(Start(), requester_codec)` plus an independent raw client's
`prepare_send`/persist/`dispatch` flow to admit a start message.

`query.TableService` implements the [queued Table contract](../TABLES.md) with
four logical columns, typed scalar/nested defaults and an explicit requester
policy. Initialize, Insert, Update and Delete casts enter a durable FIFO.
Recorded self continuations advance one creation/mutation step at a time with
the original input identity. `table.done.<input-id>` records terminal outcomes;
accepted input or a committed intermediate step is not domain completion.
Rows calls receive NotReady while work remains, then start a native query once
the queue is ready and empty.

`QueryRequester` records its wait, validates NotReady replies and allows a later
explicit Start. Complete results are consumed through an application callback,
which receives original owned IPC one bounded segment at a time; the row count
is recorded in `observed`. Callback effects are not made transactional by handler
dispatch. The queue's source model is exercised by `tests/sdk_table_work.py`;
installed native execution is recorded separately in the proof ledger.

`just bindings::python-test` installs these wheels outside the checkout, runs both
counter CLI roles with requester restart, and drives both query handlers through
41 rows/six segments, retained reads, current access checks and owned Arrow data.
The fixture provisions a disposable disk-backed node; it requires no placeholder
endpoints or manually assembled library paths.
