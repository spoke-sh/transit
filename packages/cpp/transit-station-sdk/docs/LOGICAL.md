# Logical values

`transit/logical.hpp` exposes `transit::sdk::logical::Type`, `Atom` and `Cell` over
the [C logical API](../../../c/transit-station/docs/LOGICAL.md). Copies share
immutable owned trees. Constructors copy caller input, and child accessors return
independent owners. `native()` exposes a const C view borrowed from the C++ owner;
it does not borrow a native client.

```cpp
using namespace transit::sdk::logical;
auto type = Type::structure({
    {"amount", Type::decimal(38, 2), true, false},
    {"label", Type::scalar(TRANSIT_LOGICAL_UTF8), true, false}
});
auto cell = Cell::structure({
    Cell::atom(Atom::decimal(12500000)),
    Cell::atom(Atom::utf8("Ada"))
});
auto owned = Cell::decode(cell.encode());
```

`Type` factories cover every logical family: `scalar`, `decimal`, `timestamp`,
`structure`, `tagged_union`, `list`, `array` and `map`. Fields carry name, type,
nullable and optional flags. `Atom` factories cover exact signed/unsigned numbers,
decimal coefficients, finite floats, booleans, text, bytes, temporal carriers,
intervals and UUIDs. `Int128` and `Uint128` expose exact low/high limbs; ordinary
64-bit numbers have overloads. Decimal coefficients are interpreted using their
descriptor's scale.

`Cell` factories preserve `missing`, `null`, `type_error`, `atom`, `structure`,
`list`, `array`, `map`, `tagged_union`, `json` and `conflict`. An `Alternative`
contains a positive counter/replica dot and a NULL, type-error or present cell.
Alternatives are strictly ordered; a conflict contains two to eight of them.
`fields()`, `children()`, `entries()` and `alternatives()` return owned values.
Accessing the wrong kind throws `transit::sdk::Error` with invalid-argument detail.

`encode()` and `decode()` operate on owned neutral JSON bytes. They retain exact
128-bit values, float widths and signed zero. Invalid data or exceeded bounds
throws `transit::sdk::Error`; C++ allocation failure can also throw `std::bad_alloc`.
The C API's logical depth, node, name/data and JSON budgets apply unchanged.
Moved-from handles reject access; callers must still synchronize lifetime and
concurrent assignments to their own C++ wrapper objects.

These local models do not authorize I/O or expand Table/operator support.
Shared Zig owns type/domain validation and execution. See the
[logical contract](../../../../contracts/FUZE_TYPES_V1.md) and
[executed proofs](../../../../tests/README.md).
