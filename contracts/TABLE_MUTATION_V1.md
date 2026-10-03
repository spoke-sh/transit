# Table mutation v1

## Scope and owner

Fuze `Sql.parseMutation` parses bounded literal statements and
`TableMutation.compile/lower` binds them to an explicitly supplied Table name
and storage schema. Station `TableMutation.apply/applySql` applies the validated
plan to an application's private `Turn`. These are allocation-free Zig APIs.
The [Table owner](../packages/zig/transit-station/docs/tables.md) defines storage;
the [state contract](STATE_V1.md) defines accepted commits.

An application must explicitly expose the operation and authorize its caller.
The helper does not discover a writer, grant access, submit work or commit.
The console admits SQL mutations through its `writes.table` connection
and private recovery file. The local server provisions this route and its
separate mutation policy for `items`; other connections configure it explicitly. Board, Flight SQL and language SDK query clients do
not admit mutations. A query source declaration or read permission is insufficient.
The canonical request below supports immutable transport; it does not create a
public admission route or standalone transaction session. Table row storage keeps
its existing encoding. Native, ABI and saved-operation definition checks cover
the mutation command semantics; incompatible builds cannot exchange these casts
or reopen each other's authority history.

`transit-query.TableMutationAdmission` supplies an explicitly composed private-turn
admission owner. It stages these requests, checks a separate writer policy and
proposes the terminal result atomically with the rows. The query host exposes it
through `table_writer` and combined `table_query_writer` roles.
Read-query source/requester roles do not dispatch its commands. An integrating application uses Station's frozen
native commit and current authority gates; installed-client write routes remain
separate from this composition API.

## Syntax and types

```sql
INSERT INTO items (id, value) VALUES (7, 12), (8, NULL);
UPDATE items SET value = 13 WHERE id = 7;
DELETE FROM items WHERE id = 7;
```

INSERT supplies both distinct columns in either order and one to three literal
rows. UPDATE assigns the value column and requires primary-key equality.
DELETE also requires primary-key equality. A qualifier must name the supplied
Table. There are no aliases, omitted columns, defaults, key updates, general
predicates, expressions, subqueries, conflict clauses or RETURNING results.
Additional statements and trailing tokens reject. Mutation keywords remain
contextual so existing query identifiers keep their meaning.

The primary key is a non-null signed int64. Values are nullable int64, boolean,
UTF-8 or binary according to the Table descriptor. Text and binary values are
at most 220 bytes. Literal syntax and exact typing reuse the SQL lexer and
literal decoder, including doubled quotes and hexadecimal bytea. No coercion
converts strings, uint64 or float64 to a supported Table value. SQL names remain
bounded to 16 ASCII identifier bytes, statements to 4096 UTF-8 bytes and nested
comments to 16 levels.

## Shared typed plan

`fuze.TableMutation.Target` carries the supplied name and `model.Schema`.
`Plan` owns the schema and one tagged operation:

| Operation | Owned fields |
| --- | --- |
| insert | A contiguous, nonempty prefix of at most three `model.Row` values |
| update | One `model.Row`: key to match and replacement value |
| delete | One int64 key |

`Plan.validate` rejects an empty or sparse insert, repeated keys and wrong
types. SQL lowering additionally checks source/column names, qualification and
key immutability. Typed callers run the same validation before application.
The plan's schema must exactly match the selected Table's current descriptor.
Names and scalar bytes are owned; there are no borrowed SQL slices or heap
allocations. The plan is not a permission or frozen signed recovery token.

## Selection, atomicity and results

Selection uses the supplied private turn's reads, including earlier private
changes in that turn. INSERT is insert-only: any existing or repeated key
rejects the entire statement. UPDATE and DELETE match at most one row. A missing
key succeeds with zero affected rows. Updating an existing row to the same value
counts as one affected row. NULL is a value; a missing row is not a NULL row.

The result is `affected_rows`, an integer from zero to three. It is provisional
until the enclosing native turn commits. A missing-row no-op still needs the
enclosing input-progress commit before the application can report a durable
outcome. No Table revision, receipt or committed result is fabricated locally.

The helper saves and restores the entire proposal on any failure, including
earlier row changes from this statement and output/record changes made by its
helpers. It preserves changes that preceded the call. A failed underlying read
keeps Station's sticky read error, preventing an application from committing a
proposal after swallowing an unavailable read. Schema mismatch, cross-resource
use, type errors, duplicate keys and exhausted mutation budget reject.

