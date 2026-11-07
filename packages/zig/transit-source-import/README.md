# transit-source-import

Component adapter for an already sealed finite HTTP capture. It composes above
[HTTP/Exchange](../transit-station-http/README.md) and the
[data client](../transit-data-client/README.md). It has no HTTP dispatch,
credential resolver, poll scheduler or installed mutation route. SOURCE activation
remains unavailable; this package supplies the retained-input seam for that later
owner. See [SOURCE v1](../../../contracts/SOURCE_V1.md).

`Saved` freezes the original SOURCE, CONNECTION and destination definitions,
poll/attempt, complete Exchange descriptor/reference, verifier, consumer token and
holder, candidate and output transaction originals, and finite budgets. Save it
before calling `Importer.step`. The configured host authenticates the original
attempt and terminal outcome, verifies compatible resource lifetimes and current
source disclosure, and supplies the combined publication guard. A declaration's
executor field or a caller-provided captured state is insufficient authority.

`Importer(Origin)` uses the same `ReplayWithClient` state machine as public HTTP
replay. Origin's `open`/`read` must use the current-authorized Exchange coverage
reader; `retain`/`release` must use the existing authenticated, fenced Exchange
consumer operations with the saved token/holder. The finite caller's hold remains
independent. The adapter never treats a hold as permission to disclose content.

The journal stores an immutable SHI1 original in SOR1 before requesting the hold.
It stores bounded SHP1 progress through the Catalog's reserved CPR1 owner and
discovers unfinished work using paged original-token selection. An interrupted
reservation remains recoverable with the same saved input. The first complete
replay derives status, body length/SHA-256 and terminal evidence. The second pass
copies sequential 64 KiB chunks, then rechecks the complete evidence. Empty
bodies remain explicit observations. Complete non-2xx responses retain their
status and do not imply retry or business success.

Each step advances one durable phase or at most 256 Exchange parts. The input
transcript is bounded to 8 MiB/65,536 members and the body to 4 MiB. Each pass and
restart reserves its entire transcript byte/part work before reading; exhaustion
preserves the original for inspection and explicit cancellation. Scratch has a
2 MiB budget and raw staging uses one reusable 64 KiB buffer. Each active importer
reserves 16 MiB from the shared 64 MiB admission budget, including headroom for its
nested staging/verifier owner. Admission refuses before accepting another owner;
existing owners can finish without competing for that reserved workspace.
Stored history has no resident collection.

Publication uses `CaptureOwner` and the protected original Stream transaction.
Only its authoritative common result permits the journal to record settlement;
the Exchange hold is released afterward. Unknown acquisition, commit or release
retains its original identity. Cancellation closes a private candidate or settles
the original transaction before release; revocation and failed inspection cannot
manufacture an abort. `deinit` frees local working memory only. Keep the saved
original and pending directory entry until explicit terminal release.

The [test index](../../../tests/README.md) links the component proof.
Its fixture explicitly supplies the trusted original owner, executes real Exchange
coverage/hold operations and Catalog/Stream storage, and introduces no network
dispatch capability. A separate process fixture journals those Exchange turns in
TransitLog and survives SIGKILL at reservation, hold, readiness, seal, decision and
release boundaries. Its upstream fixture materialization is separate from the
measured destination and importer budgets. Component tests do not qualify live
HTTP polling, activation or physical power-loss recovery.
