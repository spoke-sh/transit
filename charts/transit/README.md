# Standalone Transit chart

This chart runs one `transit server` from the published `transit` image. The
server provisions and supervises its own installation. It needs no native root
key, grants, external Ursula, controller or initialization Job.

The Service exposes authenticated native SQL over TLS on port 19109. Board and
internal administration listeners are not exposed. A console uses its own SQL
account and CA configuration; see [remote SQL](../../apps/transit-cli/docs/sql.md#native-httptls-sessions).
The pod is a trusted single-user placement, not Substrate worker isolation or a
replicated database. This chart currently selects Linux amd64 nodes.

## Install

Use an explicit context and namespace. Create a Secret separately from Helm with
`tls.crt`, `tls.key` and `password`. The certificate must cover the hostname used
by clients; the password contains 1–128 printable ASCII bytes without a newline.
Helm values and release history contain only the Secret name.

```sh
kubectl --context "$TRANSIT_CONTEXT" -n "$TRANSIT_NAMESPACE" create secret generic transit-sql \
  --from-file=tls.crt=server.pem --from-file=tls.key=server.key --from-file=password=owner.password
helm install transit oci://ghcr.io/spoke-sh/transit/charts/transit \
  --kube-context "$TRANSIT_CONTEXT" -n "$TRANSIT_NAMESPACE" \
  --version "$TRANSIT_VERSION" \
  --set-string image="ghcr.io/spoke-sh/transit@sha256:$TRANSIT_IMAGE_DIGEST" \
  --set existingSecret=transit-sql --wait --timeout 5m
```

Select the chart and image from the same release. Image digests are required;
mutable tags reject. Source builds can install `charts/transit` directly.
The configured `account` defaults to `owner`. Its initial owner binding is
recorded once; restarting never restores revoked rights or resets a password.
Changing the Secret is not credential rotation; use the SQL account's documented
rotation workflow.

The startup and readiness probes execute a real local SQL metadata read. An
open TCP port alone cannot pass readiness. The server runs as PID 1, handles
termination and joins its children. There is no liveness probe that would reset
an installation during a temporary storage outage.

## Retain and recover

The PVC retains **all of `/data`**, including the private `.transit` installation,
credentials, journals, accepted-operation records, storage and publication
recovery files. Its mount root is separate from the initially absent installation
child. One replica with `Recreate` prevents overlapping rollout processes;
installation locks still reject concurrent ownership. Do not share the claim
between releases or scale the Deployment.

A new installation defaults to allowing creation. After it is ready, set
`requireExisting: true` in the retained values for all subsequent starts. Upgrades
and `persistence.existingClaim` default to this policy automatically when
`requireExisting` is null. This refuses a missing installation rather than
creating a new identity. A first-install pod restarted before this policy is set
still follows the server's create-if-missing policy. Existing incomplete,
corrupt or incompatible records never authorize a reset.

`running: false` stops the server and keeps the PVC. Helm uninstall also retains
the PVC. To reinstall against it, explicitly select `persistence.existingClaim`
and the **same image digest**. Retained executable fingerprints reject an
incompatible binary replacement. A new nightly image is not an in-place upgrade
or migration of accepted work. Keep the original release available for recovery.
Deleting the PVC is a separate destructive operator action. Restoring stale
backups into live service is outside this profile.

The storage class must support the server's locking, hard-link, atomic-replace
and sync requirements. Render tests and Kind lifecycle checks do not qualify
hosted storage; see [filesystem acceptance](../../tests/interfaces/installation/filesystems.md).

## Reference topology

The earlier component chart lives at
[`deploy/reference/chart`](../../deploy/reference/chart/README.md). It remains
source-only tooling for Kubernetes/Substrate isolation and recovery proofs.
Its `node`, `ursula`, `initialize`, controller and worker values are rejected by
this standalone chart. Preserve those releases and their claims; do not upgrade
them in place to this layout or point this server at a component data directory.