At most three row keys are changed by one statement. A fresh native turn has
four mutation slots; the remaining slot can hold an application-owned outcome.
The helper does not reserve that slot or silently discard earlier mutations.
If the complete proposal exceeds the existing turn budget it rejects atomically.
It never splits a statement across turns or raises the authority's limits.

## Authority and recovery

Native acceptance still requires the current fenced writer, resource write
grant, valid captured view and unchanged write revision. Input progress, all
row changes, recorded outcomes and outputs become visible at that one boundary.
The helper cannot bypass an application's command validation or mint execution
rights. Applying a mutation through Fuze alone is impossible.

Applications retain the original admitted command identity and exact signed
proposal under uncertain transport. A fresh statement is new work. Replaying
an already accepted turn reconciles its native receipt; it does not invoke
the helper again to select against newer state. The console composes the signed client below: it persists each exact command,
observes processed input and rejection, then reads terminal status before
reporting applied rows. Its connection grants no authority.

Deleting a current row does not retire its resource or erase retained history,
accepted inputs or receipts. Retention remains unlimited by default. Mutation
results do not dispatch external effects.

## Canonical request

`transit-query.TableMutationRequest` owns the realm, writer PID, resource, Table
ID and validated plan. `fromSql` compiles against the explicitly supplied Table;
`encode/decode` share its exact schema and value codecs with Station. Decoding
copies all names and values. No pointers into an input buffer survive the call.

The following fields are contiguous, with no padding. Integers are little-endian.

| Field | Encoding |
| --- | --- |
| Magic | Four bytes `TMR1` |
| Contract definition | 32 bytes decoded from the native current definition's hexadecimal identifier |
| Realm, writer PID, resource | Three u64 identities in that order; each 1 through the native safe-integer maximum |
| Table | Nonzero u32 |
| Descriptor length | u8 |
| Descriptor | Exactly that many bytes of the current Station `TBL1` schema descriptor |
| Operation | u8: insert=1, update=2, delete=3 |
| Row count | u8: insert=1–3; update/delete=1 |
| Rows | Each has an i64 key; insert/update additionally carry a u8 value length and that many current Table value bytes |

A Table value is version byte 1, non-null byte 0 or 1, and its schema-typed body.
NULL has no body. An int64 body occupies eight bytes; boolean is one byte 0 or 1;
UTF-8 and binary use at most 220 bytes. There is no separate value-type tag:
the exact descriptor supplies the type. The shared Table decoder rejects wrong
widths, malformed UTF-8, unsupported versions and invalid boolean/null framing.

The complete request occupies at most 799 bytes: the maximum descriptor and
three maximum-size Table values. Oversized inputs, truncated fields, trailing
bytes, invalid identities, invalid operation/count and repeated keys reject.
The definition field is mandatory. A foreign definition rejects before operation
decoding; missing fields never default to the current definition. The SQL source
alias and original text are not retained in this normalized typed request.

`reference(namespace)` produces the existing immutable publication reference,
with the target resource, record 1 and format `0x31524d54` (`TMR1`). Its digest
binds the complete encoded request using Station's publication commitment.
`checkReference` validates the Table-mutation publication domain, record, format
and byte budget. The domain isolates uploads from query result budgets and
records even when their full-width namespace IDs match. Publication
reference validation alone does not prove that the bytes decode or that their
target matches the current writer. An admitting owner must validate both, check
current command authorization and record the result at the row-commit boundary.

A request/reference is neither an admitted operation nor a saved signed native
command. Exact recovery still requires the original native identity and signature.
No read-query bundle or query upload is reinterpreted as a mutation request.

## Application-composed admission

`TableMutationAdmission.dispatch` consumes an ordinary Station cast from the
turn's actual delivered input. Its principal comes exclusively from the native
external origin. Process/effect inputs, anonymous principals and non-cast frames
reject. Applications expose this owner explicitly; a public query policy or
source declaration cannot opt into it. `setPolicy` is an application configuration
API, not an unauthenticated message command.

A policy binds one principal, Table ID, exact source-declaration fingerprint,
monotonic revision and a permission mask: INSERT=1, UPDATE=2, DELETE=4. Zero
permissions revokes without deleting history. Installation requires the expected
previous revision and exactly its successor; the initial expected revision is
zero. An exact repeated policy returns unchanged. The current Table declaration
must match. Native current authorization, resource ownership and fencing remain
separate requirements at commit and observation.

