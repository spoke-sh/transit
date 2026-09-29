# Query assistance v1

Status: implemented cursor-assistance contract. [CLI v1](TRANSIT_CLI_V1.md) owns terminal
interaction; [workspace v2](../packages/zig/transit-query/docs/unified-client.md) owns
current-authority queries. This contract adds no SQL execution or grants.

The workspace `assist` request contains `sql` (at most 4096 UTF-8 bytes), `cursor`
(a UTF-8 byte boundary), an unsigned 32-bit editor `generation`, and `mode`
(`sql`, default for native callers, or `console`; generated browser requests
include it explicitly). It uses the configured source and caller. Current
native description access is required even for keyword or slash suggestions.
There is no global catalog lookup. Console mode includes the versioned slash
command vocabulary; it does not execute those commands remotely.

The `assistance` response has version 1, the input generation, `unified_v2`
capability profile, source resource/full `UQS2` contract, a nullable replacement
range `[start,end)` in UTF-8 bytes, and at most eight ordered items. Items contain
insertion text, kind and a presentation detail. The range includes the token's
suffix when the cursor is inside it. Quoted identifiers remain case sensitive;
unquoted prefixes fold case. Inserted catalog identifiers are quoted. Literal
and comment positions suppress completion. Depth, input, result and work bounds
are independent of retained data cardinality.

Fuze's production parser supplies keyword, punctuation and name-context
expectations. The query owner supplies authorized names/types and filters against
its executable v2 capabilities. Checked SUM offers int64 columns only; typed
literal suggestions exclude unsupported uint64/float64 comparisons. General DDL,
joins, windows and continuous queries cannot appear as executable candidates.
The existing SQL AST limits named identifiers to sixteen bytes, even where the
v2 schema can describe thirty-two-byte names. Those wider names do not become
named SQL candidates; star projection retains its existing compiler semantics.
Candidates are grammar continuations, not promises that an unfinished statement
will compile. Submission always reparses, resolves, validates and authorizes the
complete statement through the owning compiler/client.

Filtering precedes the eight-item bound. Ordering is deterministic: catalog names
in declared column order, then parser alternatives; slash commands use their
declared stable order. Ranking is a presentation choice, never authority. The
first profile does not query data values to complete literals or arguments.

An editor owns at most one outstanding request and one response. It captures the
exact text/cursor, generation, resource, contract and caller context. Any change,
denial, hidden/unmounted view or stale response clears suggestions. Acceptance
only replaces the indicated text and is undoable; dismissal changes nothing.
The browser converts UTF-16 positions and rejects a split surrogate. Neither
selection nor typing dispatches SQL; separately admitted Live sessions retain
their existing explicit scheduling contract.

Independent native/browser/terminal fixtures must cover incomplete prefixes,
mid-token replacement, qualified/quoted identifiers, comments, literals, source
denial, schema changes, late responses, capability exclusions and meta arguments.
Report measured latency and actual source sizes separately from these bounds.
