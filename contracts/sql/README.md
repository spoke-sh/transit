# SQL extension grammar and rewrite-safety proof

Status: design artifacts, not implemented. [`TransitExtensions.g4`](TransitExtensions.g4)
and [`FuzeRewrite.lean`](FuzeRewrite.lean) are the first checked instances of
the toolchain [`docs/QUERY_LANGUAGE.md`](../../docs/QUERY_LANGUAGE.md) proposes,
not a production parser or a proof about `transit-fuze`'s Zig code.
[`M12` — Declarative interface readiness](../../docs/roadmap/M12.md) owns
turning this into exactly that: `SELECT`/expression grammar, a real
`parse -> Fuze plan` compiler, pinned tooling and a `libpg_query` compatibility
corpus. Nothing here is wired into a build step or `M12`'s exit criteria yet —
these are pre-milestone artifacts it starts from, not partial delivery
against it.

## `TransitExtensions.g4`

The statement forms Postgres has no opinion on
(`CREATE CONNECTION`/`SOURCE`/`SINK`, an `AS OF` fragment), plus the DDL forms
that are relational spellings of typed commands Station already implements
(`CREATE TABLE`/`DOCUMENT`/`KV`, `GRANT`/`REVOKE`, `SHOW`/`DESCRIBE`). It does
not define `SELECT`/expression syntax and is meant to compose with (import
into) a full Postgres-compatible base grammar later — see
[QUERY_LANGUAGE.md](../../docs/QUERY_LANGUAGE.md#defining-and-verifying-the-grammar)
for why that base grammar should come from differential testing against
`libpg_query`, not a hand-derived reimplementation.

Verified with ANTLR 4.13.2 (`nix shell nixpkgs#antlr4`):

```sh
antlr4 -visitor TransitExtensions.g4   # generates cleanly: no ambiguity,
                                        # left-recursion or conflict warnings
antlr4-parse TransitExtensions.g4 extensionStatement -tree sample.sql
```

Nine representative statements (one per rule — `createConnection` with a
secret reference, `createSource`/`createSink` with connection options,
`createTable` with typed/nullable columns, `createKv`, `grantStatement`/
`revokeStatement`, `showStatement`, `describeStatement`, and the `asOfClause`
fragment) parse to the expected tree with zero errors; a deliberately
malformed `CREATE TABLE` correctly produces syntax errors rather than being
silently accepted. This is real tool output, not asserted; reproduce it with
the commands above.

## `FuzeRewrite.lean`

A complete, `sorry`-free Lean 4 proof (checked with Lean 4.30.0,
`nix shell nixpkgs#lean4`; `#print axioms` reports only `propext`, never
`sorryAx`) that reordering two sequential row-selecting predicates never
changes which rows are selected or their order — the safety condition a real
predicate-pushdown rewrite needs, stated at the abstraction FUZE.md's
planning section already commits to ("every rewrite must preserve the
specified result schema... and ordering").

This formalizes the *specification* in `FUZE_V1.md`, not the Zig
implementation — model/implementation correspondence is a separate, stated
assumption here, exactly as `Authority.tla`'s relationship to the real engine
is. It is the first concrete instance of the theorem class
[`docs/TESTING.md`](../../docs/TESTING.md#formal-models) already scoped Lean
for ("a Fuze rewrite with exact error semantics") — chosen because it is the
smallest real instance of that class, not because it is the most valuable one
to prove next.

```sh
lean FuzeRewrite.lean
```

## What would make either of these real

Neither is wired into `just check` or a CI lane yet; `M12`'s entry gates
list exactly what would change that: pinning `antlr4`/`lean4` in `flake.nix`
the way `nixpkgs#tlaplus` is already pinned for `just test::model`; a
`libpg_query`-based differential corpus and comparison harness; deciding
whether the Zig production parser is hand-written or generated from a Zig
target ANTLR does not natively support; and, for Lean, picking which
*additional* rewrite rules justify formalizing next — a single reordering
lemma does not cover projection, aggregation or limit interactions, each of
which needs its own stated theorem. See [`M12`](../../docs/roadmap/M12.md)
for the scoped version of this list with exit criteria attached.
