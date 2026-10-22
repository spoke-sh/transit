# @transit/client

Typed raw Transit over the standalone native client port. It has no Station
module, package or executable dependency. The explicit `native_v1` profile
supports typed send preparation, authorized capability reads, native-classified
opaque recovery and distinct admission/mutation receipts. Public Station support
is in the separate `@transit/station` package.

Build with `just bindings::node-build`; run `just bindings::node-sdk-test` for
strict checks and a real installed consumer. Tarballs go to `.cache/bindings/node`.
For local unpublished artifacts, set both dependencies and `pnpm.overrides` to
those tarball paths in the consumer's package manifest, then run `vp install`.
The proof installs offline with lifecycle scripts disabled. These are package
resolution settings; callers never assemble executable/library loader paths. The installed
`@transit/native-client` resolves its executable; `nativeHost` is an explicit
path override. Import starts no credential discovery, process or network work.
Missing artifacts and incompatible handshakes fail at `Client.open`.

```typescript
import { Client, Credential, ProcessRef } from "@transit/client";

const client = await Client.open({ url: endpoint, profile: "native_v1" });
try {
  const pending = await client.prepareSend(new ProcessRef(72, destination), bytes, {
    credential: new Credential(72, principal, keyFile),
    sequence,
  });
  try {
    await outbox.save(pending.identity, pending.export());
    const outcome = await client.dispatch(pending);
    if (outcome.kind === "admitted") await outbox.confirm(pending.identity, outcome.receipt);
    else reportAttempt(outcome); // Preserve saved bytes on uncertainty or rejection.
  } finally {
    pending.close();
  }
} finally {
  await client.close();
}
```

The application supplies principal sequencing and durable outbox storage. An
admission receipt confirms admission only. `recoverSend(bytes)` validates an
exact canonical growing send using native metadata; no signing seed is needed.
`recoverMutation`/`dispatchMutation` reconcile saved framework commands using
`MutationReceipt`, distinct from admission or reply completion. Retry bytes are
owned and copied on export, and stay out of default pending-object diagnostics.
References and metadata confer no access or ownership.

Each handle owns one port with one native request in flight and no unbounded
queue. Public operations hold admission across their preparation/metadata phases.
Overlap throws `Busy`. `close` joins active work before ending and reaping the
port. The native client owns its bounded I/O workers and generated stack budget.
Its deadlines are finite; the host request deadline is 65 seconds.

`dispatch(pending, {signal})` cancels only the caller's wait. Once the call is
owned, abort can report `uncertain` while native work continues; cleanup joins it.
A completed native receipt remains in `lastReceipt` or `lastMutationReceipt`.
Neither local cancellation nor port death promises rejection or durable peer
cancellation. Exact authority errors preserve status, code and phase. Native
stderr is drained without retaining bytes or backpressuring control on a caller's
output sink; machine responses carry structured errors.

Generated wire schemas are separate from public models. Runtime checks reject
unsafe protocol integers and malformed data even from untyped JavaScript.
`./internal` is a version-matched package interface used by Station, not a public
application API. M9's generic Station adapter remains under `@transit/station`.
The qualified packaging target is Linux x86_64 with the pinned Nix linkage;
registry publication and portable platform builds remain outside this slice.
