# Documents

`transit_document` exposes canonical changes, scoped writer jobs and independent
accepted-state reads through the shared Zig implementation. Include
`transit_station_sdk.hrl` for the immutable public records. This API does not run
a separate CRDT or infer remote writer routing.

```erlang
Root = #transit_document_dot{},
Change = #transit_document_change{
    document = 7, replica = 2, first = 1,
    operations = [{assign, Root, <<"title">>, [], {string, <<"Notes">>}}]
},
{ok, Prepared} = transit_document:prepare(Change).
```

Scalar values use tagged tuples: `{signed, Integer}`, `{unsigned, Integer}`,
`{float, Float}`, `{boolean, Boolean}`, `{string, Utf8}`, `{binary, Bytes}` and
`{character, Codepoint}`; `null_value`, `map`, `list` and `text` are atoms.
Integers preserve their full 64-bit ranges. Text positions are Unicode scalars,
not bytes or grapheme clusters. Changes contain at most eight operations; inline
strings/binary are at most 96 bytes. Shared Zig validates canonical encoding,
operation identities and merge semantics.

Inside an active handler, `create(Turn, Document, TypeRevision)` initializes the
associated resource. `stage(Turn, Document, Job, Prepared)` advances one bounded
step. Repeat with the same durable job identity and bytes until its
`#transit_document_progress.phase` is `accepted` or `duplicate`. A `progress`
result is private staging, not acceptance. Commit the turn through the runner;
the handler's return value alone is not durable evidence. The turn expires at
callback completion and rejects access from another BEAM process.

`checkpoint`, `merge_window`, `reject`, `collect` and `retire` operate through
that same scoped turn. Retention is unlimited by default. Resynchronization
returns the accepted reference, floor, replica predecessor and logical clock;
it does not replay stale edits automatically. Permanent retirement cannot be
undone with an old reference or replica identity.

`describe(Runner, Resource, Document)` returns a reference and actual source cut.
`path(Runner, Reference, Names)` preserves missing, null, scalar, object and
conflict states. Resolve conflicts explicitly with observed assignment IDs.
`sequence(Runner, Reference, Object, Cursor)` returns at most eight items and a
continuation; an empty page with a continuation is progress, not completion.
`accepted_change` and `resynchronize` use current read authorization too.
References never confer rights. Returned binaries and records remain owned after
the runner closes.

Reads run on the runner's existing serialized worker without writer ownership;
a read-only principal can use them. Closing the runner joins admitted native
work, and subsequent calls fail closed. Killing an awaiting BEAM process is not
proof that native work was cancelled. In-flight uncertainty still uses the
runner's recovery contract.

`just bindings::document-beam` installs and exercises both Erlang and Elixir
consumers against disk Ursula. See the [executed evidence](../../../../docs/history/qualification/runtime.md#m17-qualification)
for the bounded failure schedule and qualification limits.
