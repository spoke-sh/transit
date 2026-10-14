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

No database listener is supplied by these primitives. See the
[wire contract](../../../contracts/SQL_GATEWAY_V1.md) for limits and selected
protocol semantics. Build with `zig build test` or `zig build check` inside
`nix develop`.
