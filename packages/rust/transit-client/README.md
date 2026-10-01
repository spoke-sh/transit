# transit-client for Rust

Typed growing-profile sends, capability reads and exact mutation recovery over
the shared Zig client. This crate has no Station dependency. Protocol encoding,
signing, metadata classification and authority-response validation remain native.

The blocking controlling API owns one worker with the generated native stack
budget. It must run outside an async executor's event loop. Native libraries are
embedded by `transit-native-client`, then loaded from an owned temporary copy at
explicit open, with an optional native-directory override. Installed binaries
require neither a Cargo source-cache path nor manually assembled loader paths.
The clean-consumer proof removes extracted crates and build outputs before
running the executable against a real disk authority.

Loaded native code remains mapped until process exit. Repeated opens share the
same image; closing a client joins its owned work and releases handles and
buffers. This keeps code available while the native I/O runtime's detached
threads finish returning. Embedded files are removed immediately after loading.
The process admits at most sixteen distinct native images, including Station
and explicit overrides; further images return `IncompatibleNative` at
`native-library-capacity`. This does not limit the number of client handles.
Keep override files immutable for the life of the process. Missing files or a
changed file identity reject subsequent opens; they never select an embedded
fallback. Restart the process to select replacement native code.

The existing M9 `transit-station` crate remains unchanged while the separate
typed Station SDK is built. See the [Rust design](../../../docs/history/sdk/RUST.md).

Enter `nix develop .#bindings` and run `just bindings::rust-build` to create
`.cache/bindings/rust/transit-client-0.2.0.crate` and its matching
`transit-native-client` artifact. Extract both, add `transit-client = "=0.2.0"`
to the consumer, and use ordinary `[patch.crates-io]` path entries pointing at the
two extracted package directories until registry release is qualified. Build
with the supplied lockfile. No repository-relative source imports are required.
The native crate embeds the bundled library into the executable; a build-time
`TRANSIT_LIBRARY_DIR` override is available for source development only.

```rust,no_run
use transit_client::{Client, ClientConfig, Credential, ProcessRef, Sequence};
# fn main() -> Result<(), Box<dyn std::error::Error>> {
let mut client = Client::open(ClientConfig::growing("http://127.0.0.1:9010")?)?;
let credential = Credential::new(72, 65536, "/private/seed")?;
let pending = client.prepare_send(ProcessRef::new(72, 1)?, b"value", &credential, Sequence::new(1)?)?;
// Persist pending.export() before dispatch when exact recovery is required.
let receipt = client.dispatch(&pending)?;
assert_eq!(client.last_receipt(), Some(receipt));
let shutdown = client.close()?;
assert_eq!(shutdown.last_admission, Some(receipt));
# Ok(())
# }
```

The example assumes authorized, provisioned resources and an application-owned
sequence. It does not acquire rights or allocate a shared principal's sequence.
`PendingSend::export` returns copied opaque bytes. Fresh `recover_send` and
`recover_mutation` call the native classifier and need no signing seed; authority
access is still checked on dispatch. `AdmissionReceipt` and `MutationReceipt`
have different types. `DispatchError` separates preflight, rejection and unknown
outcome with exact retry material. Debug output excludes retry bytes and seed
paths. Dropping a pending value only releases local memory.

`Client` is `Send` and deliberately not `Sync`. Operations require `&mut self`,
and `close(self)` consumes the handle, joins work and returns retained receipts.
The initial API is blocking; there is no implied async cancellation or executor
adapter. Move it into an owned task outside an executor loop. Abandoning that
task's result cannot cancel accepted authority work; join its owner and recover
saved bytes if needed. Native creation, calls and destruction stay on the owned
8 MiB worker, including normal unwinding and cleanup.

`just bindings::rust-sdk-test` checks clean locked builds, moved/exclusive handle
ownership, safe bounds, copied bytes, lost receipts, exact seedless retry,
responsive controller join and revoked historical recovery. Qualification is
Linux x86_64, Rust 1.95 and Nix-linked native artifacts. Station handlers and
public language-pair qualification remain separate M11 work.