Canonical requests of at most 223 bytes support direct `execute` admission in a
single cast. The command binds the namespace, expected policy revision and full
canonical request; its complete immutable reference is derived from those bytes.
The owner checks the authenticated principal, destination, existing namespace,
active upload, current policy and declaration in its captured view. At most three
rows and the full terminal status commit together. No upload or active-pointer
record is created. Repeating an exact terminal identity preserves its original
result; conflicting principal, request or policy identity rejects. Revoked or
stale policy produces a terminal denied outcome without row writes. An active
large-request upload excludes direct admission. Native fencing and current
commit authorization remain unchanged.

The caller selects direct admission by encoded size. Larger requests use the
bounded publication sequence below; both belong to the same current definition.
An uncertain direct send must reconcile its exact signed request. Cancellation
cannot replace that send or undo an applied outcome; after reconciliation it
reports the existing terminal outcome.

One active upload per owning resource is represented by a durable namespace
pointer. Begin binds the immutable request reference, originating principal,
Table, current declaration and expected policy revision. The namespace cannot
already belong to another publication. A repeated exact begin preserves the
original status; changing its reference, Table or policy revision rejects.
Further parts, seal, apply and cancellation carry the complete original immutable
reference and must come from that original principal. The reference's resource
must match the current turn, and every reference field must match the stored
status, including its length and digest. This check precedes staging, application,
cancellation and returning a terminal result. A reused namespace under another
resource or request cannot retarget already accepted input. Callers retain the
reference with their prepared command; they cannot replace it by looking up the
same namespace again during recovery.

An active namespace prevents another begin. A terminal pointer may
be replaced by the next begin; terminal evidence remains retained.

Parts reuse `PublicationParts`: 128-byte halves of a 256-byte immutable chunk.
The maximum request uses four chunks. Parts and seal recheck the original policy
revision and current declaration. An unchanged permission mask with a newer
revision still fences an old upload. Publication sequencing, repeated-half
comparison and digest checks retain their existing meanings. Seal publishes
the complete bytes and marks the status sealed in the same private proposal.
Staging/retained records are paged durable state, not a resident backlog.

Apply requires a sealed namespace and a fresh private proposal. It verifies the
entire immutable request before proposing any row write, then checks the native
definition, realm, writer, resource, Table, descriptor and operation permission.
The final proposal changes at most three row keys plus one status key. That
record holds phase, affected count, reason and original terminal input position;
it becomes a durable result only when the native turn commits. The active pointer
is not cleared in this turn, so the existing four-mutation bound is preserved.
No timestamp, journal position or resource commit revision is invented locally.

An existing row rejects an entire INSERT with `row_exists`. The terminal status
records the attempted key and one-based input row from that rejecting execution.
No rows in the statement are applied. This witness survives replay and restart;
it is not reconstructed from a later read. It contains no stored row value. Policy revocation or
revision change rejects with `denied`; declaration changes reject with
`source_changed`; verified but malformed/incompatible request bytes reject with
`invalid_request`. A helper mutation-budget rejection uses `budget`. Unavailable
reads, corrupt stored descriptors or broken immutable publication integrity
propagate as errors; they never become acknowledged invalid user requests. Any
error restores the incoming proposal and preserves sticky read failure.

`denied` and `source_changed` retain metadata from the rejecting private view.
The witness distinguishes missing, disabled, revised or differently bound policy,
an operation excluded by its permission mask, a missing Table, a changed Table
descriptor, and a request descriptor inconsistent with the staged declaration.
Observed policy revisions, permission masks and descriptor fingerprints survive
later repair and exact replay. Reading this evidence uses current native access;
rendering it performs no new policy or Table reads.

Repeated apply/cancel of a terminal namespace preserves the original result and
input identity without reselecting rows. Cancellation before application records
`cancelled`; an uploading publication is abandoned. Cancellation remains possible
after policy revocation for the original principal, subject to native ingress
authority. It cannot undo an applied mutation. These operations retain publication
bytes, half-chunk scratch and terminal records; they do not run cleanup or opt into
expiry. Native deployment quotas still apply to the retained durable state.

### Record and command encodings

`TableMutationRecords` keys use byte prefix `00 4d`, one tag byte, and two u64
big-endian fields. Tags are policy `p` (principal, Table), status `u` (namespace,
zero), active `a` (zero, zero), and scratch `h` (namespace, zero). The active value
is one nonzero u64 little-endian namespace. Publication keys retain their own
existing domain. All integers below are little-endian and fields are contiguous.

