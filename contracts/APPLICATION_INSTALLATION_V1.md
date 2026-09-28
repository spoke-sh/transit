# Local application installation v1

Status: M25 implementation in progress; no end-to-end qualification claimed yet.
Public values live in `transit_client.Application`. The generated structural
schema and semantic validation must agree; declarations are not authority.
See the [generated schema](application-installation-v1.schema.json) and
[shared signing fixture](application-installation-v1.fixture.json).

## Placement and identities

The initial profile is trusted local Linux, with separately compiled Zig workers.
JSON configuration, management and bootstrap values are language neutral. Other
language hosts are not qualified by the Zig example. There is no shell, source
compiler, hot loader or downstream supervisor in the running neighborhood.

The realm installation pins its Transit/provider artifacts independently from
application artifacts. Each application has one stable name and declaration;
roles and resources have application-scoped names resolving to retained native
PIDs and resource IDs. Installer, worker and application caller identities remain
separate. Role contract, artifact/configuration revision, ownership generation,
application data epoch and interface revision are distinct coordinates.

A declaration has version 1, application, roles, resources, callers and optional
initialization messages. It contains at most eight roles, sixteen resources,
eight callers and sixteen initialization messages. Role order is dependency order;
unknown, duplicate or forward dependencies reject before effects. Each role names
its compatibility contract, absolute executable path and SHA-256, bounded UTF-8
opaque configuration, and named resource associations with explicit permission
masks. Only the declared writer may request resource-write permission. Associations
never imply permission independently of those grants. Each native turn still
mutates at most one resource with four mutations.

Callers may receive inspection and optional sending to exactly one declared role,
plus explicit resource inspection/read access. An inspector has no send target.
Only the trusted installer can change physical application deployment. Ordinary
application callers cannot provision principals, change grants or replace workers.
Initialization payloads are complete application-owned Station frames sent by
an authorized declared caller. Transit does not decode their domain meaning.

Names contain 1–64 ASCII letters/digits, underscore or hyphen, beginning with a
letter/digit. Paths are at most 4096 bytes; configuration is at most 8192 UTF-8
bytes per role and the complete management value has a finite encoded-byte bound.
Credentials remain file references; executable/configuration hashes are not proof
that application computation is compatible or honest.

## Management authentication and recovery

Management uses a separate local endpoint and explicit private connection file.
A request names version, installation identity, realm, principal, operation and
one install, replace, status or connect command. `Signed` contains that request,
a public key, native signed identity query and an Ed25519 signature over SHA-256
of `transit.application.v1\0` followed by canonical typed JSON request bytes.
Canonical bytes use declared field order, compact JSON, explicit default/null
fields, decimal integers, UTF-8 strings and numeric arrays for fixed byte arrays.
Union values have exactly one tag field; void payloads are empty objects.
Other object-key ordering is accepted on input, then normalized by typed parsing.
The fixture is checked independently with Python SHA-256 and OpenSSL Ed25519.
The native identity query must name the same realm/principal and verify against
the same public key. The host submits it to current Transit authority before
acting; local cryptographic verification alone never establishes current rights.
The host additionally enforces installer versus application-inspector scope.

The caller freezes a signed mutation before dispatch and retains it across an
unknown response. An operation identity cannot be reused for a changed body.
Repeated installation with the same complete declaration attaches to its existing
identities; a conflicting declaration fails. Replacement names the exact prior
role revision and unchanged compatibility contract. It cannot change resources,
associations, caller grants or unrelated roles. Automatic source rebuild and
neighborhood artifact upgrades are outside this contract.

The manager persists each native signed operation before dispatch and each
accepted receipt before deriving identifiers or advancing provisioning. Private checkpoints
are bounded at 256 KiB per application; public requests/replies at 64 KiB; receipt/revision history grows on disk and is read in
bounded pages. A local accepted management intent is not a native provisioning
receipt or evidence of worker readiness. Local records never override current
native permission, process lifetime or ownership.

`create_principal` refuses existing subjects. Subsequent activations use
`rotate_worker`: a fresh key and ownership generation commit together while
preserving current resource permissions and request sequence. Root-only rotation
checks the old key, generation, PID scope and expected permission mask. It cannot
restore a revoked resource grant. Uncertain native operations retry exact bytes;
changed intent or a new signed sequence cannot resolve a lost reply.

## Worker bootstrap

The manager executes the declared artifact with `--transit-bootstrap-v1 PATH`.
The private file contains `Bootstrap`: version, application, role, contract,
revision digest, native URL/realm/principal/PID/expected generation, an activation
marker directory, named role/resource/caller bindings and opaque configuration.
There is no signing seed in that file. Bindings identify public references,
not access rights. The worker validates the version and bounds, generates a fresh
in-memory key and uses the existing [growing registration](../packages/zig/transit-client/docs/growing-bootstrap.md).
The manager attributes the registration to its owned child and checks every
identity before activation. The worker pins exactly the supplied generation.

Readiness describes an observed activation and host startup. Domain initialization,
committed results, migration verification, data activation, interface publication
and explicit write release need their own public evidence. A launched process,
healthy socket or configuration file cannot establish any of those outcomes.

## Failure boundaries

Bound active applications/roles, native operations per reconciliation step,
registration time, restart attempts, management requests, logs and joined shutdown.
An application role failure restarts only its required local dependency closure;
replacing one application never resets storage or regenerates unrelated roles.
Missing or rolled-back history, exhausted storage and unavailable dependencies
fail visibly. They never permit expiry, empty bootstrap or deletion.

Applications compose the existing migration ledger through authenticated domain
commands. They own the transform, write pause and complete target verification.
A compatible worker can resume retained migration receipts; no automatic schema
conversion or cross-resource transaction is implied by deployment replacement.
Distributed runtime bindings, authority movement and disaster recovery remain M27.
