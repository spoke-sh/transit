# Python Station SDK examples

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
Configuration is explicit JSON with `url`, `profile: "growing_v3"`, `realm`,
`principal`, `pid`, `generation`, `seed_file` and `peer`. Provision each process,
its grant/ownership and a `data` resource association first. The example selects
`fence_on_restart`; obtain fresh ownership after a host exits. Use the configured
courier to deliver outputs. Admission, committed turns and replies are separate.

`Counter` handles typed `Add` casts and `Read` calls. `Requester` records its
correlation under `request` and later checks the native reply's peer/correlation
before committing `observed`; no Python future or object field needs to survive.
Use `encode_cast(Start(), requester_codec)` plus an independent raw client's
`prepare_send`/persist/`dispatch` flow to admit a start message.

`query.TableService` creates an int64 Table and explicit requester policy, accepts
`Initialize` and `Insert` casts, then starts a native query for `Rows` calls.
`QueryRequester` records its wait and consumes complete result segments through
an application callback. It writes the row count to `observed`. The callback
receives owned IPC bytes, one bounded segment at a time. Arbitrary external
callback effects are not made transactional by handler dispatch.

`just bindings::python-test` installs these wheels outside the checkout, runs both
counter CLI roles with requester restart, and drives both query handlers through
41 rows/six segments, retained reads, current access checks and owned Arrow data.
The fixture provisions a disposable disk-backed node; it requires no placeholder
endpoints or manually assembled library paths.
