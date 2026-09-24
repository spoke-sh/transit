# telemetry

Domain-neutral Zig instrumentation, exported as `telemetry`, with no package
dependencies. Board owns its HTTP events; Transit-specific vocabulary belongs in
`transit-observability`. This package owns bounded emission, resource identity,
short spans, metric instruments and context. See the
[observability design](../../../docs/OBSERVABILITY.md).

## Composition and configuration

An executable owns a `Runtime`, initializes it with its service name, I/O and
`Config`, then calls `start()` after placing it at its final address. Stop all
instrumented operations before `stop()` and releasing the runtime. There are no
global collectors or import-time threads. Libraries borrow an optional runtime;
`begin(null, ...)` is a no-op span. A failed writer never fails service startup.

`Config.environment(init.environ_map)` reads only:

| Variable | Values | Default |
| --- | --- | --- |
| `LOG_LEVEL` | `debug`, `info`, `warn`, `error` (`err`), `off` | `info` |
| `LOG_FORMAT` | `text`, `json` | `text` |

Invalid values fail configuration without printing the supplied value. Executables
read these once at startup. Environment changes require restart. Logs go to
stderr; stdout remains owned by each application's machine interface. Text adds
a readable service/severity/event prefix to the same JSON record. Filtering and
log loss do not filter metric instruments. `off` starts no writer.

## Record schema v1 and spans

Structured records have `schema_version: 1`, `service_name`, a random per-start
32-hex `service_instance_id`, and wall `time_unix_ms`. Operation records also have
`scope`, monotonic `duration_ns`, `trace_id`, `span_id`, optional `parent_span_id`
and an `event` object. Absent optional fields are omitted. Fields are described
by [Event](src/root.zig); they include a stable name/operation, level/outcome,
route template/method/status, local response-write outcome, and optional verified
protocol identity/position. Only fixed vocabulary and compiler error names may
enter string fields; opaque data, keys, URLs and query strings never do.

`Runtime.begin(scope, parent)` creates a distinct operation; `Span.finish(event)`
records its completion once and owns a formatted copy of the event. Call finish
after the operation and any canceled child tasks have joined. A crash or external
signal can leave no terminal record. Trace context is optional diagnostic data;
it is never authorization or a durable journal field.

[Context](src/Context.zig) supports strict lowercase W3C `traceparent` v00 with
nonzero IDs. Duplicate, malformed, oversized or unsupported-version values have
no parent. Public ingress ignores remote parents; an explicitly trusted internal
boundary can accept them. Outbound headers use local flags `00`; no `tracestate`
or baggage is forwarded. Context exists only for the bounded operation: durable
work is linked with existing protocol identity, not a span held through suspension.
The local schema maps toward OpenTelemetry semantic conventions **1.44.0**;
it is not OTLP or an OpenTelemetry SDK/exporter.

## Measurements and bounds

Seven fixed scopes (`service`, `server`, `client`, `storage`, `maintenance`,
`runtime`, `application`) each have active operations, eight outcome counts
(`ok`, `rejected`, `conflict`, `failed`, `timeout`, `canceled`, `uncertain`, `idle`),
duration sum in seconds and nine noncumulative histogram buckets with inclusive
upper bounds 0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1, 5, infinity seconds. No request,
PID, trace, route or arbitrary string creates another metric series.

`snapshot(scope)` reads atomic local counters, which reset per service instance.
A concurrent snapshot can straddle an update; it is not an atomic cut of the
application or an exact durable total. The writer reports used scopes every
30 seconds as `telemetry.metrics` with `measurement.scope` and
`measurement.snapshot`. These bounded local reports are independent of event
level (except `off`); remote scraping/export is not implemented. Completion
metrics continue even when records are filtered, suppressed or dropped.

| Resource | Bound / policy |
| --- | --- |
| Record | 2 KiB including newline; oversized records drop |
| Queue | 128 records (256 KiB payload); normal records use at most 112 slots |
| Emission | Fixed formatting buffer, try-lock enqueue; never waits for sink I/O or a queue lock |
| Rate | Up to 200 ordinary and 20 warning/error records per monotonic second; excess counted as suppressed |
| Writer | One guaranteed-concurrent task; 10 ms idle polling; no network, WAL or file ownership |
| Shutdown | Up to 200 ms flush attempt, then cancel/join; requires cancelable sink I/O |

`telemetry.loss` reports cumulative dropped/suppressed counts when the writer can
make progress. A failed sink stops the writer and increments `sink_errors`,
available to the embedding caller; it cannot report its own permanent failure to
that same sink. Abrupt termination can lose queued records or a trailing record.
File/pipe retention is the launcher's/operator's responsibility. Diagnostic loss
does not authorize mailbox loss, retries, or different protocol decisions.

## Verification

`just test::telemetry` launches the real writer with drained, blocked and closed
stderr, including one-CPU affinity on Linux. It checks 10,000 operation completions,
independent metrics, loss and bounded exit while stdout stays parseable. Unit tests
cover reserved queue capacity, context validation/parentage and escaped JSON.
The current proof qualifies the pinned Linux I/O runtime and pipes; arbitrary
custom I/O implementations must supply cancelable writes before using this sink.
