# Station v1 profile

Status: implemented experimental M9 profile: behaviors, calls, scoped framework
services, Tables and shared language exports. The
[framework design](../docs/internal/STATION.md) distinguishes this bounded implementation
from the broader direction; no stable public SDK release is implied.

## Messages and origins

A Station message is `STN1`, a one-byte kind, a little-endian unsigned 64-bit
correlation, and at most 243 payload bytes. Kind 1 is cast (correlation zero),
2 is call, 3 is reply, 4 is result fragment, 5 is result completion, 6 is result
acknowledgement, 7 is cancellation and 8 is timeout (nonzero correlation).
The [Table guide](../packages/zig/transit-station/docs/tables.md) records the
implemented result framing; the [services guide](../packages/zig/transit-station/docs/services.md)
records timeout, cancellation, registry and supervisor codecs. Unknown versions/kinds and
oversize frames are rejected. Correlation is opaque and preserves all 64 bits;
Transit identities still obey the public protocol's narrower admitted range.

A call uses its caller's consumed input position as correlation. One call per
input is supported. Reply destinations come from the input's authenticated
process origin, never an application-supplied sender field. External principals
can cast; a call expecting a process reply must originate from a process.

## Resource layout and capacity

The GenServer requires one writable associated resource. Application KV keys
cannot start with zero; framework records use that prefix. They have the same
authorization, retention and quotas as application data. This is a namespacing
rule, not a security boundary against arbitrary host code.

| Key | Value |
| --- | --- |
| `00` + `station` | UTF-8 `station.genserver.v1` |
| `00` + `w` + correlation:u64le | Durable wait record |
| `00` + `disposition` | Last closed-reply disposition `station.closed-reply.v1` |

A wait record is 27 bytes: version 1, phase byte, destination:u64le,
deadline-ms:u64le (zero means none), resolution-input:u64le and observer:u8
(255 means none). Phases are waiting=1, replied=2, timed-out=3, cancelled=4.
Timed calls require a configured observer; its authenticated firing observation
closes the wait in mailbox order. A proposed deadline is not a hard wall-clock
cutoff and cannot extend a process/resource lifetime.

There are 32 live keys per resource, values up to 256 bytes, four distinct-key
mutations and four outputs per turn. Framework state shares these limits. A
failed capacity check publishes nothing; it does not evict completed calls.
Initialization, waiting records and application writes must fit together.
The realm has four resources and four active views; wrappers do not multiply
those bounds. Each handler view expires within the authority's allowed window.

## Turn and recovery boundary

The loop resolves a required association, obtains an authority-validated view,
checks its PID/principal/generation/input/revision, and collects bounded entries.
Private writes are readable within the same handler. One state commit consumes
the input and publishes all accepted mutations, outputs and effect intent.
Failures publish only the kernel failure marker. No partial handler output is
observable. Required resource expiry retains its kernel lifecycle meaning.

Same-host retries preserve the exact signed proposal. A fresh host must first
obtain fresh ownership and read committed progress; it may then execute the
uncommitted input. Reply closure is in mailbox order. A duplicate reply cannot
reopen a completed wait or rerun its application callback. Signature grants,
resource permission and process ownership remain separate authority checks.
