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
also joins the disk Ursula storage network. Each editor mounts its own credential
and activation directory; it cannot read the operator or other editor's files.
The writer has a separate credential and no store access. Containers drop all
capabilities, use a read-only root and explicit process/memory/CPU limits.

Reference runs editors as separate Substrate/gVisor actor activations in an owned
atespace. Each activation creates an ephemeral key and emits only its public
registration. The operator checks actor/template/worker identity, grants that key
its scoped resource access, then records the exact expected next generation.
The caller never adopts a later owner. The writer is a trusted, egress-confined
Kubernetes pod, not a Substrate actor or a new provider binding. Its network
permits Transit and DNS; probes reject Ursula, Kubernetes, Substrate API and
external TCP access. Ursula receives its bounded S3 configuration from a
separately created Secret, never from Helm values or a ConfigMap. Namespace cleanup checks the recorded UID.

The finite schedule uses two distinct replica/PID identities. It repeats a sent
call under fresh ownership, interrupts an unpublished candidate with node/store
loss, then resumes the same durable writer. The reference proof additionally
kills the editor's physical worker before recovery. It checks reordered structured
and Unicode text edits, duplicate acceptance, explicit conflict resolution,
checkpoint-window resynchronization and permanent retirement. A bounded writer
invocation reporting `progress` is not accepted completion.

These placement proofs use disk WAL and owned MinIO cold storage with an 8 MiB
hot-store limit and 8 MiB cache. MinIO runs as an isolated Docker fixture connected
only to the Compose storage or Kind provider network; its generated credentials
are mounted only in Ursula's private configuration. Editors and the writer cannot
connect to either storage service. The separate local proof additionally qualifies
writer SIGKILL and exact signed acceptance retry. Neither proof substitutes for
the other. The initial no-cold-tier Compose attempt exhausted its 512 MiB memory
limit; the bounded profile spills durable data instead of expiring history.
See [executed evidence](../../../tests/README.md#m17-work-in-progress) for current
results; a task's existence does not establish that its profile passed.

`example-station-document --bootstrap-json CONFIG` is intended for a trusted
operator. It forbids a seed file and requires an exact realm/PID/principal/
generation registration. `bootstrap_timeout_ms` bounds waiting (up to 300 seconds);
`park_after_result_ms` may keep a provider log readable for up to 300 seconds and
is permitted only in this bootstrap mode. The activation directory contains only
local reuse guards, never authoritative Document or call state.
