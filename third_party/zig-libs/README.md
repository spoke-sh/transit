# Selected Zig transport compatibility snapshot

Selected MIT-licensed modules from [zig-libs](https://github.com/zaxified/zig-libs)
at the exact revision and per-file SHA-256 values in [upstream.json](upstream.json).
This snapshot supplies RFC 5280 path validation for the TLS transport; it does
not provide Transit authority. It also supplies selected HTTP/2, HPACK, protobuf
and gRPC client modules for [transit-grpc](../../packages/zig/transit-grpc/README.md).
Upstream's package build targets Zig 0.16 and fails with the pinned
0.17 compiler, so this package supplies a bounded module graph and compatibility
changes while retaining upstream tests, notices and provenance.

[compatibility.patch](compatibility.patch) records every source change: removed
array repetition syntax becomes typed splats/literals, enum backing conversions
and reflection use current APIs, and RSA test signatures borrow fixed arrays.
The DER parser descent guard was reviewed against the exact pinned 0.17
`Certificate.parse`: TBS, validity, subject/RDN/attribute, SPKI algorithm,
signature algorithm and extension values are unchanged. Its version tripwire is
advanced to 0.17. Original and patched hashes are both retained in the manifest.

M16 selects only the byte-transport HTTP/2 client engine and gRPC client. The
upstream HTTP root is narrowed to that module graph; its high-level client,
server, sockets, proxies and ambient TLS adapter are excluded. The server-only
round-trip and reverse-client tests are excluded with their implementations;
the HTTP/2 engine corpus, client negatives, protobuf vectors and captured grpcio
server responses remain executable. Upstream module READMEs describe the full
upstream library, not this selected surface.

RPC compatibility changes adapt field reflection, enum conversions, Linux wait
status and removed repetition syntax. Small additive polling methods reuse the
existing receive/credit/deframer engine so duplex writes cannot be blocked by
an incomplete incoming message. Terminal hardening preserves END_STREAM on the
exact header block, rejects malformed trailer ordering and duplicate reserved
fields, and latches malformed responses. The upstream test that accepted status before END_STREAM now requires
rejection; valid duplicate application metadata remains supported. These changes
and their regression fixtures are recorded in the patch and source hashes.

Run `nix develop --command bash -c 'cd third_party/zig-libs && zig build test'`.
`zig build test-rpc` selects the HTTP/2, protobuf and gRPC suites during RPC work.
Fixture material under `src/testdata` is public synthetic test data, not deployment
credentials. The dependency must not load ambient keys or invoke foreign peers
while executing connector work.
