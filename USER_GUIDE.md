# User Guide

This file is for people landing in the `transit` GitHub repository for the first time.

It is not the public product explainer and it is not a normative contract. Its job is to help you navigate the repo, choose the right proof path, and find the public-facing docs that already explain Transit itself.

## Start Here

If you want the product story first, do not start by reading every root Markdown file in this repo.

Start with the public MDX docs instead:

1. [website/docs/intro.mdx](website/docs/intro.mdx)
2. [website/docs/start-here/choose-your-track.mdx](website/docs/start-here/choose-your-track.mdx)
3. [website/docs/start-here/current-capabilities.mdx](website/docs/start-here/current-capabilities.mdx)
4. [website/docs/start-here/embedded-library-first-run.mdx](website/docs/start-here/embedded-library-first-run.mdx) if you want embedded Transit first
5. [website/docs/start-here/server-first-run.mdx](website/docs/start-here/server-first-run.mdx) if you want the daemon and remote CLI surface first
6. [website/docs/reference/foundational-docs.mdx](website/docs/reference/foundational-docs.mdx) when you want the canonical root contracts

That split is intentional:

- the public MDX docs explain product behavior and current capabilities
- the root Markdown files define repo contracts and reference material
- this file only explains how to use the repository without duplicating the public docs

## Choose A Repo Path

### I want the fastest end-to-end proof

Run:

```bash
just screen
```

That is the default human proof path. It exercises the current shared-engine and server surface through one repo-supported flow.

### I want embedded Transit first

Common repo-local entry points:

```bash
just transit proof local-engine --root target/transit-user-guide/local-engine
just transit proof tiered-engine --root target/transit-user-guide/tiered-engine
just transit proof integrity --root target/transit-user-guide/integrity
just transit proof materialization --root target/transit-user-guide/materialization
just transit proof reference-projection --root target/transit-user-guide/reference-projection
just transit status --root target/transit-user-guide/local-engine
```

### I want server mode first

Start a daemon:

```bash
just transit server run --root target/transit-user-guide/server --listen-addr 127.0.0.1:7171
```

Then use the common operator surface:

```bash
just transit streams create --stream-id demo.root --actor cli --reason bootstrap
printf 'hello\nworld\n' | just transit produce --stream-id demo.root
just transit consume --stream-id demo.root --from-offset 0 --with-offsets
just transit streams list
```

Omit `--from-offset` when you want `transit consume` to tail live records from
the current stream head. Pass `--from-offset 0` when you want a bounded replay
from the beginning.

The explicit `streams create` step lets you author root-stream lineage metadata
such as actor, reason, labels, and retention policy. For quick operator checks,
`transit produce` also creates a missing root stream with CLI lineage metadata
before appending the first record.

For lower-level protocol-shaped inspection, the `transit server ...` namespace still exists with `create-root`, `append`, `read`, `branch`, `merge`, `lineage`, `tail-open`, `tail-poll`, and `tail-cancel`.

### I want the current storage and failover slices

Use:

```bash
just transit --config target/transit-user-guide/storage-probe.toml storage probe
just transit proof warm-cache-recovery --root target/transit-user-guide/warm-cache-recovery
just transit proof controlled-failover --root target/transit-user-guide/controlled-failover
just transit proof chaos-failover --root target/transit-user-guide/chaos-failover
```

The warm-cache recovery proof explicitly removes the local server cache and
rebuilds it from the published remote frontier so you can see the authority
boundary, not just a successful restart.

### I want the client path

Use:

```bash
just rust-client-proof
```

## Repo Map

The important top-level areas are:

- [README.md](README.md): product summary and document map
- [crates/transit-core](crates/transit-core): shared engine, storage, lineage, consensus, and server protocol types
- [crates/transit-cli](crates/transit-cli): CLI surface, proofs, operator helpers
- [crates/transit-client](crates/transit-client): thin Rust client over the remote protocol, including replay-driven projection-consumer helpers
- [crates/transit-materialize](crates/transit-materialize): derived-state and Prolly Tree materialization layer
- [website/docs](website/docs): public-facing MDX docs
- [AGENTS.md](AGENTS.md) and [INSTRUCTIONS.md](INSTRUCTIONS.md): repo operator guidance, especially for AI agents and Keel workflow

## Public Docs Versus Root Docs

Use the public MDX pages when you want:

- the product model
- embedded versus server onboarding
- current shipped capabilities
- human-facing walkthroughs

Use the root Markdown files when you want:

- canonical architecture and configuration contracts
- benchmark and release requirements
- workload contracts such as integrity, finality/fork proofs,
  materialization, communication, or AI traces
- repo-local operator rules

The reference pages under `website/docs/reference/contracts` are generated from root docs. This file is intentionally not one of those generated public reference pages.

## If You Plan To Change The Repo

Read in this order:

1. [README.md](README.md)
2. [ARCHITECTURE.md](ARCHITECTURE.md)
3. [CONSTITUTION.md](CONSTITUTION.md)
4. [CONFIGURATION.md](CONFIGURATION.md)
5. the workload contract relevant to your change
6. [AGENTS.md](AGENTS.md) and [INSTRUCTIONS.md](INSTRUCTIONS.md) if you are operating through the repo workflow

When a change affects public behavior:

- update the relevant root contract if the canonical behavior changed
- update the public MDX pages if the user-facing explanation or walkthrough changed
- run `just docs-sync` and `just docs-build`

That is the split this repo wants to preserve.
