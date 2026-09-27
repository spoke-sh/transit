# Certificate validation compatibility snapshot

Selected MIT-licensed modules from [zig-libs](https://github.com/zaxified/zig-libs)
at the exact revision and per-file SHA-256 values in [upstream.json](upstream.json).
This snapshot supplies RFC 5280 path validation for the TLS transport; it does
not provide Transit authority. Only its direct certificate-validation dependencies
are included. Upstream's package build targets Zig 0.16 and fails with the pinned
0.17 compiler, so this package supplies a bounded module graph and compatibility
changes while retaining upstream tests, notices and provenance.

[compatibility.patch](compatibility.patch) records every source change: removed
array repetition syntax becomes typed splats/literals, enum backing conversions
and reflection use current APIs, and RSA test signatures borrow fixed arrays.
The DER parser descent guard was reviewed against the exact pinned 0.17
`Certificate.parse`: TBS, validity, subject/RDN/attribute, SPKI algorithm,
signature algorithm and extension values are unchanged. Its version tripwire is
advanced to 0.17. Original and patched hashes are both retained in the manifest.

Run `nix develop --command bash -c 'cd third_party/zig-libs && zig build test'`.
Fixture material under `src/testdata` is public synthetic test data, not deployment
credentials. The dependency must not load ambient keys or invoke foreign peers
while executing connector work.
