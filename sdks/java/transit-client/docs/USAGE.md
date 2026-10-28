# Java client usage

Build with `nix develop .#bindings -c just bindings::java-build`. The output under
`.cache/bindings/java` contains independent `transit-client-0.0.1.jar` and
`transit-native-client-0.0.1.jar`, their POM dependency manifests, and the pinned
`gson-2.12.1.jar`. Copy these three JARs into your application's `lib/` directory;
compile with `javac --release 21 -cp 'lib/*'` and run with
`java -cp 'lib/*:classes' YourApplication`. The native JAR is discovered through
that ordinary classpath, without assembling a native library path. Missing or
incompatible native artifacts raise `INCOMPATIBLE_NATIVE`. `ClientConfig.nativeHost`
provides an explicit executable override. The build uses JDK tools and emits POMs;
Maven resolution/publication is not part of the local installation proof.

Native extraction, temporary configuration and process-start I/O failures raise
`LOCAL_IO`, with the original JVM exception available through `getCause()` and its
type in `code()`. They do not establish artifact incompatibility or an authority
rejection. The JVM's `java.io.tmpdir` selects temporary storage; configure it with
`-Djava.io.tmpdir=/your/writable/directory`. The directory needs capacity for each
concurrent extracted native executable. Cleanup failure cannot replace the
original startup failure; additional cleanup errors are suppressed exceptions.

```java
var config = new ClientConfig(URI.create("http://127.0.0.1:8080"),
    ClientConfig.Profile.NATIVE_V1);
var credential = new Credential(72, 65536, Path.of("/private/client.seed"));
try (var client = Client.open(config)) {
    var pending = client.prepareSend(new ProcessRef(72, 123), payload,
        credential, nextSequence).join();
    persistAndSync(pending.export());
    switch (client.dispatch(pending).join()) {
        case Outcomes.Admitted admitted -> recordAdmission(admitted.receipt());
        case Outcomes.Rejected rejected -> handleRejection(rejected.error());
        case Outcomes.Uncertain uncertain -> retainForExactRetry(uncertain.recovery());
    }
}
```

The application supplies its payload, current principal sequence, explicit seed
file and persistence policy. Admission does not prove processing or a reply.
`capabilities` reads current authority capabilities. Select `NATIVE_V1` explicitly;
there is no fallback to the legacy bounded profile. Protocol counters use positive
`long` values at most 2^53−1 (principal zero is supported); application u64 values
in Station use `BigInteger`. Owned byte arrays are copied on entry and exit.

`PendingSend` and `PendingMutation` expose typed native metadata and opaque
`export()` bytes. `recoverSend`/`recoverMutation` validate those exact bytes through
Zig, without a signing seed. Retrying dispatch cannot invent a new identity.
Persist signed material privately; diagnostics and `toString()` exclude it.
Closing a pending object releases its local copy and does not revoke the request.

Each client owns a pipe worker, a completion publisher and a deadline timer. The
native child owns its 8 MiB Zig stack and I/O. There is one admitted job, one
completion slot and a reserved cleanup command, with no application work queue.
Overlap is rejected with `BUSY`. Startup `open` and `close` are blocking; operations
and `closeAsync` return `CompletableFuture`. Native lines are bounded by the
generated contract and a 65-second exchange deadline. Use `thenCompose`, or an
application executor for blocking continuations; a synchronous continuation must
not wait for another completion on the same publisher. A blocked application
callback can delay publication/cleanup. Callbacks must cooperate with shutdown.

Cancelling a returned future or interrupting a controller does not interrupt its
admitted native job. `closeAsync` stops admission and joins owned work before
disposing the port. Cancelling its returned view does not cancel cleanup.
`closeSnapshot`/`retainedEvidence` retain the last known admission/mutation even
when the original future was cancelled. Cleanup failure is distinct and retained
evidence remains accessible. Synchronous `close` joins both worker threads and
preserves the caller's interrupt flag. The port is never killed just because a
local future was cancelled. A transport deadline or process loss during dispatch
produces `Uncertain`; explicit shutdown never implies a durable cancellation.

`TransitException.kind/status/code/phase` preserves access denial, stale ownership,
permanent retirement, unavailable history and native transport distinctions.
Preflight failures complete the operation future exceptionally; dispatch returns
typed `Rejected` or `Uncertain` outcomes. Malformed post-dispatch receipts remain
uncertain. JVM fatal resource exhaustion is not a recoverable scheduling promise.
Keep persisted bytes for recovery after abrupt JVM/host loss.

The M9 `io.transit.station.NativeHost` remains the explicit low-level conformance
adapter. Its JSON pump is not this API, and its cancellation policy is different.

Generated request/response validation resolves only local `$defs`/`$ref` names
within the selected schema root. Recursive child values are bounded; foreign or
missing references, unsupported keywords and non-consuming cycles reject before
results are exposed. A schema accepted for one operation does not define types
for another operation.
