# TypeScript public SDK examples

This installable package contains `Counter`, `Requester`, `TableService` and
`QueryRequester`, plus the shared version-one counter, u64 and query codecs.
All full-width values use `bigint`. The codec specification and cross-language
fixtures live in the parent example guide.

Build with `nix develop --command just bindings::node-build`. Install the generated
tarballs with their matching `@transit/client`, `@transit/station` and native
dependencies. For local unpublished artifacts, use ordinary package-manager
overrides as described in the client package guide.

Run `transit-node-counter CONFIG service --commits 1` or replace `service` with
`requester`. CONFIG supplies `url`, `profile: "native_v1"`, `realm`, `pid`,
`principal`, `generation`, `seed_file` and the other role's `peer` PID. Provision
the activation, grants and `data` association first. The CLI explicitly requires
fresh ownership after host loss. Applications that need exact retry across a
crash provide the public runner's persistence hooks instead.

Requester correlation is stored with its wait and outgoing call, then checked
against authenticated reply provenance in a later turn. Handler object fields
hold configuration only. The query example reads the verified manifest and
streams bounded original IPC segments; it does not retain an entire result.
