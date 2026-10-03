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

`required_alpn` optionally offers one 1–255-byte application protocol and refuses
the handshake unless the peer selects it. TLS 1.2 selection is in ServerHello;
TLS 1.3 selection is in authenticated EncryptedExtensions. Duplicate, unsolicited,
wrong and malformed selections reject. The adapter writes no application bytes
before successful negotiation. `just test::tls-alpn` qualifies `h2`, missing
selection and incompatible offers against independent TLS 1.2/1.3 peers; this
does not itself qualify HTTP/2 or gRPC framing.

Run `nix develop --command bash -c 'cd packages/zig/transit-tls && zig build test'`.
Transport/deployment qualification belongs to its consumers; M15 owns the initial
HTTP integration and M16 will qualify its HTTP/2 use separately.

Certificate failures retain the validation check: an absent trust path, a
non-CA issuer, missing certificate-signing usage, excessive path length,
server-authentication usage mismatch or a name constraint. Malformed/empty/
truncated/oversized certificate data and exhausted validation scratch have
separate errors. These errors carry no certificate bytes, names or key material.
The pinned validator reports `NoTrustedPath` if every one of several candidate
paths fails; it does not select an invented single cause for that case.
Socket adapters can read the TLS reader's `read_err` and the socket reader/writer
cause slots when an I/O interface returns `ReadFailed` or `WriteFailed`.
