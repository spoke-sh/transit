# Board configuration and deployment

[transit-board](../README.md)

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
  "read_interval_ms": 100
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
separate scopes. Upstream URLs, and signing identity are trusted
operator configuration, never accepted from requests.

Browser and agent clients call `GET /api/v1/…` directly, without bearer tokens
or cookies. Every data read still uses Board's signing seed and rechecks its
current Transit permission. Revocation takes effect at that boundary; released
bytes cannot be recalled. Seed rotation takes effect on subsequent data calls;
coordinate it with the authority's grant update.

The OpenAPI lists the process, mailbox, outbox, effect, payload-metadata, history
and journey routes. See [inspection v1](../../../contracts/INSPECTION_V1.md) for
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
deployments. The [launcher settings](../../../launchers/README.md#local-development-configuration)
expose these fields through a Git-ignored `.env` loaded by `.envrc`.
