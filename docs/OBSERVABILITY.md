# Observability

Status: [M2 follow-up](roadmap/M2-OBSERVABILITY.md) in progress before Station.
Board request logs and the bounded [telemetry primitives](../packages/zig/telemetry/README.md)
are implemented across Board, Transit, storage, maintenance, runtime and callers.
Launcher/deployment qualification is in progress. This document owns cross-component rules.
Exact event schemas and configuration belong with the implementation as it lands.

## Purpose and authority

Operators need to see what each service is doing, why progress has stopped, and
which dependency or protocol boundary explains it. The first useful outcome is
visible Board HTTP requests in `just launchers::local::up`, followed by correlated
Transit diagnostics and instrumentation across the running system.

Operational telemetry is derived, bounded, and potentially incomplete. The
durable protocol history remains authoritative for accepted input, ownership,
committed progress, and effects. Logs are not an audit ledger or a second task
store; missing telemetry never proves an operation did not happen. Required
authorization and lifecycle evidence stays in the protocol under
[SECURITY.md](SECURITY.md) and [RETENTION.md](RETENTION.md).

Board's evidence-backed inspection API and service observability serve different
questions. A journey explains recorded work; a request log explains a service
interaction. Board must work without a telemetry backend, and Transit must be
observable without Board running. Telemetry failure must not grant authority,
change a transition, block control progress, or trigger effect redispatch.

## Ownership and package boundaries

| Owner | Observations it can explain |
| --- | --- |
| Board executable | HTTP handling, authentication/session outcomes, API projection failures, upstream call timing, startup and shutdown |
| Transit node | Signed ingress, scoped read/command outcomes, validation and fencing failures, durable acceptance or receipt recovery, authority recovery |
| Transit client | Each transport attempt, deadline/disconnection, received response or rejection, correlation with its caller; no invented server outcome |
| Node maintenance | Work performed, clock/storage failures, retirement, reconciliation closure, checkpoint and reclamation outcomes |
| Transit backend | Storage operations, conditional conflicts, latency, recovery/checkpoint/trim progress, capacity failures |
| Runtime controller and adapter | Reconciliation progress, recorded binding revisions, provider operation attempts/results, uncertain provider outcomes |
| Application callers and CLI | Activation, handler execution, proposal submission, retries, blocked work and uncertain results; application meaning stays here |
| Launchers and external infrastructure | Service exits, probe failures and restart lifecycle; Ursula, Substrate and Kubernetes retain their own instrumentation |

Each owner emits observations where it knows their meaning. Board owns its HTTP
instrumentation even though it also calls Transit. Reserve
`packages/zig/transit-observability` / `transit_observability` for the shared
**Transit-specific** event vocabulary and instrumentation interfaces used by
Transit services, adapters, and clients. It is implemented as a separate library;
it does not name all telemetry in Rey. Board's generic HTTP events do not belong in it.

Formatting, severity, resource identity, bounded sinks, metric instruments and
trace context are common plumbing with no Board or Transit domain dependency.
The `telemetry` package implements this interface, established against Board and
Transit HTTP call sites. It owns no application or protocol event vocabulary.
`transit-observability` may depend on the public protocol and that neutral
interface; it must not depend on Board, core, providers, or an exporter SDK.
Executable composition supplies sinks, clocks, configuration and shutdown policy.
Libraries expose optional, bounded instrumentation hooks; importing a library
never starts threads, opens a sink, or acquires credentials.

Keep `transit-core`'s dependency on the public protocol and its deterministic
transition boundary. Observe committed results in the host/adapter; if a missing
distinction requires a core result change, return a deterministic fact rather
than reading a clock or writing logs inside the transition. Instrumentation must
not import application handlers or alter signed command bytes.

## Signals and their meaning

| Signal | First instrumentation scope | Interpretation |
| --- | --- | --- |
| Logs | Request completion, lifecycle changes, failures, bounded progress summaries | Individual observations with stable event names and structured fields |
| Metrics | Request/operation counts and duration histograms, in-flight work, errors, telemetry drops; supported progress gauges | Bounded service-local measurements with units, reset behavior and freshness |
| Traces | Short server/client and dependency spans with explicit context | Timing and causal hints for observed execution, separate from durable journeys |
| Health | Existing probes plus documented liveness, readiness and progress meanings | Evidence about a specific service boundary, never execution ownership |

Count durable admission, turn commit, output delivery, dispatch authorization and
effect settlement separately. An HTTP success can contain a previous receipt;
a timeout can follow a successful commit. Neither proves a fresh transition.
Record whether a result is newly committed, deduplicated, recovered, rejected,
or uncertain only where the implementation can establish that distinction.
Otherwise emit the narrower known result. Replay/recovery must not increment a
counter named as fresh application completion or emit fictitious new dispatches.

HTTP observations distinguish intended response status, completed local response
write, deadline, cancellation and peer disconnection. A local write does not
prove the peer received it. Emit one terminal observation per handled request,
including failure paths, after its handler has completed or cancellation has
joined. Define timing boundaries and measure elapsed time with a monotonic clock;
wall timestamps aid navigation, not cross-machine ordering or expiry authority.
Keep transport outcome and protocol outcome as separate fields.

Metrics count observations by a named service instance, not exact system-wide
durable totals. Retries can add transport attempts without adding committed work;
multiple observers can see the same commit. Restarts reset local counters and
must be identifiable. Independent metric accumulation must not depend on whether
a log or span was sampled or dropped. Missing/stale measurements are not zeros.

