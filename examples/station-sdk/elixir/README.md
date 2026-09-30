# Elixir public SDK examples

These native Elixir codecs and behaviours implement the shared
[counter/query formats](../README.md) using public SDK structs and tagged outcomes.
`Counter`, `Requester`, `TableService` and `QueryRequester` keep durable facts in
associated state. Calls return from their turn and resume through authenticated
replies or completed results. Query consumption streams owned IPC; its external
effects need application idempotency. Codecs preserve full-width integers and
reject unsupported versions, lengths, tags, roles and null markers.

Build with `nix develop .#bindings -c just bindings::beam-build`. Extract the
Elixir examples and their public client/Station and native OTP dependencies into
an ordinary library directory. Run the installed executable module:

```sh
ERL_LIBS=/tmp/transit-libs elixir -e 'Transit.SdkExamples.CounterMain.main()' -- config.json service --commits 1
ERL_LIBS=/tmp/transit-libs elixir -e 'Transit.SdkExamples.CounterMain.main()' -- config.json requester --commits 1
```

Each role has its own config with `url`, `profile: "native_v1"`, `realm`,
`principal`, `pid`, `generation`, `seed_file` and `peer`. Provision grants,
ownership and a `data` association first; delivery belongs to the deployment.
The CLI explicitly selects `:fresh_ownership`, stops on uncertainty and requires
fencing/reconciliation after host loss. Select persisted recovery for exact retry.
Both roles and the Table/query handlers pass M11's installed-artifact authority
schedule. See the [test guide](../../../tests/README.md).
