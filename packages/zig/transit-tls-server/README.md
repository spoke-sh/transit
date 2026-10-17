# transit-tls-server

TLS 1.2/1.3 server sessions over deadline-bound Zig socket I/O on Linux x86_64.
The library links OpenSSL 3.6.4 (Apache-2.0), pinned by the consuming Nix
environment and checked at context construction. It does not implement
cryptography or database authentication. The separate `transit-tls` package
continues to own outbound TLS.

`Context.init` loads explicitly supplied PEM certificate-chain and private-key
paths and checks that they match and that the leaf certificate is currently valid. Contexts remain immutable while sessions use
them; certificate rotation creates a replacement context for new sessions.
Compression, renegotiation, session caching and tickets are disabled.

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

Build and run the standalone checks in the repository's `sql-wire` Nix shell.
The `probe` build target supplies the independent database-upgrade TLS peer.
See the [toolchain guide](../../../nix/README.md) and
[proof ledger](../../../tests/README.md) for commands and executed evidence.
