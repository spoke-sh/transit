# Go Serving caller

`github.com/spoke-sh/transit/sdks/go/serving` adapts the shared Zig
[caller host](../../../apps/transit-serving-client/README.md). It contains no
signer, native wire codec, automatic retry or implicit journal. It is an additive
process-based port; the separate raw `client` C ABI is unchanged. Catalog/SQL and
browser session mutation are outside this package.

Select an absolute installed `Config.Executable` from
`nix build .#transit-serving-client` at the same source revision as this Go module.
This package needs no cgo. The host and its Nix closure must remain available at
runtime. No source checkout, compiler, shell or ambient program lookup is used
by an invocation. Public module/native releases remain separate qualification.

Open a `Client` with explicit origin, native identities, external seed/CA paths
and timeout. `Prepare` creates `Pending`; store `Pending.Export()` before sending.
After restart, use `Recover` to classify those exact bytes and verify the returned
sequence/application command against the journal. `Dispatch` attempts that same
work once. `Observe` exposes discovery/status/result/disposition and
`ReadApplication` signs an application-defined context. Responses preserve HTTP
status, including authoritative domain errors; applications must validate their
own success/absence schemas. A receipt means admission, not business completion.

Each call runs one native process, bounded by the native timeout plus five
seconds for process startup/output, and joins it on return. Context cancellation
kills and joins that invocation; cancellation cannot roll back an admitted
command. An uncertain dispatch returns `ErrUnknownOutcome`. Concurrent calls
return `ErrBusy`; `Close` waits for admitted work and refuses later calls. Saved
bytes are copied, and formatting a pending operation redacts its contents.
The owner supplies durable storage, exclusive sequencing and recovery after
process death. This port makes no throughput claim for per-call startup.

Run ordinary units with `go test ./serving`. The explicit installed transport
fixture requires:

```sh
TRANSIT_SERVING_CLIENT=/nix/store/…/bin/transit-serving-client \
  go test -tags serving_native ./serving
```

It exercises actual native preparation, exact recovery/replay, private CA trust,
scope refusal and joined cancellation against a TLS fixture. It does not replace
an independent real Serving authority/installed-provider qualification.
