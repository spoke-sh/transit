# Finite Flight example

The [gateway](../../apps/transit-flight-gateway/README.md) reuses the actual
public Table query hosts and shared finite serving policy. Run
`nix develop --command just test::flight` for the owned native installation,
explicit TLS edge, PyArrow and pinned ADBC Python/C consumers. Its data contains
nullable full-width integers, with empty and aggregate SQL results.

[nginx.conf.in](nginx.conf.in) is the bounded HTTP/2 TLS edge used by that proof.
It disables upstream retries and access logs. Deployment CA and hostname checks
are mandatory; [configuration](../../apps/transit-flight-gateway/docs/configuration.md)
describes deadlines, credentials and memory budgets.

Compose/reference placement and adversarial lifecycle qualification are still
in progress. See the [proof ledger](../../tests/README.md#m22-qualification-in-progress).
