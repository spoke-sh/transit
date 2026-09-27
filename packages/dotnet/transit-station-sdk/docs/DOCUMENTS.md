# Documents

The .NET 8 `Document` API exposes immutable changes and bounded accepted-state
reads over shared Zig. It adds no C# CRDT implementation. Document/replica/dot
identities use full-width `ulong`; signed values use `long`, and text characters
use `System.Text.Rune`. Map/list/text creation is distinct from string replacement.
Constructors copy operation/observation lists and validate finite floats, UTF-8
bounds, Unicode and scalar shapes. `Bytes.Copy()` preserves immutable backing data.

`Document.PrepareAsync` validates and encodes a `Change` through the shared codec.
Its `Prepared` result owns canonical SDC1 bytes; `DecodeAsync` returns native C#
values. `Document.Reference.DecodeAsync` validates SDR1 references without granting
access. Local codec calls use a joined native worker with the required stack size.

Within synchronous handlers, `turn.Document(id)` returns a scoped owner. `Create`
takes explicit quotas; `Stage(job, change, nodeLimit)` advances one bounded durable
step. Repeat the same job and bytes in later turns until accepted. Checkpoint,
merge-window, rejection, collection and retirement operations use that same scope.
The result remains tentative until the runner commits. Escaped owners reject;
handler fields and tasks do not preserve durable state. Unlimited retention is
the default and retirement is permanent.

`runner.Documents` is a stateless reader facade. `DescribeAsync`, `PathAsync`,
`SequenceAsync`, `AcceptedChangeAsync` and `ResynchronizeAsync` use the runner's
bounded worker. Path results preserve missing/null/scalar/object/conflict states;
incompatible traversal fails. Pages hold at most eight owned items and a bounded
continuation. Resynchronization returns accepted reference and replica clock
information; it does not replay edits automatically. Each operation checks current
resource policy, lifetime, retained floor and Document retirement. Old values can
remain stable while the resource source revision advances.

Cancellation abandons the local wait, not the admitted native work. Asynchronous
runner disposal joins that work before destruction, preserves shutdown evidence,
and makes subsequent reader calls fail closed. Returned values remain owned.
Use `await using` or explicit `DisposeAsync`; do not use `async void` handlers.

`just bindings::document-dotnet` installs clean NuGet packages and runs independent
codec/Unicode/reference fixtures plus the disk recovery/read-authority schedule.
See the [proof evidence](../../../../tests/README.md#m17-work-in-progress).
