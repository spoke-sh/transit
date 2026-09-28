# Live Table views

M21 integration is in progress. `reactive` explicitly composes the shared
`transit-serving-http` host with Board. Browser/placement evidence is tracked in
[the proof guide](../../../tests/README.md#m21-consumer-foundation-in-progress);
compilation does not close those gates.

The optional configuration has `principal`, `seed_file` and `gateway`, using the
[shared gateway configuration](../../../packages/zig/transit-serving-http/README.md).
The gateway's exact `host` and `public_origin` must match Board. Set `reactive:
true`, a 30000 ms connection deadline, four data handlers and
`per_caller_requests: 4` for two streams plus finite reads. Ordinary Board routes
retain their configured 100–5000 ms deadline and read throttle; renew/close/pause
use reserved capacity. Production origins require HTTPS. The shared host permits
HTTP only with explicit `development_allow_insecure_http`; Board's own origin
validation still applies. Web Locks require a secure browser context.

The gateway reader uses separately provisioned current resource grants. Its
`viewer` contains an explicitly provisioned control principal and key file;
`snapshot_values` must be false in Board. Board's base inspection credential
remains read-only. Enabling `viewer.refresh` also requires `query_v2`, with the
same caller principal, requester/ingress PID and request resource. Each worker
needs the cross-resource associations and grants described by the
[durable refresh owner](../../../packages/zig/transit-serving/docs/refresh.md).
Neither associations nor private reachability confer those grants.

Board's Table progress panel displays metadata, data-progress revision and
schema fingerprint through the shared reactive client. It does not decode
application snapshots or turn the whole atlas into one consistent live cut.
Follow is explicit. Pause, route unmount and browser hiding stop acquisition and
lease renewal, then attempt exact control recovery and close. An unavailable
close leaves the lease to expire; it cannot cancel accepted queries.

For an eligible completed v2 Table query, **Follow changes** reuses the submitted
immutable plan and admits new finite query identities through the durable owner.
The SQL draft remains independent. One newest invalidation coalesces source
changes, and the requester fairly chooses between its bounded active views.
Each explicit generation budgets eight selected refresh intents. Exhaustion
stops following; another budget requires an explicit action. Accepted histories
remain retained according to their existing lifetime policy.

The browser verifies a candidate by traversing its ordered segments while
retaining one segment, then rereads its visible page under current authority.
Rows and manifest/profile evidence switch together only after that pass. Pages
and source positions never mix. The displayed snapshot keeps its original basis
through transient failure; current denial or expiry clears protected rows.

Frozen manual query sends and their caller lock live above route components.
They survive in-app navigation and transient atlas failure in the current tab.
Manual uploads and reactive controls use the same per-realm/principal Web Lock
across same-origin tabs. A lock retained through uncertainty must be resolved by
retrying the identical operation; it is not a durable admission grant. Full
browser reload loses this in-memory recovery state; recorded query namespaces
remain recoverable through the existing finite query surface. No offline data or
signing key is stored in browser storage. Different origins and non-browser
callers still require explicit native sequence coordination.
