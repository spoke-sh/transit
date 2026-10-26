# Documents

The Java 21 `Document` API provides immutable changes, scoped publication jobs
and asynchronous accepted-state reads. The shared Zig implementation owns all
codec, merge, publication and authority semantics. Document and replica identities
use full-width `BigInteger` u64 values; signed scalar integers use `long`.

Construct `Document.Change` from one to eight operation records and call
`Document.prepare`. `Prepared` owns immutable canonical SDC1 bytes. `decode`
returns Java records through the same shared codec. Value types distinguish
null, signed/unsigned numbers, finite doubles, strings, binary, map/list/text
creation and a Unicode scalar code point. Invalid UTF-16 surrogates reject;
text edits use stable dots rather than Java string offsets. Constructors copy
lists, and `Bytes.copy()` never exposes the backing array.

A handler uses `turn.document(id)` to obtain a checked owner. `create` configures
explicit quotas; `stage(job, change, nodeLimit)` advances one bounded step. Repeat
the same job and change in later turns until accepted. Progress remains private
until the runner commits. Checkpoints, finite merge windows, rejection, collection
and retirement share the same turn scope. Escaped owner objects reject after the
callback. Unlimited retention is the default; retirement remains permanent.

`runner.documents()` returns a stateless reader facade. `describe`, `path`,
`sequence`, `acceptedChange` and `resynchronize` return `CompletableFuture` values
through the runner's bounded worker. Read inputs are copied/validated before
submission; pending mutations and concurrent worker admission reject. Results
own their values. A page contains at most eight items and an optional continuation.
Path results preserve missing/null/scalar/object/conflict states; incompatible
traversal fails. Resynchronization reports the accepted reference and replica
predecessor/clock, without replaying old edits automatically.

A reference identifies accepted history and conveys no grant. Every call checks
current read policy, resource lifetime, retained floor and permanent retirement.
Older reference values can remain stable while their resource source cut advances.
Cancelling a future only abandons that wait; close still joins admitted native
work before destroying the port. Close the owning runner explicitly; subsequent
reader calls fail closed and owned results survive destruction.

`just bindings::document-java` installs clean JARs, compiles an external consumer
with all warnings treated as errors, and runs independent change/Unicode/reference
fixtures plus the shared disk recovery schedule. See the
[proof evidence](../../../../docs/history/qualification/runtime.md#m17-qualification).
