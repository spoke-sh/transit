# Documents

`Transit.Station.Sdk.Document` provides immutable structs and tagged results over
the Erlang SDK and shared Zig implementation. It owns no independent merge engine.

```elixir
alias Transit.Station.Sdk.Document
alias Document.{Change, Dot}

{:ok, prepared} = Document.prepare(%Change{
  document: 7,
  replica: 2,
  first: 1,
  operations: [{:assign, %Dot{}, "title", [], {:string, "Notes"}}]
})
```

Within a handler, `Document.owner(turn, 7)` creates a callback-scoped owner.
`Document.create(owner, 1)` initializes the associated resource;
`Document.stage(owner, job, prepared)` advances one bounded publication step.
Repeat the same job and canonical bytes on later turns until its `%Progress{}`
phase is `:accepted` or `:duplicate`, then let the runner commit that turn.
`:progress` denotes staging, not accepted state. An owner cannot escape its
callback or run in a different BEAM process.

`Document.describe(runner, resource, 7)` returns an accepted reference and source
revision. `Document.path(runner, reference, ["title"])` returns a `%PathValue{}`
whose `%Field{}` distinguishes missing, null, scalar, object and conflict.
`Document.observed(field)` supplies assignment IDs for an explicit resolution.
`Document.sequence(runner, reference, object, cursor)` returns a bounded `%Page{}`;
follow `next` until `nil`, including pages with no visible items.

Values use tagged tuples with full-width integers and immutable binaries.
`:text` is editable Unicode scalar text; `{:string, utf8}` replaces one bounded
string. `{:character, codepoint}` represents one scalar, never a surrogate or a
grapheme index. Changes hold at most eight operations, and strings/binary at most
96 bytes. The [Erlang guide](../../transit-station-sdk/docs/documents.md) lists
the complete value model, maintenance operations and read semantics.

Reads need current resource grants and serialize on the existing runner worker.
They do not require writer ownership. `Runner.close` joins admitted native work;
later calls fail closed. BEAM task cancellation does not establish remote
cancellation. Returned structs and binaries stay owned after close. Publication
references and replica IDs never confer authority or revive retired history.

The installed Erlang and Elixir consumers run through
`just bindings::document-beam`; [proof evidence](../../../../tests/README.md#m17-qualification)
records current coverage. These scoped APIs do not imply a remote Document
submission protocol or automatic foreign worker placement.
