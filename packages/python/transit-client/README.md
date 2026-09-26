# transit-client for Python

M11's typed raw client over the shared Zig implementation. It has no Station
import, dependency or native artifact. `transit-native-client` supplies the
version-matched library and standalone port; an explicit `native_directory`
override can replace installed library discovery. No credentials or connections
are discovered during import. Linux x86_64 / CPython 3.13 is the initial target.
Public Station runners are a separate package.

```python
from pathlib import Path
from transit_client import Client, ClientConfig, Credential, ProcessRef

config = ClientConfig(url="http://127.0.0.1:18101", profile="growing_v3")
credential = Credential(realm=72, principal=65536, seed_file=Path("/private/sender.key"))
with Client.open(config) as client:
    capabilities = client.capabilities(credential)  # Explicit authorized read.
    with client.prepare_send(ProcessRef(72, 1), b"message",
                             credential=credential, sequence=1) as pending:
        # Persist pending.identity and pending.export() in your durable outbox
        # before dispatch when restart recovery is required.
        admitted = client.dispatch(pending)
```

Provision the destination and grants independently. The application owns principal
sequencing and durable outbox storage. An admission receipt confirms mailbox
admission, not handler execution, a committed application turn or a remote reply.
To recover in another host, use `client.recover_send(saved_bytes)` and dispatch
that object; no credential is needed. Native metadata validates its canonical
kind/profile/command before the SDK exposes a pending send. Retry material stays
opaque and out of default representations. Closing a pending object releases its
local bytes; it does not revoke or cancel the signed request.
`capabilities(credential)` reports current authority budgets and the observed
principal sequence. It does not reserve a sequence or coordinate other handles;
local library compatibility alone cannot establish authority support.

`AsyncClient` has asynchronous preparation, recovery, dispatch and `aclose` methods.
Use `async with await AsyncClient.open(config) as client`. Each handle owns one
worker with at least an 8 MiB stack, one admitted operation and no unbounded
executor queue. Native handles retain their separately bounded two-worker I/O
pool. Overlap raises `Busy`. Close joins the in-flight operation before destruction;
async close keeps the loop responsive and joins even if its await is cancelled.
Native I/O has the configured deadline (1–60000 ms). Local await cancellation does
not establish a rejection or durable cancellation. Keep pending bytes and reconcile;
`last_receipt` exposes the last receipt observed even if its await was cancelled.
Use explicit contexts; garbage collection is not a shutdown protocol.

Named exceptions live in `transit_client.errors`. `UncertainOperation` owns exact
recovery material; rejections preserve native status, authority code and phase.
Denied access, stale ownership, retirement, history unavailability, read errors,
closed handles and incompatible artifacts remain distinguishable. A denied retry
does not resolve an earlier unknown result. Python seed copies cannot be guaranteed
erased; native temporary key buffers are erased. Keep key files and retry stores
private and exclude their contents from diagnostics.

Build artifacts with `just bindings::python-build`; run `just bindings::python-test`
for strict type checks and a clean consumer outside the checkout, including lost
receipts, fresh-host seedless recovery, revoked retry, host response allocation
failure, overlap and responsive async cancellation/disposal.
The public `prepare_send` API selects growing v3 explicitly; it does not silently
route legacy requests. M9 generic operations remain in the legacy raw binding.
Registry publication and other platforms are outside the current qualification.