| Record | Fields after four-byte magic |
| --- | --- |
| Policy `TML1`, 57 bytes | principal u64, Table u32, revision u64, declaration 32 bytes, permissions u8 |
| Status `TMS1`, 192 bytes | existing `SPF1` reference 72 bytes, principal u64, Table u32, declaration 32 bytes, policy revision u64, phase u8, affected rows u8, reason u8, terminal input u64, conflicting input row u8, conflicting key i64, witness-present u8, witness 43 bytes |

Phases are uploading=1, sealed=2, applied=3, rejected=4, cancelled=5. Reasons are
none=0, row_exists=1, source_changed=2, invalid_request=3, denied=4, budget=5.
For `row_exists`, conflicting input row is 1 through 3 and key is the signed
int64 attempted key. For all other reasons both fields are zero. A missing,
out-of-range or extraneous witness is invalid. The neutral status includes a
required `conflict` field: `{ "key": "<signed decimal>", "row": <1..3> }` for
`row_exists`, otherwise `null`. Native SDKs expose the key as a signed 64-bit
integer and preserve its full range. Reading a retained witness requires the
same current authorization as reading the original terminal status.
Uploading/sealed require zero count, reason and terminal input. Applied has reason
none and zero to three affected rows. Rejected has a nonzero reason and zero
count. Cancelled has reason none and zero count. Every terminal phase requires a
positive input within the native safe-integer limit. Missing, truncated, trailing
or inconsistent fields reject; stored values never receive compatibility defaults.

The witness is present exactly for `denied` and `source_changed`. Its fields are
kind u8, observed policy revision u64, permissions u8, observed declaration
32 bytes, operation u8. Kinds are policy_missing=1, policy_disabled=2,
policy_revision=3, policy_declaration=4, operation_denied=5, table_missing=6,
table_declaration=7, request_declaration=8. Policy kinds 2–5 require a positive
observed revision and a mask within 0–7 (insert=1, update=2, delete=4). Kind 2
requires zero permissions; kind 3 requires a revision different from the status.
Kinds 4, 7 and 8 require a fingerprint different from the expected declaration.
Kind 5 records insert=1, update=2 or delete=3, excluded by the observed mask.
All unused fields are zero. An absent witness uses flag zero and 43 zero bytes;
flag one requires a valid kind and matching status reason. Other flags reject.
The former shorter status shapes reject rather than synthesizing evidence.

`MutationDiagnostic.status` projects each phase and reason into the shared
diagnostic contract. `bound` additionally verifies the original request
fingerprint before disclosing its primary-key column and caller-supplied name.
`input` projects a writer disposition separately, identifying its native input
rather than inventing a mutation namespace. A terminal result offers no resume
or cancellation action. Pending mutations retain exact-resume and cancellation
guidance; input rejection alone grants neither. Budget quantities absent from
the owner record are marked `unrecorded`.

| Cast payload magic | Following fields |
| --- | --- |
| Execute `TME1` | Namespace u64, expected policy revision u64, canonical `TMR1` bytes (at most 223) |
| Begin `TMB1` | `SPF1` reference, Table u32, expected policy revision u64 |
| Part `TMP1` | `SPF1` reference, chunk ordinal u32, second-half flag u8 (0 or 1), 1–128 payload bytes |
| Seal `TMZ1` | `SPF1` reference |
| Apply `TMX1` | `SPF1` reference |
| Cancel `TMK1` | `SPF1` reference |

Execute occupies at most 243 payload bytes and fits the existing Station frame
bound. Publication commands retain their existing bounded encodings. Namespace-only command
payloads reject; no decoder substitutes a current reference for missing fields.
The contextual publication owner
checks each part's exact required length. Decode borrows part bytes from the
input only for the enclosing handler; durable staging copies them into the private
proposal. Native envelope and persisted-head definition checks bind the enclosing
framework semantics; the canonical request separately requires that definition.

## Signed Zig caller

`transit-query.TableMutationClient` composes the public signed native client.
Applications supply a `Connection` with realm, originating principal, writer PID,
resource and Table ID, plus the caller's key and native transport. The writer
must explicitly expose the admission owner above; configuring a query host or
granting read access does not install a mutation handler. Native ingress rights,
current resource reads and the separately installed mutation policy remain
distinct. The shared client does not discover a writer or provision these grants.

