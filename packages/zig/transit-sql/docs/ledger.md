# Account operation ledger

`Ledger` records SQL operations in one private native KV resource per account.
Table acceptance belongs to the direct Table owner. The ledger retains identity,
an immutable intent reference, dispatch eligibility and the original terminal
outcome. It performs no network sends. `Coordinator` checks current native
ownership before supplying explicit direct operations.

## Identity and roles

Configuration fixes the realm, private resource, owner PID, account fingerprint,
and one to eight database bindings. A binding fixes the catalog scope, direct
service audience, schema identity and selected role. The private resource is
separate from every configured catalog resource. Native grants and current
Table rights govern access; a database name or retained summary grants none.

Worker, ingress, operator control, coordinator and Table caller have separate
roles. The worker commits ledger turns; ingress publishes references; the
coordinator admits validated references and records permanent dispatch eligibility.
Every coordinator mutation checks the delivered native generation. Operator
controls request cancellation or reconciliation and increase explicit capacity;
they cannot manufacture a Table outcome.

Initialization accepts a fresh private resource containing at most the Station
server descriptor. Its immutable configuration fingerprint rejects changed
identity or database mappings. Quota increases are separate retained controls.
Credential rotation cannot change an accepted operation's principal or role.

## Preparation and discovery

`begin` allocates an operation ID from the accepted native input position. A
caller-owned 16-byte nonce indexes that ID and its request fingerprint. Repeating
the same nonce and binding discovers the original operation; altered content
rejects. The ledger reserves capacity before publishing the identity.

The caller freezes complete direct work and stages its canonical `TDI1` bytes
with the direct owner. Staging does not admit execution. The resulting reference
binds the current definition, connection, namespace, complete operation binding
and content length/digest. The ledger publishes its canonical `GIR1` envelope
through `beginIntent`, `intentPart` and `sealIntent`. Row payloads do not pass
through these native control inputs.

When conditional DDL needs no Table mutation, the envelope instead carries an
inline `NameAssertion.Binding`. It freezes the original name condition and
complete proposed declaration commitment. Publishing this reference does not
admit the assertion or reserve its name.

`admitIntent` validates the complete committed reference, its publication digest,
operation identity and configured scope. It retains a commitment to the full
binding and adds the operation to the ready index. All ledger transitions obey
the native limit of four mutations and 256-byte values per turn.

`list` returns at most eight operations. Its cursor binds the account, private
resource, minimum observed revision and last operation ID. Pages acquire current
authority and a cut at or after the previous page. They do not promise one atomic
history snapshot. `discover` and listing start no work. Separate durable indexes
cover incomplete uploads, ready work and retained history, so scheduling does
not load history into memory. One Table operation is active per account.

## Dispatch and terminal evidence

`authorizeDispatch` commits eligibility before the first direct admission attempt.
This fact is permanent: a lost response never restores the before-dispatch state.
The coordinator reads the committed reference, checks the current native owner,
and observes the original direct operation. If absent, it admits the exact saved
content. If admitted, it explicitly executes or cancels that original binding.
A replacement coordinator follows the same path. Transport requests can carry
current credentials while retaining the original work identity and bytes.

`Terminal.fromResult` verifies the complete binding, target interpretation,
resulting definition and direct acceptance position. It projects applied,
rejected or cancelled outcomes, with matched/changed counts for DML. The ledger
accepts completion only after dispatch eligibility and only for its retained
binding. Native control processing alone is never Table completion.

`Terminal.fromReference` also validates unchanged, rejected and cancelled catalog
name assertions. Their retained position belongs to the catalog, their row
counts are zero, and they carry no resulting Table revision. Dispatch may cancel
an unobserved assertion directly. Lost replies and changed names cannot replace
the original condition or turn its outcome into a Table commit.

Status and SQL outcome disclosure reobserve the direct owner under current
rights. A private summary is insufficient. Unknown remote outcomes remain
pending; neither a socket deadline nor a retry creates successor work.

## Cancellation, capacity and lifetime

Before dispatch eligibility, cancellation abandons local work without fabricating
a Table outcome. Afterwards, cancellation requires the direct owner's original
operation and terminal evidence. Socket loss and inspection do not cancel work.

Quotas separately bound retained operation count, unsettled operations and
logical retained/reserved bytes. Pending quota is at most 1024. Each operation
reserves 4096 bytes for its reference and 512 bytes for metadata/terminal evidence.
The configured complete-intent limit is enforced independently; it does not
charge row bytes as native control payloads. These budgets are not physical
filesystem-size guarantees.

New admissions cannot consume existing reservations. Terminal settlement charges
retained reference content and releases unused reservation. Accepted identities
and history remain retained. Quota pressure does not expire work or grant cleanup
rights. Explicit capacity controls preserve the original identity.

## Native control recovery

`Control.Command` encodes `GSQ1`, the mandatory current definition and a bounded
tagged command. Integers are little-endian; optional fields have exact zero/one
presence bytes. Publication parts carry an aligned offset, length and 128 bytes
with zero padding. Foreign definitions, unknown tags and trailing bytes reject.

`Behavior` commits attributed `GSD1` rejection evidence after initialization.
Rejected transition mutations are discarded. Source failures, allocation failures
and host cancellation propagate without fabricating a rejection. `Client.Prepared`
freezes native control bytes and signature. A serialized `ControlLane` retains
an uncertain request before allocating its next sequence. This control protocol
is distinct from direct Table acceptance.

`AccountRuntime.tick` progresses independently of SQL socket lifetimes. It joins
its worker and borrowing sessions before freeing transports. A new activation
requires current native ownership and an already initialized private ledger.
Bootstrap initialization has no SQL listeners. Current ownership, direct Table
completion and current disclosure rights are checked separately.

## Interactive read pin recovery

`ReadPins` owns a private directory per account inside the activation directory.
Before sending `pin`, it atomically publishes and syncs a record containing the
current definition, gateway identity/generation, exact prepared Table binding,
random acquisition identity and expected partition frontier. It durably records
the returned handle before exposing the read. Closing records intent to release
before remote I/O; uncertain release retains the file.

After checking its native generation, the worker visits at most eight directory
entries and reconciles at most one eligible record per pass. Current-generation
active reads remain protected. Closing records and records from earlier
generations use `pin_status` under their original principal and current rights.
An active pin is released; an already released pin needs only journal cleanup.
If acquisition is absent at the same frontier, recovery repeats the original
request and releases it. Absence at a later frontier or a retired object proves
that delayed original acquisition cannot succeed. It never chooses a new nonce
or captures a new frontier.

Denied, unavailable, incompatible or inconsistent evidence preserves the journal
and is reported as `sql.read.cleanup_blocked`. Other work can continue. Cleanup
is not expiry and does not delete Table storage or retention evidence. This
journal makes pin ownership recoverable; it does not make an ordinary SELECT
resumable after losing its session.
