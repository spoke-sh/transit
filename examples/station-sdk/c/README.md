# Typed C Station examples

M11's installed C application library
contains the shared counter/requester and Table/query requester handlers, with
strict versioned codecs and full u64/i64 values. Applications use the public C
SDK; they do not pump native actions or import repository source files.
`just bindings::c-sdk-test` installs and runs the actual counter executable and
the Table/query callback library through the shared authority schedule.

`transit-c-counter URL service|requester REALM PRINCIPAL PID GENERATION SEED_FILE
PEER COMMITS PENDING_FILE` runs a bounded number of committed inputs. The host
persists every exact mutation before dispatch and stops for explicit recovery on
uncertainty. Configuration assumes an existing authorized process, association
and input; running the CLI does not provision authority or deliver outputs.

The C example codecs are also a direct application-library dependency of the
C++ examples, keeping the two application wire implementations consistent.
Table results arrive as bounded owned segments. The query requester's `consume`
callback borrows a segment and can copy original IPC bytes and metadata before
returning. Such callback effects occur during a private turn and require the
application's own idempotency policy.