| API | Result and behavior |
| --- | --- |
| `describe()` | Current Table descriptor, principal's mutation policy, resource revision and active namespace from one bounded metadata batch |
| `compileSql(name, text)` | Owned typed request; checks current schema/policy and the operation permission, without submission |
| `prepare(command)` | One owned signed cast for the explicit target; performs advisory current checks without sending |
| `Prepared.save(allocator)` / `restore(allocator, bytes)` | Canonical owned saved operation, bounded to 8192 input bytes on restore |
| `submit(prepared)` | Validates target and signature, then submits the exact original native request; performs no new metadata read, signing or implicit retry |
| `observe(prepared, receipt.position)` | `pending` or `processed` input progress for that admitted send, never a fabricated row result |
| `rejection(prepared, receipt.position)` | Optional recorded input rejection, checked against the original principal, payload and input; separate from terminal request status |
| `status(original_reference)` | Optional durable status bound to the original reference, principal and Table; current native read rights apply |
| `prepareNext(namespace, request)` | One direct execute or next begin/part/seal/apply command from committed state, or null for an existing terminal result |

The saved envelope has required `version` (1), current `definition`, `connection`
and `signed` fields. All connection identities and nested native fields retain
their owning bounds. Canonical equality rejects missing/defaulted fields,
unknown fields, trailing content and alternate JSON encodings. Restoring copies
the complete operation; no reference into input bytes survives. Structural checks
run before network use, and submission verifies the native signature with the
configured key. Connection metadata grants no authority; the signed frame and
stored immutable request determine the operation the writer may apply.

On uncertain submission, keep and resubmit the exact `Prepared` object or its
saved bytes. Do not prepare a new sequence, recompile the SQL, change its target
or choose an upload successor. After reconciling the native receipt, observe its
input as processed and check its input rejection before preparing the next step. Callers serialize commands
for a principal; separate handles may race for the native sequence and receive a
conflict. No automatic re-signing resolves that conflict. A send receipt proves
mailbox admission, while the terminal status records application, rejection or
cancellation. A processed staging input alone proves none of those outcomes.

Upload resumption uses the original owned canonical request and namespace. Its
full reference must match stored status. Each step reads at most six requested
metadata keys at one current resource revision, plus a previous active status
when checking whether its terminal pointer can be replaced. It validates an
existing half against the exact original bytes before selecting the second half.
The next command copies its part bytes into the signed native frame before
returning. Only immutable feature support is cached; credentials, metadata,
policy and authorization are not cached. Admission rechecks all applicable
conditions at the writer's captured commit basis.

Current policy denial prevents compilation and new uploads. Apply and cancel
can still be prepared for an existing request after application-policy revocation
so the writer can record denial or cancellation. Terminal observations retain
their original input/result identity; cancellation cannot undo applied rows.
Unavailable reads, writer changes, conflicting references and malformed staging
records propagate without inventing a result or submitting a replacement.

## Explicit writer host

The query host's `table_writer` role installs `TableMutationWriter` and its
input guard together. Configuration names an existing resource, initializer
principal, initial caller principal, Table ID, column names, value type and
initial permission mask. Resource and caller are positive native identities;
the initializer may explicitly be root (0). Table defaults to 1, names to `id`
and `value`, and type to int64. Permissions are required (bits 1/2/4 above).
The resource must be the worker's required state association and have the current
writer/grants. Configuration does not create the native resource or mint rights.

Before exposing caller ingress, deliver the exact `initializeCommand()` cast
from the configured initializer. One native turn writes the empty Table schema,
initial revision-one policy, immutable writer configuration and Station behavior
descriptor: four mutations total. Existing Table metadata rejects. Uninitialized
foreign input cannot initialize the writer. Exact repeated initialization is a
no-op. Every later input compares the current resource and stored configuration;
changing the configuration file or association cannot silently adopt other data.
Initial policy settings in this immutable configuration remain distinct from
later observed policy revisions.

`PolicyChange` is a separate administrative cast, accepted only from the
configured initializer. It carries the exact resource, expected previous policy
revision and full next policy. Its Table must match the configured Table; its
principal can name an additional caller. Schema fingerprint, monotonic revision
and zero-mask revocation use the same admission policy owner. It does not change
native grants. Native input progress and the policy update share one turn.

After initialization the guard rejects malformed frames, process/effect origins,
unsupported commands and unauthorized administration before Station's other
frame handlers can interpret them. Known command conflicts record a bounded
input disposition and consume that input, leaving the original request status
intact. This lets a caller observe a premature apply, busy upload or stale policy
without stopping later valid work. Unavailable/poisoned reads, stored corruption,
broken publication integrity and changed writer configuration propagate; they
never become fabricated command rejections. The host preserves its existing
fenced activation, exact pending commit and transient-read recovery rules.

