# Documents and collaborative text

Document APIs use immutable `Data` values, `Integer` identities and copied/frozen
binary `String` data. `DocumentValue` explicitly selects null, boolean, signed or
unsigned integer, finite float64, string, binary, map, list, text or character.
Characters contain one Unicode scalar; replacement strings are distinct from
editable text. The shared Zig codec preserves negative zero and full-width values.

```ruby
S = Transit::Station
change = S::DocumentChange.new(
  document: 42, epoch: 1, replica: 7, first: 1,
  operations: [
    S::DocumentOperation.assign('body', S::DocumentValue.new(kind: :text)),
    S::DocumentOperation.insert(
      S::DocumentDot.new(counter: 1, replica: 7),
      S::DocumentValue.new(kind: :character, value: '🙂'))
  ])
prepared = S.prepare_document(change)
```

Preparation is tentative and uses no credentials. Inside a writer handler,
`turn.document(42).create` fixes publication quotas. `stage(job, prepared,
node_limit: 256)` performs one bounded operation per turn; preserve the same job
and bytes across durable scheduling/recovery. A returned `:accepted` or
`:duplicate` revision is private until the runner reports its enclosing commit.
Do not store authoritative progress in handler fields. Document owners expire
with the handler and obey the runner's thread/fiber checks.

`checkpoint`, `merge_window`, `reject`, `collect` and `retire` provide bounded
maintenance and explicit lifecycle policy. Default retention is unlimited; finite
floors advance only on checkpoint publication. Retirement is permanent, separate
from physical collection. These APIs do not implicitly route a large change body
through a mailbox frame; authenticate application routing before writer actions.
The [shared contract](../../../../contracts/STATION_DOCUMENT_V1.md) owns merge,
causal identity, conflict and storage rules.

`runner.documents` exposes current-policy reads without execution ownership.
`describe(resource, id)` supplies an exact accepted reference and the current
resource cut. `path(ref, names)` distinguishes missing/null/object/scalar/conflict;
wrong intermediate types fail explicitly. Assignment IDs support explicit conflict
resolution. `sequence(ref, object, cursor:)` returns at most eight owned items.
An empty continuation page is not EOF. Keep the reference across pages; it cannot
bypass current read grants, the history floor or retirement.

`accepted_change` reads retained tail material and reports checkpoint boundaries.
`resynchronize` returns accepted replica and clock facts, leaving reconciliation
of tentative edits to the application. `DocumentReference.encode/decode` uses the
shared SDR1 codec; reference bytes grant no authority.

Reads run on the runner's existing worker. `close` joins active work and invalidates
saved reader objects. Interrupting a waiting Ruby thread cannot cancel a durable
change or free native work early. `just bindings::document-ruby` installs external
gem consumers for shared fixtures and the publication/read/recovery schedule.
