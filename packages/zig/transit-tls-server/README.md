# transit-tls-server

TLS 1.2/1.3 server sessions over deadline-bound Zig socket I/O on Linux x86_64.
The library links OpenSSL 3.6.4 (Apache-2.0), pinned by the consuming Nix
environment and checked at context construction. It does not implement
cryptography or database authentication. Linux musl builds select the static
OpenSSL libraries from that target's package environment; other targets retain
dynamic linking. The static release bundle carries the pinned dependency notices.
The separate `transit-tls` package continues to own outbound TLS.

`Context.init` loads explicitly supplied PEM certificate-chain and private-key
paths and checks that they match and that the leaf certificate is currently valid. Contexts remain immutable while sessions use
them; certificate rotation creates a replacement context for new sessions.
Compression, renegotiation, session caching and tickets are disabled.
`Context.verifyLocalTrust` checks the supplied CA chain, server usage and both
loopback SAN identities before a local placement advertises that trust.

`LocalTrust.issue` creates a P-256 local CA and a server certificate for
`localhost` and `127.0.0.1` through the pinned provider. The CA is valid for ten
years and the server certificate for one year, with five minutes of clock skew
allowance. It returns four owned PEM buffers, each bounded to 8 KiB; the caller
persists them privately before exposing a listener. `deinit` erases and releases
those buffers. Issuance does not publish trust, renew a retained certificate, or
grant database access.

The caller negotiates the protocol's TLS upgrade before `Session.accept` and
owns the socket, context lifetime and absolute deadlines. OpenSSL uses memory
BIOs; network I/O passes through Zig's cancellation and timeout boundary.
Handshake input is bounded at 64 KiB plus one 18 KiB receive buffer; encrypted
output is drained after every TLS operation. Application writes use at most
16 KiB per TLS call. Slow partial messages do not reset the caller's deadline.
`finish` sends close-notify without waiting; `deinit` releases TLS memory and
does not close the caller's socket. Truncated TLS input is an error.

`Memory.create(allocator, capacity)` installs a fixed `transit-memory` slab as
OpenSSL's process-wide allocator before any OpenSSL initialization. All library
allocations, reallocations, headers, alignment and fragmentation consume that
reserve; exhaustion returns allocation failure without a heap fallback. Shrinks
retain charged capacity until release. Released payloads are erased before reuse.
The owner is shared by contexts and connections, including provider and
thread-local state; it is not an account quota or a bound on unrelated libc/I/O
allocations. Callers that do not install this owner use OpenSSL's allocator.

Installation must be serialized before other crypto users start. An existing
installation or earlier foreign OpenSSL initialization rejects. Destroy every
context/session and join every crypto-using worker before `Memory.destroy`;
it performs OpenSSL's permanent process cleanup before freeing the reserve.
OpenSSL cannot be used or reinitialized afterward. A process may instead retain
the owner until process termination. For detached workers, call `Memory.stopThread`
on each worker after its final crypto operation and before its completion signal;
the gateway uses `transit-io`'s worker cleanup barrier for this purpose. The TLS probe reserves 16 MiB and checks
100 fresh connections with alternating TLS 1.2/1.3, independently verified by
Python clients, while forbidding backing growth. This component check does not
qualify the gateway's other allocation owners.

Build and run the standalone checks in the repository's `sql-wire` Nix shell.
The `probe` build target supplies the independent database-upgrade TLS peer.
See the [toolchain guide](../../../nix/README.md) and
[proof ledger](../../../docs/history/qualification/README.md) for commands and executed evidence.
