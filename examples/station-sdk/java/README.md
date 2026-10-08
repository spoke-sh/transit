# Java public SDK examples

`Messages`, `Codecs` and `Handlers` implement the shared
[version-1 counter and query formats](../README.md), using Java records, sealed
messages, typed handlers and full u64 `BigInteger` values. `Counter` and `Requester`
save totals/correlations/results in associated state; replacing either object
does not lose durable waiting state. `TableService` implements the
[durable FIFO contract](../TABLES.md): four typed columns with text/list defaults,
explicit creation quotas, queued insert/update/delete, and one native step per
recorded self continuation. Global admission positions remain the original DML
identities. Completion and queue bookkeeping keep the four-write budget;
pending queries receive an authenticated NotReady reply and can be explicitly
started later. `QueryRequester` validates provenance and streams
owned IPC segments to its application callback.

Build from the bindings shell with `just bindings::java-build`. Install
`transit-sdk-examples-0.2.0.jar` plus the JAR dependencies in the
[SDK guide](../../../packages/java/transit-station-sdk/docs/USAGE.md) into `lib/`.
Run the actual installed CLI roles:

```sh
java -cp 'lib/*' io.transit.examples.CounterMain config.json service --commits 1
java -cp 'lib/*' io.transit.examples.CounterMain config.json requester --commits 1
```

Each role needs its own configuration object with `url`, `profile: "native_v1"`,
`realm`, `principal`, `pid`, `generation`, `seed_file` and `peer`. Its provisioned
process must already own the recorded `data` association with current grants.
Provisioning and outbox delivery belong to the deployment. Keep private seed
paths/files and recovery bytes outside Git. Loading an example JAR starts no work.

The CLI explicitly selects `Recovery.FreshOwnership`; a deployment must fence and
reconcile a fresh activation after host loss. It stops on uncertainty and never
re-signs a lost request. Applications needing exact host-loss retry should use
`Recovery.PersistBeforeDispatch` as described in the SDK guide. Handler code contains
no generic native JSON actions, manual polling, framework hex or sibling imports.
Only the CLI configuration and output use JSON. Codec byte manipulation implements
the application format, not Transit protocol semantics.

`just bindings::java-sdk-test` builds these JARs, compiles an external consumer and
runs both CLI roles. The shared schedule covers full-width codec fixtures,
recovery hooks, scoped access, retained Tables and complete query IPC decoded
independently with PyArrow. Callback consumption is ordinary application code;
effects must have their own replay/idempotency policy. No Java Arrow adapter is
selected, and arbitrary suspended Java stacks are not durable continuations.
