# Query assistance v1

Cursor assistance provides context-aware SQL and console suggestions. [CLI v1](TRANSIT_CLI_V1.md) owns terminal
interaction; [workspace v1](../packages/zig/transit-query/docs/unified-client.md) owns
current-authority queries. This contract adds no SQL execution or grants.

The workspace `assist` request contains `sql` (at most 4096 UTF-8 bytes), `cursor`
(a UTF-8 byte boundary), an unsigned 32-bit editor `generation`, and `mode`
(`sql`, default for native callers, or `console`; generated browser requests
include it explicitly). It uses the configured source and caller. Current
native description access is required even for keyword or dot-command suggestions.
There is no global catalog lookup. Console mode includes the versioned dot-command
command vocabulary; it does not execute those commands remotely.

The `assistance` response has version 1, the input generation, `unified_v1`
capability profile, source resource/full `UQS1` contract, a nullable replacement
range `[start,end)` in UTF-8 bytes, and at most eight ordered items. Items contain
insertion text, kind and a presentation detail. The range includes the token's
suffix when the cursor is inside it. Quoted identifiers remain case sensitive;
unquoted prefixes fold case. Inserted catalog identifiers are quoted. Literal
and comment positions suppress completion. Depth, input, result and work bounds
are independent of retained data cardinality.

In console mode, a fully typed keyword at the token's end advances to the next
grammar position when it is the sole match with complete coverage. The response
then uses a zero-width range at the cursor; the console's shared edit helper
adds any required separator. Partial words, interior cursors, quoted names and
limited matches retain their replacement. Ordinary SQL editor mode continues
to complete the current token.

Fuze's production parser supplies keyword, punctuation and name-context
expectations. The query owner supplies authorized names/types and filters against
its executable v1 capabilities. An explicit source alias in the parsed prefix
replaces the original column qualifier; source authorization still uses the
declared source. A source qualifier awaiting a column offers a dot continuation.
It offers scalar comparisons only when the same name also identifies a column;
an already qualified column cannot gain another qualifier. Checked SUM offers
int64 columns only; typed literal suggestions use explicit `'0'::uint64` and `'0'::float64` forms for
those column types. Exact cell-state tests retain all five states. General DDL,
joins, windows and continuous queries cannot appear as executable candidates in
the `unified_v1` profile.
The existing SQL AST limits named identifiers to sixteen bytes, even where the
v1 schema can describe thirty-two-byte names. Those wider names do not become
named SQL candidates; star projection retains its existing compiler semantics.
Candidates are grammar continuations, not promises that an unfinished statement
will compile. Submission always reparses, resolves, validates and authorizes the
complete statement through the owning compiler/client.

Filtering precedes the eight-item bound. Ordering is deterministic: catalog names
in declared column order, then parser alternatives; dot commands use their
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

## Catalog and relational assistance

The catalog uses `DirectTableAssistance` and reports `direct_table_v1`. Its
response identifies the catalog lifetime resource, a null native resource
revision, current policy revision and a commitment to the exact definitions
checked for disclosure. It shares the request, replacement-range and eight-item
bounds above. It reads metadata through `DirectTableClient`; it opens no data
snapshots and prepares no mutation. Source search reads at most 128 catalog pages.

General Table DDL, DML and SELECT use their production parser and current schema.
Names support up to 255 UTF-8 bytes and inserted identifiers are quoted with
embedded quotes escaped. Relational drafts use the relational parser's cursor
expectations. Header discovery can identify up to two aliases even while the
projection is unfinished; this is metadata discovery, not accepted SQL. Both
aliases resolve inside the configured catalog under its current inspection
policy. The complete response is discarded if the catalog revision or policy
changes during construction.

Relational column suggestions admit int64 only. At an unqualified position,
multiple sources produce separately quoted alias/column references; after a
qualifier only its columns are offered. Unknown and ambiguous predicate names
produce no guessed comparison operators. NULL appears for explicit state tests,
not as a comparison literal. Other logical cell states, rich-type comparisons,
LIMIT, HAVING and ORDER BY are excluded from this relational profile. Consumed
JOIN/GROUP/aggregate syntax and aliases receive roles from that same production
parser for console highlighting. Suggested text does not enable relational
execution or bypass the explicit connection configuration and query admission.
