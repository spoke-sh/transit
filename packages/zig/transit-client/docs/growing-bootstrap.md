# Operator ownership bootstrap

`bootstrap.awaitGrowingOwnership` supports explicit operator placement with a
fixed expected generation and fresh ephemeral key. Provider-bound workers use
`bootstrap.awaitActivation` and the runtime controller's binding evidence. Both
helpers use the same native v1 authority and cannot grant themselves ownership.

The host generates a fresh in-memory key, fixes the expected next generation
before launch and emits exactly one JSON line:

```json
{"growing_bootstrap":{"version":1,"realm":42,"pid":9,"principal":65536,"generation":5,"public_key":[0]}}
```

The illustration abbreviates the key: a real registration has exactly 32 integer
bytes. All identities are unsigned protocol integers, not floating-point values.
The distinct `growing_bootstrap` envelope cannot be mistaken for the runtime controller's
provider registration. The helper checks the public key matches its signing key.

An independently trusted operator must attribute the line to the selected current
physical worker/container, check all identities against its launch request, then
use signed public commands to grant the fresh key, reissue the required resource
grants and record ownership at the expected prior generation. Registration itself
is public data and grants nothing. A copied registration, provider state, stored
name or checkpoint cannot authorize execution.

The helper only reads the current authorized process. A lower generation waits;
exact expected ownership succeeds; a later generation or different owner fails.
Permanent retirement and a blocked process fail explicitly. No activation is
adopted after success: the ordinary session remains pinned to that
generation. Authentication denials, authority timeouts/unavailability and an HTTP
connection closing during this read can be polled within the explicit finite
bootstrap timeout (maximum 300 seconds); other errors stop the host. Every retry
reads the same pinned identity and generation and never submits a mutation.
Expected denied polls emit no repeated diagnostics. Neither key material nor an
authoritative activation is written to the filesystem or provider snapshot.

The operator must authenticate physical placement independently. Unit checks of
registration parsing and polling do not prove that attribution; actual placement
and recovery schedules are recorded in the [proof ledger](../../../../tests/README.md).
