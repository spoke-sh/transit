# Board

Inspection-only Zig service containing the static [Board frontend](../board-web/README.md)
and [OpenAPI v1](../../contracts/board-v1.openapi.json). Its only application
libraries are `transit-client` and `board-api`; it has no kernel, Ursula, provider,
or handler dependency. [Board's design](../../docs/BOARD.md) owns the architecture.

## Try it

```sh
nix develop
just board::install
just board::demo
```

The demo starts isolated disk-backed Ursula, Transit, and the real counter caller.
It prints a loopback URL and an access-key **file path**. Read that file locally
and paste its contents into the login form. Ctrl-C removes the disposable realm.
No access key enters the URL or logs.

For a persistent development system with an actively polling caller, use
`just launchers::local::up` or `just launchers::compose::up` instead. Their
[guide](../../launchers/README.md) covers logs, inputs and restart without losing
the realm. To configure Board against another provisioned realm:

```sh
just board::build
zig-out/bin/board /absolute/path/board.json
```

`just build` also installs Board. Building requires the locked frontend dependencies;
running the resulting binary requires neither Node nor a checkout/assets directory.
The build embeds up to 128 files / 8 MiB, with no external fonts, CDNs, or runtime
downloads. Static assets and `/openapi/v1.json` are public; installation data is not.

## Configuration and provisioning

```json
{
  "upstream": "http://127.0.0.1:8080",
  "realm": 71,
  "principal": 2,
  "seed_file": "/run/board/transit-seed",
  "credential_file": "/run/board/access-key",
  "public_origin": "http://127.0.0.1:8090",
  "listen": "127.0.0.1",
  "port": 8090,
  "session_seconds": 900,
  "request_timeout_ms": 1500,
  "upstream_timeout_ms": 800,
  "read_interval_ms": 100,
  "lenses": [{"pid": 1, "kind": "rey.example.counter", "version": 1}]
}
```

An administrator provisions the realm and records a grant for this principal
with **only `inspect` (16)**, optionally restricted to one PID. Board rejects
principal zero and refuses data from a grant with any additional permission.
`seed_file` is that principal's 32-byte Ed25519 seed as 64 hex characters. Generate
the separate access key with a cryptographic random source: 32 bytes, also hex.
Use restrictive file/Secret permissions. Credentials never belong in Git/config
maps, frontend assets, query strings, or application history.

Every admitted human or agent shares this instance's explicit Transit scope.
There is no per-user delegation. Configure separate instances/principals for
separate scopes. Upstream URLs, signing identity and lens mappings are trusted
operator configuration, never accepted from requests.

Browser sign-in exchanges `Authorization: Bearer ACCESS_KEY` at
`POST /api/v1/session` for an opaque HttpOnly, SameSite=Strict cookie, scoped to
`/api/v1/`. Sessions last 900 seconds by default (1–3600 configurable), do not
renew through cookies, and are lost on restart. At most 32 sessions exist;
exhaustion rejects sign-in. Expiry uses the OS boot clock, including suspension
on the supported Linux/macOS implementations. `POST /api/v1/logout` invalidates
the presented session. Rotation is an atomic replacement of the access-key file:
every API request rereads it, invalidating all sessions tied to the old key.
Transit seed rotation likewise takes effect on subsequent data calls; coordinate
it with the authority's grant update. Permission revocation is checked upstream
on every data read. Released bytes cannot be recalled.

Agents use the same bearer credential directly against `GET /api/v1/…`.
Only session creation/logout use POST; neither mutates Transit. The OpenAPI lists
the process, mailbox, outbox, effect, payload-metadata, history and journey routes.
See [inspection v1](../../contracts/INSPECTION_V1.md) for cut/continuation semantics.
Query errors are JSON, including unknown API routes; they never fall through to HTML.

## Deployment boundary

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
set to `0.0.0.0` and `port` set to `18102`. This opt-in sends credentials and
sessions over unencrypted HTTP and omits the cookie's Secure attribute;
authentication, HttpOnly/SameSite cookies, exact Host/Origin checks and read-only
grants still apply. Its default is false. HTTPS remains required for normal remote
deployments. The [launcher settings](../../launchers/README.md#local-development-configuration)
expose these fields through a Git-ignored `.env` loaded by `.envrc`.

## Bounds and observations

One request executes at a time, with an overall deadline (100–5000 ms). Upstream
calls have a shorter timeout; no redirects or response cache. The minimum spacing
between upstream reads is 100 ms by default (configurable up to 5000 ms), shared
across viewers. Excess reads get `429 RateLimited`; clients back off. Headers are
8 KiB, request bodies 4 KiB (routes accept empty bodies), request targets 1024 bytes,
and upstream responses 256 KiB. Sessions and lens mappings are fixed/bounded.

Each data response preserves the public inspection observation plus optional
lens/causal facts. Pages contain at most 16 facts and journeys at most 32 edges.
Any authority change expires a continuation; busy writes may prevent pagination.
Coverage is explicit after trimming, and no Board cache pins history. A running
lifecycle is not worker liveness; delivered is admission, and closed-unknown is
not external failure. This bounded experimental profile is not a throughput SLA.

## Verification

`just board::check` checks contracts, generated client, strict types, formatting,
lint and frontend unit tests. `just board::test` runs Zig ingress/unit tests and
real disk-backed service proofs. `just board::browser-install` installs the pinned
Chromium; `just board::browser` exercises the real embedded UI with Playwright.
The [test guide](../../tests/README.md) records measured limits and reference evidence.
