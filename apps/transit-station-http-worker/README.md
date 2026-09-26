# transit-station-http-worker

An initial finite M15 worker composing the public growing Station client,
[exchange capture](../../packages/zig/transit-exchange/README.md) and
[HTTP transport](../../packages/zig/transit-station-http/README.md). It is under
qualification; this executable does not complete M15's public caller, credential,
SDK or deployment scope.

`just test::http-worker` qualifies the real binary with disk-backed Ursula,
lost seal/dispatch/observation responses, node/store restart, current read
revocation and worker SIGKILL after remote application. Recovery closes unknown
without resending; sealed results replay through the public read adapter.
The TLS proof includes versioned credential/header scope, private secret
resolution, capture omission and replay after the credential file is removed.
Explicit idempotent retries, redirects, status queries and cancellation requests
use new linked effects under frozen endpoint policies.

`zig build transit-station-http-worker` installs the binary. Supply one JSON
configuration file containing authority URL, realm/principal/seed-file, PID and
fresh ownership generation, required `state` association, an activation marker
directory, exchange ID, endpoint revision and the transport's explicit endpoint
configuration. The principal needs current inspect/execute/publish/send/effect
rights scoped to the worker PID and read/write access to its associated resource.
The private control mailbox admits only this worker's ticks and authenticated
effect results. Provisioning and ownership remain separate administrative work.

In `prepare` mode, supply a typed `Request`, optional body file and finite
`reconcile_before_ms`. Preparation captures the metadata, rendered head and body,
then freezes exact coverage with one kernel effect. Request metadata is at most
8 KiB. A fresh activation can resume interrupted preparation with the same
metadata/body. Sealed segment commitments and partial chunks reject changed
bytes, and the original reconciliation deadline is retained. Repeating a ready
preparation does not create another effect. A controller may explicitly release
unfinished preparation that has not committed an intent; no remote cancellation
is implied. The body is at most
64 KiB. This initial executable owns a bounded 64 KiB
request buffer; responses are captured in 4 KiB segments. At most 16 configured
credential bindings identify a name, immutable version, allowed header and local
file. References require TLS and an exact binding/header match. Values are read
only by the authorized transport, bounded to 4 KiB each, never captured, and
zeroed on cleanup. The configured registry is trusted deployment policy; managed
secret-provider integrations and online registry mutation are not implemented.

In `execute` mode, the worker loads the committed request and checks the configured
endpoint revision/authority. Only a still-pending effect can receive a fresh
dispatch authorization. The timeout/byte bounds, header allowlist and explicit
CA bundle digest must also match the prepared policy. HTTPS requires `ca_file`,
bounded to 1 MiB and immutable during an activation. The network timeout is capped
by the remaining original reconciliation budget. Only that authorization permits
one network send. Already-authorized work from a lost
worker closes unknown without resending. A complete sealed capture can resume
its kernel observation after restart. Exact Transit retries reuse signed bytes;
they are separate from external execution. Each OS invocation requires a fresh
generation; the activation marker prevents reusing a previously entered generation.

An endpoint's trusted `retry_policy` names an immutable policy ID/revision and
one `key_header`. Set the root's finite `max_attempts` before preparation (default
one). An explicit new `prepare` with `followup: {parent, reason: "retry"}` and a fresh exchange ID can
retry an unknown parent only with identical canonical metadata and body, including
one nonempty literal idempotency key. The endpoint must implement that versioned
idempotency contract; the worker cannot infer it from an HTTP method. Followups
share the original deadline and total attempt budget. There is no automatic
retry, renewed budget, or reuse of an already-authorized kernel effect.

`redirect_policy` declares an ID/revision for explicit redirects. A `redirect`
followup requires an observed complete 301/302/303/307/308 response and one captured,
allowlisted Location. Only an exact origin-form target at the same authority is
accepted; credentials, method and body remain unchanged. POST and other methods
besides GET/HEAD require 307/308; the worker does not guess method rewrites.

`reconcile_policy` and `cancel_policy` each fix an ID/revision, method and literal
target before the root intent. Reconciliation permits GET/HEAD; cancellation
permits POST/DELETE, both with empty bodies and unchanged credential/header scope.
Their `followup.reason` values are `reconcile` and `cancel`. They require a closed
unknown parent and get independent captured outcomes. A cancellation request does
not undo prior remote work, and status evidence does not reopen or rewrite the
original kernel effect. Every followup consumes the original total budget/deadline.

The worker emits exchange identity, capture phase, kernel outcome and byte/segment
counts on stdout. `phase: "complete"` describes sealed capture; `outcome` separately
reports `pending`, `authorized`, `unknown`, `observed`, `cancelled`, `closed_unknown`
or `not_committed`. Capture completion alone is not kernel outcome acceptance.
It does not log bodies, request targets or credential material. HTTP status is
captured evidence, not a claim of business success. Resource retention remains
unlimited; group retirement and dependency-safe cleanup are explicit operations.
`release` mode is the trusted controller's explicit disposal of this private
worker's caller replay hold. It requires a recorded terminal kernel decision,
retires group availability, then performs at most `cleanup_steps` bounded steps
(default 64, maximum 128). Invoke again with fresh ownership to resume. It never
resolves an unsettled effect or releases other consumer dependencies. The disk
proof restarts after retirement and partial reclamation, rejects replay while
bytes remain, and finishes cleanup without another remote request.
TLS authenticates the virtual host while dialing a provisioned numeric address;
no proxy environment or implicit DNS selection changes that destination.
