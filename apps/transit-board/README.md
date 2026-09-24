# transit-board

Inspection-only Zig service containing the static [Board frontend](../transit-board-web/README.md)
and [OpenAPI v1](../../contracts/transit-board-v1.openapi.json). Its only application
libraries are `transit-client` and `transit-board-api`; it has no kernel, Ursula, provider,
or handler dependency. [Board's design](../../docs/BOARD.md) owns the architecture.

## Try it

```sh
nix develop
just transit-board::install
just transit-board::demo
```

The demo starts isolated disk-backed Ursula, Transit, and the real counter caller.
It prints a loopback URL. Open it directly; Board has no access keys, sign-in,
or browser sessions. Ctrl-C removes the disposable realm.

For a persistent development system with an actively polling caller, use
`just launchers::local::up` or `just launchers::compose::up` instead. Their
[guide](../../launchers/README.md) covers logs, inputs and restart without losing
the realm. To configure Board against another provisioned realm:

```sh
just transit-board::build
zig-out/bin/transit-board /absolute/path/board.json
```

`just build::debug` also installs Board; use another [build profile](../../tasks/README.md#build-profiles)
for optimized executables. Building requires the locked frontend dependencies;
running the resulting binary requires neither Node nor a checkout/assets directory.
The build embeds up to 128 files / 8 MiB, with no external fonts, CDNs, or runtime
downloads. Every reachable viewer can read this instance’s configured inspection scope.
The deployment boundary controls who can reach Board.

## Configuration and provisioning

```json
{
  "upstream": "http://127.0.0.1:8080",
  "realm": 71,
  "principal": 2,
  "seed_file": "/run/board/transit-seed",
  "public_origin": "http://127.0.0.1:8090",
  "listen": "127.0.0.1",
  "port": 8090,
  "request_timeout_ms": 1500,
  "upstream_timeout_ms": 800,
  "read_interval_ms": 100,
  "lenses": [{"pid": 1, "kind": "rey.example.counter", "version": 1}]
}
```

An administrator provisions the realm and records a grant for this principal
with **only `inspect` (16)**, optionally restricted to one PID. Board rejects
principal zero and refuses data from a grant with any additional permission.
`seed_file` is that principal's 32-byte Ed25519 seed as 64 hex characters.
Use restrictive file/Secret permissions. Signing credentials never belong in Git/config
maps, frontend assets, query strings, or application history.

Every reachable human or agent shares this instance's explicit Transit scope.
There is no per-user delegation. Configure separate instances/principals for
separate scopes. Upstream URLs, signing identity and lens mappings are trusted
operator configuration, never accepted from requests.

Browser and agent clients call `GET /api/v1/…` directly, without bearer tokens
or cookies. Every data read still uses Board's signing seed and rechecks its
current Transit permission. Revocation takes effect at that boundary; released
bytes cannot be recalled. Seed rotation takes effect on subsequent data calls;
coordinate it with the authority's grant update.

The OpenAPI lists the process, mailbox, outbox, effect, payload-metadata, history
and journey routes. See [inspection v1](../../contracts/INSPECTION_V1.md) for
cut/continuation semantics. Query errors are JSON, including unknown API routes;
they never fall through to HTML. POST requests cannot mutate Transit.

### Migrating the experimental Board v1 profile

This deliberately removes the original viewer-authentication contract. Session
creation/logout endpoints and the `Session` schema are removed, as are the
`session_seconds` capability and the TypeScript `login`/`logout` helpers. Rebuild
API and frontend together; external clients should regenerate from OpenAPI and
stop sending Board credentials. The inspection GET routes remain under `/api/v1/`.

Launcher `update board` regenerates configuration and deploys the new executable.
For standalone configurations, remove `credential_file` and `session_seconds`;
unknown fields fail configuration parsing. Keep `seed_file`: Transit still
requires it. Old ignored access-key files and old browser cookies are unused;
Board no longer reads, issues, or renews them. The reference launcher reapplies
its Board Secret with only the Transit seed after the new pod is ready.

## Deployment boundary

Board is for private deployments. Network reachability admits viewers to its
shared inspection scope; Board does not authenticate individual people or agents.
Use network restrictions or a separately managed authenticated ingress to control
that reachability. Host/Origin checks are browser protections, not authentication.

By default, remote `public_origin` requires HTTPS at a trusted TLS ingress. Board itself
serves private HTTP. Match the configured Host exactly; pass the original Origin.
Strip `Forwarded` and `X-Forwarded-{Host,Proto,For}` headers: Board rejects them
and does not use them to authenticate proxy claims. No CORS or credentialed proxy
surface is available. By default, plain HTTP is accepted only for a `127.0.0.1` public origin.
Keep the listener private and permit egress only to its configured Transit service
and required DNS. No service-account token, storage credential or provider
credential belongs in the pod. Host validation is also required on health probes.

For a trusted development LAN, explicitly set `development_allow_insecure_http`
to `true` to allow an origin such as `http://devbox.local:18102`, with `listen`
set to `0.0.0.0` and `port` set to `18102`. This opt-in sends inspection data over
unencrypted HTTP; exact Host/Origin checks and the upstream read-only grant still
apply. Its default is false. HTTPS remains required for normal remote
deployments. The [launcher settings](../../launchers/README.md#local-development-configuration)
expose these fields through a Git-ignored `.env` loaded by `.envrc`.

## Bounds and observations

One request executes at a time, with an overall deadline (100–5000 ms). Upstream
calls have a shorter timeout; no redirects or response cache. The minimum spacing
between upstream reads is 100 ms by default (configurable up to 5000 ms), shared
across viewers. Excess reads get `429 RateLimited`; clients back off. Headers are
8 KiB, request bodies 4 KiB (routes accept empty bodies), request targets 1024 bytes,
and upstream responses 256 KiB. Lens mappings are bounded.

Each data response preserves the public inspection observation plus optional
lens/causal facts. Pages contain at most 16 facts and journeys at most 32 edges.
Any authority change expires a continuation; busy writes may prevent pagination.
Coverage is explicit after trimming, and no Board cache pins history. A running
lifecycle is not worker liveness; delivered is admission, and closed-unknown is
not external failure. This bounded experimental profile is not a throughput SLA.

## Service diagnostics

Board identifies itself as `transit-board` in service diagnostics. It emits
`board.http.request` records on stderr with method, fixed route
template, status when available, local response-write completion and monotonic
duration. Failed/denied requests and deadlines are visible; successful
`/health` probes are debug-only. Public trace headers are ignored, and credentials, cookies, raw paths,
queries and payloads never appear in these records.

Use `LOG_FORMAT=json` for machine records or the default `text` for foreground
launchers. `LOG_LEVEL` defaults to `info`; `debug`, `warn`, `error` and `off` are
also supported. The [telemetry package](../../packages/zig/telemetry/README.md)
owns the schema, local metric snapshots, context and bounded sink behavior.
`service.starting`, `service.ready`, `service.failed` and `service.stopped` describe
normal execution; abrupt exits and signals are reported by the process manager.
Board's `/health` checks its HTTP/Host boundary, not upstream Transit availability.

Upstream client attempts get their own spans parented to the Board request;
successful attempts are debug-only, failures remain visible at normal verbosity.
An explicitly configured private node can continue that context across ingress
and storage. Local/Compose launchers enable it without forwarding browser-supplied
parents. Use their [per-service settings](../../launchers/README.md#service-diagnostics)
to turn on debug detail while navigating.

## Verification

`just transit-board::check` checks contracts, generated client, strict types, formatting,
lint and frontend unit tests. `just transit-board::test` runs Zig ingress/unit tests and
real disk-backed service proofs. `just transit-board::browser-install` installs the pinned
Chromium; `just transit-board::browser` exercises the real embedded UI with Playwright.
The [test guide](../../tests/README.md) records measured limits and reference evidence.
