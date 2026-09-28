# Arrow integration

The selected compiler is Zig `0.17.0-dev.2267+48abf1a34`. The package manifest
pins [rupurt/zarrow](https://github.com/rupurt/zarrow/tree/4276ac30d63d1af159490b7dc70e15d749b8d01b)
by Git revision and package hash. Its IPC writer uses its own pinned vendored
zstd/lz4 sources. Fuze's initial results are uncompressed.

[rupurt/zarrow-compute](https://github.com/rupurt/zarrow-compute/tree/def4d0654b4d6cdc2f4a7e6ad4a5930301f3391a)
is an ordinary Zig dependency pinned by immutable Git revision and package hash.
This is the Zig 0.17 migration proposed in
[upstream PR #3](https://github.com/tylitianrui/zarrow-compute/pull/3); it replaces
the earlier vendored compatibility snapshot. Its compiler and zarrow pins match
Fuze's. Fuze imports the exported `zarrow_compute` module and supplies the same
full Arrow module used by IPC, preserving one type universe and the writer fixes
below. The dependency's compute tests remain part of the package's `test` step.

`patches.zig` applies guarded patches to a generated copy of zarrow's source.
An IPC schema write that fails after transferring ownership to `MessageT`
previously freed the schema twice. The patch records ownership transfer before
writing, leaving early-construction cleanup intact. Its regression test fills a
one-byte output buffer using Zig's checking allocator. The fetched dependency
is never edited in place; changed patch anchors fail the build.
The FlatBuffer builder's unscoped byte/string debug logging is also disabled:
encoding must not disclose schemas or perform logging I/O. Caller-owned
instrumentation describes the query operation without payloads.

Use Git dependency fetching on this compiler. Mixing a prior `zig fetch` of the
GitHub tarball with the new build fetcher's global archive cache produced a hash
mismatch with an extra archive directory in the local proof. A fresh Git fetch
produces the manifest's package hash; package builds must also work cold.

## Capacity evidence

`just test::arrow` emits a complete two-column IPC stream (`id: int64`, nullable
`label: utf8`) and checks it with Nix-pinned PyArrow 23.0.0. The three-row fixture
includes a null, Unicode and integers above JavaScript's exact-number range.
It is 456 bytes; the empty result preserves its schema in 392 bytes.

Station's legacy qualified result profile reserves framing space: three **224-byte**
data keys and one manifest, at most **672 IPC bytes**. Its boundary proof sweeps
real variable-width results, captures the maximum, rejects larger results without
mutations, then completes the four-message reply across separate consumer turns.
The [Table guide](../../transit-station/docs/tables.md) owns framework/row/result
capacity and the real-service publication/recovery proof. Kernel IDs remain subject
to the protocol's advertised counter limit; Arrow integer values have their own
full signed 64-bit range.

The separate M10 [incremental engine](streaming.md) uses the same pinned libraries.
Its independent Arrow proof spans 70 rows and 16,008 text-result bytes in seven
segments. Whole-query limits and aggregate carry cross pages; allocation/output
capacity remains per-step. This removes the pure engine's whole-source ceiling,
but does not by itself qualify Station's larger durable result protocol.

M22 metadata/schema work exposed a valid zero-body IPC batch rejected by the
pinned reader. The guarded build-cache patch now supplies an owned empty body
for RecordBatch/DictionaryBatch messages while retaining normal array validation.
An empty primitive result, row-count mismatch and truncated stream are regression
tests; this changes neither the upstream pin nor the Arrow wire format.
