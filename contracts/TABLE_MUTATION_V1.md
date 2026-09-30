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
The console, Board, Flight SQL and language SDK query clients do not yet admit
SQL mutations. A query source declaration or read permission is insufficient.
The canonical request below supports immutable transport; it does not create a
public admission route or standalone transaction session. Existing Table storage
and the native contract definition are unchanged.

`transit-query.TableMutationAdmission` supplies an explicitly composed private-turn
admission owner. It stages these requests, checks a separate writer policy and
proposes the terminal result atomically with the rows. The supplied query hosts
do not dispatch its commands. Its reference-store checks do not establish native
durable recovery or installed-client write support.

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
the helper again to select against newer state. Public SQL admission and durable
result routing require their own implementation before those guarantees can
be offered by a console or SDK convenience API.

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
`checkReference` validates the record, format and byte budget. Publication
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

One active upload per owning resource is represented by a durable namespace
pointer. Begin binds the immutable request reference, originating principal,
Table, current declaration and expected policy revision. The namespace cannot
already belong to another publication. A repeated exact begin preserves the
original status; changing its reference, Table or policy revision rejects.
Further parts, seal, apply and cancellation must come from that original
principal. An active namespace prevents another begin. A terminal pointer may
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

An existing row rejects an entire INSERT with `row_exists`. Policy revocation or
revision change rejects with `denied`; declaration changes reject with
`source_changed`; verified but malformed/incompatible request bytes reject with
`invalid_request`. A helper mutation-budget rejection uses `budget`. Unavailable
reads, corrupt stored descriptors or broken immutable publication integrity
propagate as errors; they never become acknowledged invalid user requests. Any
error restores the incoming proposal and preserves sticky read failure.

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
| Status `TMS1`, 135 bytes | existing `SPF1` reference 68 bytes, principal u64, Table u32, declaration 32 bytes, policy revision u64, phase u8, affected rows u8, reason u8, terminal input u64 |

Phases are uploading=1, sealed=2, applied=3, rejected=4, cancelled=5. Reasons are
none=0, row_exists=1, source_changed=2, invalid_request=3, denied=4, budget=5.
Uploading/sealed require zero count, reason and terminal input. Applied has reason
none and zero to three affected rows. Rejected has a nonzero reason and zero
count. Cancelled has reason none and zero count. Every terminal phase requires a
positive input within the native safe-integer limit. Missing, truncated, trailing
or inconsistent fields reject; stored values never receive compatibility defaults.

| Cast payload magic | Following fields |
| --- | --- |
| Begin `TMB1` | `SPF1` reference, Table u32, expected policy revision u64 |
| Part `TMP1` | namespace u64, chunk ordinal u32, second-half flag u8 (0 or 1), 1–128 payload bytes |
| Seal `TMZ1` | namespace u64 |
| Apply `TMX1` | namespace u64 |
| Cancel `TMK1` | namespace u64 |

These payloads fit an ordinary Station frame. The contextual publication owner
checks each part's exact required length. Decode borrows part bytes from the
input only for the enclosing handler; durable staging copies them into the private
proposal. Native envelope and persisted-head definition checks bind the enclosing
framework semantics; the canonical request separately requires that definition.
