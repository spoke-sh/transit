# Explicit growing ownership bootstrap

M15's finite HTTP reference example needs a fresh key inside a physically placed
caller. `bootstrap.awaitGrowingOwnership` is an opt-in helper for that operator
workflow. It does not add a provider binding, controller, supervisor or new kernel
operation. The v2 `awaitActivation` and qualified M8 runtime contract are unchanged.

The host generates a fresh in-memory key, fixes the expected next generation
before launch and emits exactly one JSON line:

```json
{"growing_bootstrap":{"version":1,"realm":42,"pid":9,"principal":65536,"generation":5,"public_key":[0]}}
```

The illustration abbreviates the key: a real registration has exactly 32 integer
bytes. All identities are unsigned protocol integers, not floating-point values.
The distinct `growing_bootstrap` envelope cannot be mistaken for the v2 controller's
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
adopted after success: the ordinary growing session remains pinned to that
generation. Authentication denials, authority timeouts/unavailability and an HTTP
connection closing during this read can be polled within the explicit finite
bootstrap timeout (maximum 300 seconds); other errors stop the host. Every retry
reads the same pinned identity and generation and never submits a mutation.
Expected denied polls emit no repeated diagnostics. Neither key material nor an
authoritative activation is written to the filesystem or provider snapshot.

This operator placement profile does not advertise growing runtime bindings or
automatic provider reconciliation. M15 reference execution and physical attribution
are being qualified separately; the helper's unit checks alone do not prove them.