Derive backlog from an authorized, identified state cut. The current M1 live
mailbox count uses admitted minus consumed minus cancelled inputs. Journal
position differences are not message counts or elapsed time. Do not publish
oldest-message age, exact global totals, or another gauge without supporting
evidence and freshness semantics. Per-process inspection stays in Board's
bounded read surfaces rather than an unbounded metric series per PID.

Liveness means the service can make its required local progress; readiness means
it can currently serve its declared role; workload progress means accepted work
is advancing. An idle caller can be healthy, and a responding server can be
blocked on storage. Document existing `/health` behavior before changing probes.
A telemetry sink outage alone must not fail readiness or cause restart loops.

## Correlation across requests and durable work

A browser request handled by Board, Board's outbound Transit call, and the node's
inbound request are distinct operations. Give them separate span/operation
identities with propagated context. Connect their diagnostic records without
merging their durations, permissions, or outcomes.

Use W3C trace context at HTTP boundaries and OpenTelemetry-compatible resource,
log and span fields. Trace/span identifiers allow related logs to be connected;
they are not authentication. See [W3C Trace Context](https://www.w3.org/TR/trace-context/)
and [OpenTelemetry context propagation](https://opentelemetry.io/docs/concepts/context-propagation/).
The implementation gate selects a supported context profile and tests malformed,
oversized, duplicate and spoofed headers. Public ingress starts a local context
by default; any acceptance of a remote parent needs an explicit trust policy.
Remote sampling flags cannot compel unlimited collection. Do not propagate
arbitrary baggage, headers, credentials, or tenant assertions.

Use existing authenticated realm, Transit PID, activation/generation, operation
identity and recorded position to relate durable work where available. Identify
the service instance and OS process separately from a Transit process or runtime
binding. Record claimed identifiers as unverified, if needed at all, until the
appropriate authentication/authorization boundary has established them.

Retries get distinct transport attempts while preserving the protocol's stable
retry identity. Suspended processes and delayed effects do not hold spans open
for their entire lifetime. Later execution starts bounded spans linked through
known protocol identities or explicit span links. Recovered work may have no
original trace context; the durable evidence still suffices. Persisting new
trace metadata would require an explicit versioned contract change; this pass
does not add it to signed commands or mailbox records.

## Output, privacy and resource limits

Local development defaults to readable service-prefixed records. Deployments can
select structured JSON using the same event fields and meanings. Emit diagnostics
to stderr and preserve machine-readable stdout used by CLI receipts, caller
bootstrap and controller one-shot output. Configure verbosity/format per service;
launchers pass configuration and display output without interpreting authority.
Exact configuration names/defaults will be documented with each executable.

At normal verbosity, show Board/API request completions, meaningful lifecycle and
progress changes, and actionable failures. Successful health probes and repetitive
idle/poll diagnostics belong at debug or in bounded aggregates. Failed probes
and unexpected exits remain visible. Repeated errors can be coalesced with a
count and time range. Debug mode never enables secret or payload dumping.

Allowlist structured fields and escape untrusted text. Exclude authorization
headers, session/access keys, cookies, request/response bodies, opaque application
state, raw query strings and full URLs/configuration dumps. Use route templates
and finite error classes, including an unmatched-route category. Default to
omitting peer addresses and user-supplied names. Authorized protocol identifiers
can support protected logs/traces; they are not public diagnostics or metric
labels. Apply [security boundaries](SECURITY.md#credentials-secrets-and-observations)
to log files and future export/scrape endpoints too.

Bound record size, attribute count/length, concurrent spans, histogram buckets,
metric series, queue bytes and shutdown flush time. Metric labels use finite
operation/route/method/status/error categories; unknown input maps to a bounded
category. No PID, request/trace ID, credential, arbitrary path or error string
labels. Use seconds for HTTP duration histograms and low-cardinality routes,
following the [OpenTelemetry HTTP metric conventions](https://opentelemetry.io/docs/specs/semconv/http/http-metrics/).

Emission on service paths must have bounded work and must not wait for disk,
network or a slow stderr consumer. Use bounded buffering with an explicit drop
policy, coalescing and capacity for important diagnostics; no finite buffer can
guarantee delivery to a permanently stalled sink. Expose dropped/suppressed
counts when reporting becomes possible, without recursive logging. Qualify the
pinned Zig concurrency behavior on one CPU so a blocked writer cannot prevent
deadlines, cancellation or control work. Bounded shutdown may lose queued data;
a crash can lose it too. No telemetry WAL is required.

Launcher log storage also needs a declared finite rotation/retention budget;
its current streaming and persistent files do not establish bounded disk use.
Operational log retention is independent of application-opted-in mailbox/history
retention and cannot authorize protocol cleanup. Later external telemetry
storage needs its own access, retention and capacity policy.

## OpenTelemetry path and later scope

Start with service instrumentation: tested local log sinks, bounded metric
snapshots and span/context hooks. Metrics and spans need a test consumer even
before remote export; merely adding IDs to text logs is not distributed tracing.
Pin the chosen semantic-convention/schema version when implementation begins.
Keep provider/export choices outside core and public command contracts.

A later change can connect those instruments to an OpenTelemetry SDK/exporter
and collector once compatibility with the pinned Zig toolchain, cancellation,
resource bounds and deployment trust has been proved. No SDK or collector is
selected here. The first pass adds no telemetry backend, public metrics endpoint,
Board telemetry-query API, dashboards, alerting system or browser analytics.
Protect any later diagnostic endpoint independently; Board inspection grants do
not automatically grant access to all service telemetry.

The [follow-up plan](roadmap/M2-OBSERVABILITY.md) owns sequencing, implementation
gates and acceptance evidence. Component READMEs will own exact event/metric
catalogs, configuration, operating examples and measured limits as code lands.
