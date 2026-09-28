# Declarative definitions and operator publication

M23 implementation is in progress. The shared compiler, signed upload owner and
native restart proof are implemented. The optional embedded SQL/Form/Canvas editor passes its native browser, signed
publication and restart proof. The shell and declared routes are implemented; migration and
generated application qualification remain separate work.

Board embeds `board.sql` as its explicit built-in definition. `GET
/api/v1/interface` returns a compiler-validated built-in artifact or a complete
published definition. Static renderer artifacts remain part of the executable;
SQL cannot load code. A supplied `interface` scope selects a durable application
owner. Board's inspection principal then also needs an explicit read grant for
that resource. Each acquisition uses current public reads, verifies the immutable
body and rechecks the head. Before the first publication, the response explicitly
identifies the built-in artifact. Denial, corruption or an unavailable authority
cannot fall back to a cached definition.

The optional `application` configuration enables `POST /api/v1/application`:

```json
{
  "application": {
    "scope": {
      "realm": 49,
      "application": 9,
      "pid": 17,
      "resource": 19,
      "namespace": "23"
    },
    "operators": [65537, null, null, null, null, null, null, null,
                  null, null, null, null, null, null, null, null]
  }
}
```

These are example public identities, not provisioning instructions. Provision the
actual Station application owner with its immutable configuration and independent
bootstrap administrator first, then grant operators native send/read rights and
the owner's publication policy. The server refuses reuse of its inspection,
query or reactive principal as an operator. At most sixteen explicitly allowed
operator identities can access this endpoint; this deployment bound is not the
number of durable application revisions or operators supported by Transit.

The endpoint is disabled when `application` is absent. It requires the exact
configured Origin, Host and JSON content type. Its 512 KiB request cap admits JSON
escaping of a complete 64 KiB program; semantic program, member and upload bounds
remain smaller. It shares the listener's finite handler capacity, request deadline
and read throttle. Telemetry records the fixed route, never program or key bytes.

The private deployment boundary admits inspection viewers. Operator writes
additionally require an attributable native signature, current native grants and
current application policy. The trusted host prepares the shared native digest;
the browser signs it with a locally imported PKCS#8 Ed25519 key. The host never
receives that private key. This profile trusts the application origin and scripts;
it does not establish human authentication or defend against a compromised origin.

SQL, Form and Canvas edits return to the same Zig semantic validator. Review
freezes the exact expected base, next revision and publication digest. Publishing
stages bounded parts and activates only after complete owner validation. A native
admission receipt is distinct from application completion. Lost replies retain
the exact signed submission across route changes. Explicit pending export/import
supports browser-reload recovery without retaining the private key. See the
[shared browser recovery guide](../../../packages/ts/transit-application/docs/operator.md).
Bootstrap policy repair remains an independently provisioned native administrator
operation; editing a broken definition cannot grant its own recovery rights.

## Routes, sources and recovery

The growing profile renders the current declaration's entry screen, paths, labels,
areas, density and navigation actions. Custom deep links load the static application shell; the renderer then acquires
the current authorized definition and reports absent screens explicitly. Loading
this public artifact grants no data access and does not require a native read. System paths under
`/api`, `/assets`, `/health`, `/openapi`, `/processes` and `/recovery` are reserved.
`/recovery/definition` always reaches the independently admitted operator editor;
publication cannot remove this path. Failed current reads clear declared views,
while exact pending operator requests remain recoverable there.

The monochrome shell uses a 56 px header, 208 px sidebar and 32 px content inset at
1440 px. Comfortable/compact density is a presentation choice. One five-second
current-definition poll is active per visible client, with no retained historical
catalog. Activity shows one authorized page of per-PID counters, not an event log
or cross-process causal history. Operations distinguishes the current inspection
identity from configured endpoint and declared dependency metadata.

Worksheet bindings supply the initial SQL and the complete `UQS2` source contract
fingerprint in their `schema` field. This includes Table identity or KV/Document
decoders, not merely column types. The owning Zig compiler supplies fingerprints;
the browser compares them before admission and before presenting verified results.
Table v1 adds an optional `contract` read without changing existing response shapes.
Unified queries reuse their existing compilation and manifest contract evidence.
A mismatched binding clears result presentation without replacing pending requests.
Both workspace profiles retain uncertain native submissions above route lifetime.
An explicitly resumed prior upload preserves its original frozen plan. Follow is
available only for declared Table follow bindings and uses their finite starts
budget; snapshots never acquire Follow implicitly. Business renderers and command
codecs belong to the downstream application artifact.

## Bounded Atlas evidence

Atlas filters only its authorized eight-process/eight-resource page before
computing visible counts or ordering outliers. Identity order is stable; waiting
inputs and current KV key counts have separate explicit sort choices. Resource
bindings display the resource projection. Every backing resource has one plot;
current keys are not Table rows, value bytes or disk use. The monochrome inbox
well uses one inset pixel per waiting input, capped at eight with the exact count
still labeled. The independent dashed outbox shoulder represents unavailable
count evidence. Age and physical worker readiness remain unavailable.

**Inspect participation** reads `/api/v1/resources/{id}/participation`. It checks
current metadata access before and after bounded acquisition, plus current
inspection identity. One process page and one association page per process cost
at most thirteen native reads. Counts are filtered by native authorization before
a selected resource contributes. This is association evidence, not traffic,
readiness, a census or permission to read values. Each association page preserves
its own observation position; the process page and final resource metadata may
have different positions. No global snapshot is inferred.

`after` with `position` continues the process page. `pid` selects one participant;
`association_after` with that PID and the original association `position` follows
its association page. Mixed process/association cursors reject. A changed cut
requires an explicit fresh scan; the UI clears the failed page rather than merging
incompatible counts. It holds one response, discards denied contributions and
pauses hidden-tab reads. Ten shared aliases in the native proof still produce one
backing-resource plot and one row per PID on each displayed association page.

Use **Abandon upload and release staging** to close an unpublished reviewed
operation and finish bounded collection. An interrupted collection retains the
same recovery controls and reviewed plan. The editor permits replacing that plan
only after cleanup releases its reservation. This does not retire an active
interface or erase retained history; attempting to abandon an applied revision
returns a conflict.
