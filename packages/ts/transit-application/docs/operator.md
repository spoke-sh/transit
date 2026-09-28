# Operator transport and recovery

`request` validates the generated application host contract before submission and
before exposing a reply. The selected profile uses a private deployment boundary
and separately provisioned native operators; it does not add human accounts,
OIDC, cookies or a host-held operator key.

`OperatorSession` imports a non-extractable WebCrypto Ed25519 key or accepts a host
signer. The trusted Zig host prepares native digest bytes. The browser checks the
returned scope, identity and typed request before signing; this is not a proof
against a compromised application origin or compiler host. Deploy the origin and
its scripts within the operator's trust boundary. Private keys never cross the
HTTP boundary or enter application SQL, logs or saved pending requests.

The session owns at most one uncertain native submission. A failed response keeps
its entire signature and request, including on denial; the caller must inspect
its outcome instead of treating a transport error as an application rejection.
`retry` forwards exactly those bytes without a new identity or signature.
`exportPending`/`restorePending` and the separately saved reviewed plan support
explicit recovery across browser reload;
the package does not persist private keys or requests automatically. Keep the
session above route and interface-generation replacement.

The session shares M21's native caller Web Lock with other same-origin clients.
It waits at most five seconds to acquire the caller sequence before preparing a
submission and holds that lock while its reply is uncertain. Exact retry releases
the lock only after a native receipt. Browser loss releases the physical lock,
not the unresolved operation. This coordinates tabs on one origin; it does not
coordinate separate origins or hosts or replace durable native admission.

A native receipt confirms admission only. `reviewPublication` obtains the current
head and freezes the next revision, complete canonical body, operation, record,
expected base and publication digest under the exact operator and application
scope. A later draft cannot discard that frozen reviewed plan. `publish` asks the Zig `Upload` helper for
one continuation at a time, then signs an ordinary native command. Durable
policy, body validation and the conditional publication owner remain authoritative.
An accepted input awaiting processing can time out; resume the same reviewed
proposal after inspecting progress. Conflicts require a new explicit review, not
an automatically substituted base. Chunk staging does not activate a definition.

SQL compilation, Form/Canvas edits and upload planning cannot admit commands.
`readInterface` returns either the explicitly labeled built-in artifact or one
fully verified published revision acquired through current public reads. Hosts
must not replace a denied published read with a stale or built-in definition.
