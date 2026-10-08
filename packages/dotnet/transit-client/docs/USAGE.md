# .NET client usage

Build with `nix develop .#bindings -c just bindings::dotnet-build`. Add the local
`.cache/bindings/dotnet` folder as a NuGet source and reference `Transit.Client`
version `0.2.0`. Its exact native dependency is `Transit.Native.Client` 0.2.0;
there is no Station dependency. NuGet restores these packages into an ordinary
external project. The native assembly carries the matching Zig library, which
is extracted privately, version-checked and removed after owned work closes.
An explicit `ClientConfig.NativeDirectory` can select a compatible library.
Different clients own their library references independently. Artifacts require
the Nix runtime closure; NuGet.org publication and portable Linux packages are
not qualified.

```csharp
await using var client = await Client.OpenAsync(new ClientConfig(
    new Uri("http://127.0.0.1:8080"), Profile.NativeV1));
var credential = new Credential(72, 65536, "/private/client.seed");
using var pending = await client.PrepareSendAsync(
    new ProcessRef(72, 123), payload, credential, nextSequence);
PersistAndSync(pending.Export());
switch (await client.DispatchAsync(pending)) {
    case Admitted admitted: RecordAdmission(admitted.Receipt); break;
    case Rejected rejected: HandleRejection(rejected.Error); break;
    case Uncertain uncertain: RetainForExactRetry(uncertain.Recovery()); break;
}
```

The application supplies payloads, current principal sequence, credentials and
persistence. `CapabilitiesAsync` reads current authority capabilities. Select
`NativeV1` explicitly. Admission is distinct from committed processing and reply
completion. Protocol counters use `ulong` within the native 2^53−1 bound;
application u64/int64 values use `ulong`/`long`. Byte arrays are copied on entry
and export. Errors contain bounded kind/status/code/phase, never signed bytes or
credential paths. Signing seeds are read only from the explicit file, with bounded
temporary buffers cleared after use; the CLR cannot promise secure erasure of
all managed/runtime copies.

`PendingSend` and `PendingMutation` own exact signed retry bytes and typed native
metadata. `RecoverSendAsync` and `RecoverMutationAsync` validate their canonical
form through Zig without a signing seed. Dispatch never re-signs an uncertain
request. Persist retry material privately before dispatch if host-loss recovery
is required. Disposing a pending object releases its local bytes; it does not
revoke the signed request.

Each client owns a dedicated 8 MiB thread, one admitted job and a bounded queue.
Native construction, calls and destruction run on that worker. Overlap fails
with `Busy`; there is no implicit application backlog. Task continuations run
asynchronously. Operation cancellation tokens, or `task.WaitAsync(token)`, stop
only the caller's wait. The admitted operation stays owned and records any known
receipt. `CloseAsync` stops admission and waits for that work and native cleanup;
`DisposeAsync` supports `await using`. `CloseSnapshot`/`Dispose` also join the OS
thread synchronously. `RetainedEvidence` remains available after cleanup even
if the original operation wait was cancelled. Keep the acquisition task and
observe `OpenAsync` before disposing; startup has no cancellation parameter.
Garbage collection does not replace explicit disposal.

Transport failures or invalid post-dispatch receipts remain uncertain. Cleanup,
cancellation and exceptions do not acknowledge inputs or request durable
cancellation. Recover exact persisted bytes or establish fresh ownership before
recomputing. Native allocation-failure enumeration is shared evidence; fatal CLR
resource exhaustion is outside the managed recovery promise.

Generated schema validation resolves recursive local `$defs`/`$ref` names only
within their owning root. Missing/external references, unknown validation
keywords, non-consuming cycles and excessive data/reference depth reject.
Cancelling a caller's wait does not relax validation or release native ownership.
