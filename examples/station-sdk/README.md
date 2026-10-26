# Public Station SDK examples

M11's public service/requester examples use the shared application formats below.
The format and [fixtures](../../tests/verification/sdk-codecs-v1.json) are defined
before language codecs. Implementations, installation commands and executable
qualification are added with each SDK; this contract alone is not a runnable
example or proof of support.

Executable installed examples are available in [Python](python/README.md),
[TypeScript](typescript/README.md), [Rust](rust/README.md), [Ruby](ruby/README.md),
[C](c/README.md), [C++](cpp/README.md), [Java](java/README.md) and
[.NET](dotnet/README.md), [Erlang](erlang/README.md) and [Elixir](elixir/README.md).
Their clean-consumer proofs run the same
counter, requester, retained Table and multi-segment query schedule. The
[public language ring](../../docs/history/qualification/verification.md#public-sdk-interoperability) also runs
every language in both roles against a different-language peer.

## Counter messages v1

Application type `transit.examples.counter`, version 1, uses four prefix bytes
`54 53 43 01` (ASCII `TSC` followed by version 1), then a one-byte tag. `Add` (1)
and `Total` (4) carry exactly eight following bytes, an unsigned little-endian
64-bit integer. `Read` (2) and `Start` (3) have no following bytes. Encoded size is
5 or 13 bytes. The service accepts `Add | Read`; the requester accepts
`Start | Total`. A role rejects other variants before invoking its handler.

This is an application payload inside the native Station envelope. A `Total`
variant is not an authenticated reply by itself. The requester verifies the
framework reply kind, recorded peer and saved correlation. `Start` records its
correlation in associated state with the call; receiving `Total` is a later turn.
Worker fields and host tasks do not preserve the request across a restart.

State keys `total`, `request` and `observed` use application type
`transit.examples.u64`, version 1: prefix `54 53 55 01` (ASCII `TSU`, version 1)
and exactly eight unsigned little-endian bytes. Full-width values stay integers;
JSON fixture values use decimal strings to avoid JavaScript rounding. Overflow,
negative values and booleans masquerading as integers reject before encoding.

## Query messages v1

A separate Table/query example uses type `transit.examples.query`, version 1,
with prefix `54 53 51 01` (ASCII `TSQ`, version 1). Initialize (1), Rows (3), Start
(4), Advance (5) and NotReady (6) have no following bytes. Insert (2) and Update
(7) carry an eight-byte signed little-endian key, a one-byte nullable marker
(0 = null, 1 = present) and, when present, an eight-byte signed little-endian
value. Delete (8) carries only the signed key. Encoded sizes are 5, 13, 14 or 22
bytes. Service roles accept Initialize, Insert, Rows, Advance, Update and Delete;
the requester accepts Start and NotReady. Native verified result completion is
a separate event, never an application message.

The [queued Table contract](TABLES.md) defines durable operation identities,
continuations, the four-column schema, private-turn bounds and compact outcome
records. It identifies its implementation and fixtures separately from runtime
qualification.

All decoders require exact prefix/version, known tag, exact length and marker.
Reject truncated/trailing data and unsupported versions rather than guessing a
format. SDK failure policy determines whether malformed application input stays
pending or is explicitly blocked. The kernel treats application payloads as
opaque and does not validate these formats or the application's computation.
