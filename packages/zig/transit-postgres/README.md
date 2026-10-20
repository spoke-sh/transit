# transit-postgres

PostgreSQL v3 frame decoding and deterministic extended-query admission, exported
as `transit_postgres` over the shared `transit-sql-gateway` library.

`Frame.startup` and `Frame.decode` borrow complete input frames and distinguish
incomplete prefixes from invalid lengths. They reject oversized lengths before
allocation and retain trailing bytes for a caller's next frame. Upgrade and
cancellation frames require their exact sizes. `Frame.read` owns one bounded
message from a transport supplying `readExact`; release it with `deinit`.

`Cycle` admits one execution per extended cycle. A write remains deferred until
Sync. A second execution, Flush or other message after the deferred write marks
the cycle failed without permitting dispatch. Failed cycles ignore messages
until Sync. Reads may resume the same suspended portal before Sync. The caller
validates payloads, owns portal/statement lifetimes and clears portals at Sync;
framing errors close the connection. Cycle decisions alone grant no authority.

`Frontend.decode` checks exact simple/extended bodies and borrows their bytes.
`Scalar` supplies OIDs and lossless text/binary codecs, including uint64 as
`numeric(20,0)`, nullable parameters and narrower driver integer OIDs. Text values
reject NUL. The caller retains statement/portal bytes, owns bytea hex decoding
allocations, validates statement counts and supplies bounded row framing.

`Startup` reads at most 8192 bytes and validates up to 16 name/value pairs,
mandatory account selection, duplicate keys and exact termination. It retains
the requested minor version so the session can explicitly negotiate protocol
3.0; it does not silently apply startup settings. Decoded fields borrow the
owned startup payload.

`Backend` builds bounded authentication, parameter, metadata, row, completion and
error frames. It preserves full uint64 counts, binary numeric metadata, NULL
length markers and negotiated field formats. Returned bytes borrow its reusable
buffer. Failed encodings expose no partial result; the caller supplies current
authorization and observed completion before writing any frame. Error messages
must already be classified and safe for disclosure.

`Session.Engine` owns named and unnamed prepared statements, copied bindings and
portals. The host supplies shared SQL execution, current authorization and safe
diagnostics. Writes dispatch only after a valid Sync; read suspension retains one
cut until completion, Close, error or Sync. Closing a statement closes dependent
portals. Failed extended cycles drain through a valid Sync; transport failures
close the connection without retrying a partial reply.

Read execution requests at most eight rows at a time. Each batch checks current
rights after materialization and before transmission. An Execute row limit also
bounds the batch request; suspension retains no already authorized output batch.
The next Execute checks rights again against the retained source cut.

The [gateway application](../../../apps/transit-sql-gateway/README.md) supplies
the listener and authenticated host. See the
[wire contract](../../../contracts/SQL_GATEWAY_V1.md) for limits and selected
protocol semantics. Build with `zig build test` or `zig build check` inside
`nix develop`.
