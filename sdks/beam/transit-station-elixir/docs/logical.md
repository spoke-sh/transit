# Logical values

`Transit.Station.Sdk.Logical` exposes the shared
[logical descriptors and cells](../../transit-station-sdk/docs/logical.md)
through immutable Elixir tagged values. Fields, elements and conflict alternatives
use `Logical.Field`, `Logical.Element` and `Logical.Alternative` structs.

```elixir
alias Transit.Station.Sdk.Logical, as: L
alias Transit.Station.Sdk.Logical.{Field, Element, Alternative}

type = {:structure, [%Field{name: "amount", type: {:decimal, 38, 2}, nullable: true}]}
cell = {:value, {:structure, [{:value, {:atom, {:decimal, 123456789012345678901234567890}}}]}}
{:ok, wire} = L.encode(:cell, cell)
{:ok, ^cell} = L.decode(:cell, wire)
```

`encode(:type | :atom | :cell, value)` returns an owned neutral map or
`{:error, %Transit.Client.Error{}}`. `decode(kind, wire)` returns a native value,
including nested structs, or an incompatible-input error. Encoding validates
caller values; decoding validates fields and canonical representations. The
functions perform no I/O. The generated neutral maps use binary keys and remain
separate from public host types.

Use Elixir atoms for scalar type names and tuple tags; use binaries for names,
UTF-8 data, JSON text and arbitrary bytes. Integers retain exact 128-bit logical
ranges. Explicit `:float32`/`:float64` tags preserve width and signed-zero bits.
`%Field{}` defaults to nonnullable and nonoptional; `%Element{}` defaults to
nonnullable. `%Alternative{counter, replica, value}` requires an ordered positive
uint64 dot when encoded. Missing, null, source type error, present value and
conflict retain their separate meanings.

The shared codec enforces descriptor depth/node/name and cell depth/node/data
budgets. Host-struct conversion also has a finite 96-level, one-million-term
budget before codec validation. Values are immutable; codec outputs copy bounded
binary slices instead of retaining unrelated caller storage. External text never
becomes a BEAM atom. Type storage and query/operator support remain separate
capabilities; see the shared guide and [proof ledger](../../../../tests/README.md).
