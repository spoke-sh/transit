# Erlang public SDK examples

These codecs and handlers implement the shared [counter/query formats](../README.md)
through public records and behaviours. `transit_example_counter` and
`transit_example_requester` persist totals, call correlations and observed replies
in associated state. `transit_example_table_service` and
`transit_example_query_requester` demonstrate nullable signed Tables and streaming
original IPC. Local handler context is temporary; consumption effects need
application idempotency. Codecs reject unknown versions, lengths, tags and roles.

Build with `nix develop .#bindings -c just bindings::beam-build`. Extract the
Erlang examples, public client/Station and native OTP applications into a library
directory, then run the installed example module through ordinary OTP resolution:

```sh
ERL_LIBS=/tmp/transit-libs erl -noshell -s transit_erlang_counter main -extra config.json service --commits 1
ERL_LIBS=/tmp/transit-libs erl -noshell -s transit_erlang_counter main -extra config.json requester --commits 1
```

Each role needs its own config containing `url`, `profile: "growing_v3"`, `realm`,
`principal`, `pid`, `generation`, `seed_file` and `peer`. Provision current grants,
ownership and the `data` association first; the deployment drives delivery.
The executable explicitly chooses `fresh_ownership` and stops on uncertainty.
Fence/reconcile after host loss; use `persist_before_dispatch` for exact saved
host-loss retry. Both roles and the Table/query handlers pass M11's installed-artifact
authority schedule. See the [test guide](../../../tests/README.md).
