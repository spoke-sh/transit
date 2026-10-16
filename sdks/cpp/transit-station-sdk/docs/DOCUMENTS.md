# Documents

The C++17 SDK provides `DocumentChange`, variant `DocumentOperation` and
`DocumentValue` types over the [C ownership boundary](../../../c/transit-station/docs/DOCUMENTS.md).
All codec, merge, publication and authority semantics remain in Zig.

```cpp
using namespace transit::sdk::station;
auto change = prepare_document({42, 1, 1, 7, 0, 1, {
    DocumentAssign{{}, "title", {}, std::string("Shared notes")},
    DocumentAssign{{}, "body", {}, DocumentText{}},
    DocumentInsert{{2, 7}, {}, U'🙂'}
}});
```

A prepared change is move-only and owns canonical bytes; `data()` returns a copy.
Values use int64/uint64/double, owned strings/binary and `char32_t` for one Unicode
scalar. Invalid surrogates and non-finite doubles reject. Map/list/text creation
has a distinct variant from replacement strings. Dots identify sequence elements
and observed assignments; offsets never imply an element identity.

In a handler, `turn.document(id)` retains a checked scope handle. `create` takes
explicit quotas; `stage(job, change, node_limit)` advances one bounded step.
Repeat the same job in later turns until accepted. Every result is tentative
until the runner reports a committed turn. Checkpoint, finite merge windows,
rejection, collection and permanent retirement use the same owner. Copying an
owner does not extend its scope; all methods reject after the handler finishes.

`runner.documents()` returns a move-only RAII reader. `describe`, `path`,
`sequence`, `accepted_change` and `resynchronize` return owned values. Path fields
preserve missing/null/scalar/object/conflict status and visible assignments.
Pages contain at most eight items plus an optional continuation. Readers retain a
safe local runner handle; closing/destroying the runner joins work and subsequent
reader calls fail closed. References identify accepted history but convey no
permissions, so current policy and retained-history checks apply to every read.

`just bindings::document-c` runs the installed C++ API and the independent C11
handler against the same fixture/recovery schedule. It covers prepared-byte
round trips, Unicode, full-width values, scope expiry, host replacement, retained
references, read-only grants, prefix revocation, conflict visibility and retirement.
The [test guide](../../../../tests/README.md#m17-qualification) records results;
remote writer routing and placement remain separate proofs.
