# Ownership, outcomes and recovery

Call `transit_sdk_growing_config(url)` and `transit_sdk_client_open`. This selects
native_v1 explicitly. Credentials
specify a realm, principal and seed file. The seed is read only for preparation,
bounded, and wiped after use. No credentials or request payloads enter diagnostics.
References and protocol counters are checked at every public boundary; protocol
counters stop at 2^53−1. Application bytes preserve all u64/i64 values.

The client owns one worker with an 8 MiB stack and one admitted call. The public
API blocks its calling thread. Concurrent work is rejected with BUSY; reentry
from its worker is rejected too. Use an application-owned task on async runtimes.
Abandoning that task's controlling wait does not cancel accepted work: join the
task and inspect its dispatch result or close evidence. Native work cannot run
on an undersized caller stack. Deferred POSIX cancellation is masked across SDK
calls; asynchronous thread cancellation and cancellation of destructors are not
supported. Prefer a separate local controller and cooperative shutdown.

C input pointers borrow until their synchronous call returns. Do not mutate or
free a handle or its arguments concurrently. `client_close` may run alongside an
admitted call: it rejects new work and joins before returning last known receipts.
It is idempotent and leaves the handle valid for repeated close observations.
`client_destroy` requires exclusive ownership, closes and releases the handle.
Use-after-destroy is a C memory error, not a recoverable SDK error.

Native code images remain mapped until process exit. The shared loader reuses
each canonical library path and admits at most sixteen distinct images,
including Station and incompatible overrides. Further images fail with
`TRANSIT_SDK_INCOMPATIBLE_NATIVE` at `native-library-capacity`; this does not
limit client handles. Changes to a loaded file's identity, size or timestamps
fail at `native-file-changed`. Native artifacts are immutable for a process;
replace the process to use replacement artifacts, and keep its SDK loaded for
that lifetime.

Close still drains owned I/O, stops the SDK worker and releases native handles
and buffers. Code retention covers the pinned Zig pool's detached-thread exit
instructions after it reports drained work; that report does not make unloading
its library safe. It grants no execution rights and retains no client credential.

Preparation copies payload bytes. A pending handle owns exact signed retry bytes
and native-validated metadata, independently of its client or credential file.
Export returns another owned copy; release it with `transit_sdk_buffer_release`.
Destroy pending sends/mutations with their corresponding destroy function.
Do not overwrite a nonempty output buffer/handle: release it before another call.

Persist exported bytes before dispatch when recovery must survive process loss.
ADMITTED is mailbox admission; CONFIRMED is a raw mutation receipt. Neither is
handler commitment or reply completion. UNCERTAIN preserves the original pending
handle for an exact retry. PREFLIGHT_FAILED means the SDK could not initiate the
requested dispatch; DISPATCH_REJECTED carries an authoritative rejection.
The error preserves native status, protocol code and distinctions for revoked
access, stale ownership, retirement and unavailable history. Retry still checks
current authorization. `recover_send` rejects non-send requests; `recover_mutation`
accepts opaque growing commands for runner recovery without constructing a new
request identity. No API logs or rewrites the frozen request.

Allocation failure while observing a mutation response is uncertain. The pending
handle remains owned by the caller. Destruction, close and exception unwinding
do not acknowledge inputs or cancel durable work. The generated raw ABI remains
available for advanced operations outside this deliberately small typed client.
