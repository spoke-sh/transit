# Document placement and recovery

From the pinned Nix environment, run `just examples::document-compose` or
`just examples::document-reference`. The reference task requires the owned
reference infrastructure and matching runtime image from the
[reference launcher guide](../../../launchers/README.md). Both tasks
create fresh, isolated installations and clean only their own resources. They
do not adopt an application's namespace, resources, credentials or history.

The physical runner uses the static image, operator and Substrate helpers first
qualified by the connector examples. Document binaries depend directly on Station;
they do not import Exchange, HTTP or gRPC semantics. No external effect peer is
deployed. The independent network probe is infrastructure tooling.

Compose runs two editor services and a writer on a client network. Only Transit
also joins the private MinIO storage network. Each editor mounts its own credential
and activation directory; it cannot read the operator or other editor's files.
The writer has a separate credential and no store access. Containers drop all
capabilities, use a read-only root and explicit process/memory/CPU limits.

Reference runs editors as separate Substrate/gVisor actor activations in an owned
atespace. Each activation creates an ephemeral key and emits only its public
registration. The operator checks actor/template/worker identity, grants that key
its scoped resource access, then records the exact expected next generation.
The caller never adopts a later owner. The trusted writer uses the fixed node
Service IP already permitted by its firewall; Substrate editors use the scoped
hostname required by their egress policy. The writer is a trusted, egress-confined
Kubernetes pod, not a Substrate actor or a new provider binding. Its network
permits Transit and DNS; probes reject MinIO, Kubernetes, Substrate API and
external TCP access. Only the server receives the provider credential file and
private CA bundle from its existing Secret. Namespace cleanup checks the recorded UID.

The finite schedule uses two distinct replica/PID identities. It repeats a sent
call under fresh ownership, interrupts an unpublished candidate with node/store
loss, then resumes the same durable writer. The reference proof additionally
kills the editor's physical worker before recovery. It checks reordered structured
and Unicode text edits, duplicate acceptance, explicit conflict resolution,
checkpoint-window resynchronization and permanent retirement. During native-owner recovery, the harness holds Deployment replicas at zero
until the previous process is joined, then starts the replacement with the same
retained authority. A bounded writer invocation reporting `progress` is not
accepted completion.

These placement proofs use native disk WAL, durable staging, a separate 32 MiB
verified disk cache, and pinned MinIO immutable storage on the selected private
bridge. MinIO uses TLS with a fixture-owned private CA. Only the server receives
provider credentials and can access that endpoint. Editors and the writer retain
their separate scoped Transit identities. The local proof additionally exercises
writer SIGKILL and exact signed acceptance retry. Neither proof substitutes for
the other. Historical M17 measurements used the earlier provider; see
[executed evidence](../../../docs/history/qualification/runtime.md#m17-qualification)
and the [native cutover record](../../../docs/history/qualification/native-storage-cutover.md)
for their distinct source/profile limits.

`example-station-document --bootstrap-json CONFIG` is intended for a trusted
operator. It forbids a seed file and requires an exact realm/PID/principal/
generation registration. `bootstrap_timeout_ms` bounds waiting (up to 300 seconds);
`park_after_result_ms` may keep a provider log readable for up to 300 seconds and
is permitted only in this bootstrap mode. The activation directory contains only
local reuse guards, never authoritative Document or call state.
