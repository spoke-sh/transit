# Public Station SDK examples

M11's public service/requester examples use the shared application formats below.
The format and [fixtures](../../tests/verification/sdk-codecs-v1.json) are defined
before language codecs. Implementations, installation commands and executable
qualification are added with each SDK; this contract alone is not a runnable
example or proof of support.

Executable installed examples are available in [Python](python/README.md),
[TypeScript](typescript/README.md), [Rust](rust/README.md), [Ruby](ruby/README.md),
[C](c/README.md) and [C++](cpp/README.md). Their clean-consumer proofs run the same
counter, requester, retained Table and multi-segment query schedule. Other
languages and public mixed-language pairs remain M11 work.

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
with prefix `54 53 51 01` (ASCII `TSQ`, version 1). Tags `Initialize` (1), `Rows`
(3) and `Start` (4) have no following bytes. `Insert` (2) carries an eight-byte
signed little-endian key, a one-byte nullable marker (0 = null, 1 = present) and,
when present, an eight-byte signed little-endian value. Encoded size is 5, 14 or
22 bytes. `Initialize | Insert | Rows` belong to the service; `Start` belongs to
the requester. Native verified result completion is a separate handler event,
never decoded as one of these application messages.

All decoders require exact prefix/version, known tag, exact length and marker.
Reject truncated/trailing data and unsupported versions rather than guessing a
format. SDK failure policy determines whether malformed application input stays
pending or is explicitly blocked. The kernel treats application payloads as
opaque and does not validate these formats or the application's computation.
