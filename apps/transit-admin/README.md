# transit-admin

Small signed Transit operator client built on
[transit-client](../../packages/zig/transit-client/README.md). It derives public
keys, signs/submits commands and issues native queries under current grants.
It has no storage or provider access.

From the repository root in `nix develop`, run `just build::debug apps`, then:

```sh
zig-out/bin/transit-admin public-key PRIVATE_SEED_FILE
zig-out/bin/transit-admin sign PRIVATE_SEED_FILE REQUEST.json
zig-out/bin/transit-admin submit PRIVATE_SEED_FILE REQUEST.json http://127.0.0.1:8080
zig-out/bin/transit-admin sign-query PRIVATE_SEED_FILE QUERY.json
zig-out/bin/transit-admin query PRIVATE_SEED_FILE QUERY.json http://127.0.0.1:8080
```

Seed files contain 32 bytes encoded as hexadecimal and require owner-only
permissions. Save the mutation request before submitting. A lost response requires
the same signed request and sequence until its outcome is resolved.

`REQUEST.json` contains native v1 `realm`, `principal`, mutation `sequence` and
`command`. `QUERY.json` contains `realm`, `principal` and `kind`. The shared client
supplies the current version and definition, canonical bytes and signatures.
For example, `{"realm":72,"principal":1,"kind":{"process":9}}` reads a process.
`{"realm":72,"principal":1,"kind":{"inspection":{"resource":"processes"}}}`
starts bounded discovery. State, delivery and capability reads use the same query
command with their respective native variants; there are no separate legacy routes.

See the [native contract](../../contracts/TRANSIT_V1.md) and
[service contract](../../contracts/SERVICE_V1.md) for fields, limits and errors.
[main.zig](main.zig) owns argument parsing and secret-file handling;
`just test::service` exercises the actual binary through signed HTTP ingress.

Diagnostics use [bounded telemetry](../../packages/zig/telemetry/README.md) on
stderr. Machine results remain on stdout. Logs exclude seeds, signed requests,
payloads and URLs. An uncertain submission still requires exact reconciliation.
