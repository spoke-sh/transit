# Signed Table mutation callers

`station_table_mutation_create/call/destroy` expose the shared Zig mutation
client through an explicit caller handle. The native port selects `mutation_client`
and accepts `table_mutation` actions. These profiles use
[neutral mutation values](../../../../contracts/TABLE_MUTATION_V1.md#neutral-caller-values)
and the same writer, policy, upload and result contracts as Zig callers.
The generated `TableMutationConfig`, `TableMutationAction` and
`TableMutationResult` schemas come from those public types.
[Typed SDK callers](../../../../docs/reference/sdks.md#table-mutation-callers)
use this boundary. The [mutation CLI](../../../../apps/transit-cli/docs/mutations.md)
uses the same shared Zig client with explicit saved-file recovery.

Creation takes the ABI version, explicit authority URL and seed, and a JSON
configuration containing `connection` (realm, principal, writer, resource, Table)
and `timeout_ms` (default 5000, range 1–60000). The URL is at most 2048 bytes and
the configuration at most 8192 bytes. All identities are required and validated.
No writer discovery, grant provisioning, PID ownership or activation is implicit.
The resource must have an explicitly enabled compatible mutation writer.

The native profile uses the [shared ABI ownership rules](bindings.md): one
operation at a time, `busy` on overlap, an 8 MiB calling-thread stack and joined
destruction. Each handle owns a bounded I/O pool and wipes its signing key on
destruction. Native output buffers remain owned independently of the handle and
must be released exactly once. Complete action JSON is at most 256 KiB; shared
owners impose the narrower request, part and saved-command bounds.

## Preparation and recovery

1. `describe` checks the current Table and mutation policy. `compile` additionally
   checks the requested operation and returns canonical request/reference hex.
   Persist both unchanged before staging. `capabilities` describes the local
   implementation and establishes neither authority support nor permission.
2. `next` validates the complete reference against the original request and
   prepares one command. Save the returned opaque `prepared` string before
   submission. Explicit `prepare` supplies begin/part/seal/apply/cancel controls.
3. `submit` dispatches that exact saved command once. The ABI validates its
   connection, definition, framing and signature before dispatch. Local malformed
   envelopes return `invalid_argument`; unconfirmed transport/result failures
   after dispatch return `uncertain`, including output-buffer allocation failure.
   Neither outcome triggers automatic retry or new signing.
4. Reconcile an uncertain submission by resubmitting the identical prepared
   string, including after handle/port replacement. Observe its original receipt
   position as processed, then read its separate input rejection before asking
   for another stage. A native receipt establishes admission only.
5. A null next command requires reading terminal status: applied, rejected and
   cancelled remain distinct. Current native read grants gate observations even
   after mutation-policy revocation. Cancelling applied work cannot undo rows.

Errors retain the native cause and authority code when available. Current native
or mutation-policy denial returns `denied`; busy staging returns `busy`; changed
identity, source or policy conflicts return `conflict`. Missing/failed writers
return `unavailable`. Retain the original request and signed command on errors;
an error code never authorizes reconstruction of accepted work.

Error buffers include an optional owned `diagnostic` envelope. Compiler failures
retain the original column, scalar/type context and SQL coordinates after the
current writer metadata checks. Other failures identify the attempted operation
and preserve local-before-dispatch, unknown-send and failed-inspection evidence.
An unknown send targets exact recovery at its original native sequence; a failed
read never fabricates a mutation outcome. The envelope is caller-facing data,
excluded from ordinary exception messages and telemetry. Losing optional detail
does not change the primary status or saved-command recovery obligation.

## Port profile

The configuration selects one of `mutation_client`, `query_client`, a server,
or local codecs. Conflicting profiles reject before admitting work. A read-query
profile returns `not_ready` for mutation actions. The profile requires an
explicit `url` and `seed_file`; importing an adapter creates no native handle.
Port `shutdown` joins and destroys its owners before acknowledging closure.
Host-task cancellation or lost shutdown acknowledgement does not cancel durable
work; keep prepared strings and known receipts outside the child process.

Repeated `observe` actions for the same pending input use the shared client's
bounded notification wait, at most 50 ms per native wait. Every response checks
current authority; a cached position supplies only a scheduling hint. Wait-slot
exhaustion uses bounded backoff and an ordinary read. The action never retries a
mutation or turns a timeout into a terminal result. Joined cancellation and the
configured transport deadline still apply.