Input dispositions use key `TableMutationRecords.key('e', input, 0)`. They retain
the originating external principal (0 for non-external rejected input), original
input position, a domain-separated hash of the complete delivered Station frame
and a reason. They are not terminal mutation outcomes or row counts. The shared
client checks principal/input/payload before returning `rejection`. Current read
grants apply. Dispositions, configurations and policy history have no automatic
expiry; retained cardinality is independent of resident memory.

| Record or cast | Contiguous little-endian encoding |
| --- | --- |
| Writer configuration `TMW1`, at most 73 bytes; key `('w',0,0)` | resource u64, initializer u64, initial caller u64, Table u32, descriptor length u8, shared `TBL1` descriptor, initial permissions u8 |
| Initialize `TMI1`, 44 bytes | resource u64, SHA-256 of `transit.table.mutation.writer.v1` + NUL + complete configuration bytes |
| Policy change `TMG1`, 77 bytes | resource u64, expected revision u64, complete 57-byte `TML1` policy |
| Input disposition `TME1`, 53 bytes | principal u64, input u64, SHA-256 of `transit.table.mutation.input.v1` + NUL + complete frame bytes, reason u8 |

Disposition reasons are invalid_command=1, denied=2, identity_conflict=3, busy=4,
not_found=5, not_active=6, upload_closed=7, not_sealed=8, invalid_part=9,
incomplete_upload=10, source_changed=11 and stale_policy=12. Missing, truncated,
trailing or invalid fields reject. The role does not install a query peer or
execute query calls; client/CLI/SDK read-query routes retain their own profiles.

The separate [combined Table owner](TABLE_QUERY_WRITER_V1.md) installs this
mutation handler alongside a finite query source through a bounded two-turn
initializer. It preserves the same mutation caller, status and policy contracts.

## Neutral caller values

`TableMutationBridge` owns language-neutral actions and results above the signed
Zig client. Its returned strings and schema names belong to the supplied result
allocator; decoded requests own their cells and names independently of input
bytes. The [native ABI/port caller](../packages/zig/transit-station-bindings/docs/table-mutations.md)
exposes these actions through an explicit mutation profile. Idiomatic CLI/language
adapters have separate integration boundaries. A local bridge value does not establish a write route,
current grants or a running compatible writer.

Native realm/principal/PID/resource/input/revision counters and Table IDs use
validated JSON numbers within their native bounds. Namespace IDs use canonical
unsigned decimal strings, preserving all 64 bits. Policy revisions also use
decimal strings but retain their native safe-counter bound. Request bytes,
publication references, declaration digests and command parts use hex strings;
outputs use lowercase. SQL retains the compiler's int64/null/bool/UTF-8/binary
rules. No mutation value passes through a JavaScript floating-point number.

| Action | Result and boundary |
| --- | --- |
| `capabilities` | Local bounded mutation support; does not read or authorize a writer |
| `describe` | Current Table names/type, resource revision, policy revision/declaration/mask and active namespace |
| `compile {name, sql, namespace}` | Current-policy checked canonical `request` hex and complete `reference` hex; does not admit work |
| `next {request, reference}` | Optional opaque prepared string for one command; recomputes the request commitment and rejects changed references before reading staging state |
| `prepare` | Explicit begin/part/seal/apply/cancel with full reference; returns one opaque prepared string |
| `submit` | Original opaque string only; returns a native receipt, preserving explicit uncertainty and exact retry |
| `observe {prepared, input}` | Pending/processed progress for the original admitted input |
| `rejection {prepared, input}` | Optional separate writer disposition after processing |
| `status` | Original full reference; reads durable status under current native grants, even after mutation-policy revocation; returns null when absent |

Begin includes Table ID and decimal policy revision. Parts include ordinal,
second-half flag and bounded hex bytes. Seal/apply/cancel carry the full reference.
Compilation binds the caller's explicitly configured resource, writer and Table.
Persist both compiled fields unchanged before staging. A null `prepared` result
means terminal staging state; inspect status to distinguish application, rejection
and cancellation. It does not imply success. Reconcile and inspect the preceding
prepared input before requesting a successor. Saved signed strings remain opaque:
language adapters must not parse/re-encode, replace, or re-sign them after timeout.
