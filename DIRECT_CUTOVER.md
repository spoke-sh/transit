# Direct Cutover Proof Path

This document defines the canonical upstream proof path for downstream repos
that want to delete duplicate local Transit runtime ownership or private hosted
client semantics.

The policy is a hard cutover:

- move hosted authority to `transit-server`
- move Rust consumer imports to `transit-client`
- delete duplicate local runtime or repo-local hosted client ownership
- do not preserve dual-write or transitionary hosted-interface debt

## Minimum Proof Set

### 1. Hosted Authority Proof

Run the hosted authority proof from the Transit repo:

```bash
cargo run -p transit-cli --bin transit -- proof hosted-authority --root target/transit-cutover/hosted --json
```

This proof exercises the server boundary as the consumer authority for append
and replay.

The downstream repo should be able to cite these receipt fields literally:

- `"remote_api": "TransitClient"`
- `"consumer_boundary": "external producers and readers use TransitClient over the server boundary; they do not open LocalEngine as their own authority"`
- `"embedded_authority_used": false`
- `"replay_matches_acknowledged_history": true`
- `"authority_surface": "transit-server remote append/read contract"`

Those fields are the direct proof that hosted producers and readers are using
the upstream client over the hosted boundary rather than opening embedded local
Transit storage as a second authority.

### 2. Rust Client Proof

Run the upstream Rust client proof:

```bash
cargo run -p transit-client --example proof
```

This proof exercises the published `transit-client` surface through:

- `create_root`
- `append`
- `read`
- `tail_open`
- `tail_grant_credit`
- `tail_poll`
- `tail_cancel`
- `create_branch`
- `create_merge`
- `lineage`

The expected receipt is `status: VERIFIED`.

That is the direct proof that downstream Rust consumers can use the upstream
client surface without rebuilding a private hosted client vocabulary.

## What A Clean Cutover Means

After a downstream repo cites this proof path, its replacement posture should
be clear:

- hosted producer and reader paths talk to `transit-server`
- the downstream repo imports hosted Rust client vocabulary from
  `transit-client`
- embedded local Transit storage is not treated as the authority for the same
  hosted workload lane
- repo-local hosted client wrappers or duplicate runtime surfaces are deleted,
  not preserved behind compatibility layers

## Delete After Cutover

Once the upstream proof path is adopted, downstream repos should remove:

- repo-local hosted client wrappers that duplicate `transit-client`
- embedded-runtime entry points that are still presented as the authority for
  the same hosted workload lane
- dual-write or compatibility adapters that keep both the old downstream lane
  and the upstream Transit lane alive at the same time

## Explicit Non-Claims

This cutover proof path is deliberately narrow.

It does not by itself prove:

- token or mTLS wire enforcement
- tiered durability for hosted acknowledgements
- warm-cache recovery from remote-tier publication
- consumer-owned schema or policy correctness

Those require separate upstream proof surfaces.

In particular, the hosted authority proof keeps this non-claim explicit:

- tiered durability is not claimed there because the proof does not publish the
  acknowledged history to the remote tier

## Related Upstream Contracts

- [`HOSTED_CONSUMERS.md`](HOSTED_CONSUMERS.md)
- [`crates/transit-client/README.md`](crates/transit-client/README.md)
