# Release Process

`transit` is intended to ship as both an embedded library surface and a server binary. The release process should reflect that dual role without splitting the core storage model.

## Current State

This repository is in the bootstrap stage.

What exists today:

- project thesis
- architecture and operating rules
- configuration, guide, evaluation, and agent documents
- bootstrapped Rust workspace with `transit-core` and `transit-cli`
- Nix flake, Rust toolchain file, `cargo nextest`, and `just mission`
- initial `object_store` filesystem probe wiring
- initial shared-engine server daemon bootstrap with provisional remote append/read/tail/branch/merge/lineage-inspection operations but no stable wire protocol yet

What does not exist yet:

- production stream engine
- stable on-disk format
- stable wire protocol
- finalized packaging workflow

That means early tags should be treated as design and prototype milestones, not as compatibility guarantees.

## Versioning Policy

Before `1.0`:

- breaking changes are allowed
- storage and protocol changes should still be documented clearly
- migration notes are required whenever an existing prototype format changes

At `1.0` the following should be stable:

- core stream and branch semantics
- on-disk segment and manifest format
- baseline wire protocol expectations
- documented durability modes

## Planned Release Artifacts

The intended release artifacts are:

- Rust crates for the embedded/core surfaces
- a `transitd` server binary
- a container image for server deployments
- checksums, integrity metadata, and release notes

Additional language bindings can be added later, but the Rust release remains the reference surface.

## Release Checklist

### 1. Update Version And Notes

- bump crate or package versions
- update release notes with architecture, API, storage-format, and operator-impact changes
- document any migration steps

### 2. Re-run Core Validation

At minimum, a code release should include evidence for:

- append and read correctness
- branch creation and ancestry replay correctness
- crash recovery behavior
- tiered-storage round-trip or cold-restore behavior
- segment, manifest, and checkpoint integrity behavior for the changed scope
- benchmark results for the changed scope

### 3. Review Compatibility Surface

For each release, call out whether these changed:

- record format
- segment format
- manifest format
- integrity proof format or digest algorithm
- network API
- configuration keys

### 4. Commit, Tag, And Publish

Use one logical release commit, then tag it with the matching version.

Example tag forms:

- `v0.0.1` for doc or prototype milestones
- `v0.1.0` for the first usable developer preview
- `v0.x.y` for pre-1.0 iteration

### 5. Publish Artifacts

Once packaging exists, publish:

- binary artifacts
- crate releases
- container image
- checksums
- any manifest-root or checkpoint-format notes needed for verification tooling
- release notes

## Minimum Evidence For A Public Code Release

Do not publish a public code release without:

- explicit durability mode coverage
- storage-backend context
- benchmark metadata
- correctness tests for branch and recovery behavior
- notes about checksum, digest, and checkpoint compatibility when relevant
- notes about any unstable or experimental surfaces

## Platform Expectations

Initial expected support:

- Linux x86_64 as the first-class server target
- Linux ARM64 as an important follow-on server target
- macOS arm64 for local development and embedded testing

Windows support is possible later, but it should not delay core storage and server progress.

## Packaging To Finalize

These decisions are intentionally still open:

- final release automation tooling
- artifact signing requirements
- container base image policy
- whether signed checkpoints ship before or after the first public server preview
- whether the first public packaging surface is library-first, server-first, or both

When those are decided, this document should be updated before the release process is treated as stable.
