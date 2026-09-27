# transit-tls

TLS 1.2/1.3 transport with bounded RFC 5280 certificate-path verification. The
client is the pinned Zig compiler's TLS implementation with the certificate-list
validation from zig-libs rebased onto it. Exact revisions and original SHA-256
values are recorded in [upstream.json](upstream.json); licensing is in [NOTICE](NOTICE).
The [compatibility snapshot](../../../third_party/zig-libs/README.md) owns the
certificate validator and its direct dependencies.

The unpatched compiler verifies signatures and hostnames but does not enforce
CA constraints on intermediate certificates. This adapter collects at most ten
bounded certificates, validates DER before parsing and checks the whole path,
including CA/key usage, path length, name constraints and server authentication
usage. Verification uses a fixed 16 KiB scratch buffer. It performs no DNS,
credential resolution, connection retry or Transit authorization.

Use explicit hostname verification and a current trust bundle. The low-level
client has the compiler's reader/writer ownership and options; connector adapters
must keep its buffers alive, enforce a deadline and exclude key logging. Rebase
this copy deliberately on compiler updates and rerun independent forged-chain
and valid-chain fixtures. Remove the workaround only after the compiler itself
passes those checks.

Run `nix develop --command bash -c 'cd packages/zig/transit-tls && zig build test'`.
Transport/deployment qualification belongs to its consumers; M15 owns the initial
HTTP integration and M16 will qualify its HTTP/2 use separately.
