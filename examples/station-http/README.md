# Finite HTTP caller

This synthetic Zig application publishes a request, records a correlated call to
the HTTP connector and reads the captured response through shared Station APIs.
The caller has no HTTP transport or credential resolver. Its publication progress,
peer/correlation and received outcome survive worker replacement.

```sh
nix develop --command just examples::http
```

The local task owns a disposable disk-backed Ursula store, growing Transit node,
random keys and an independent TLS peer. The separate operator provisions two
PIDs/resources and scoped caller/connector identities; a delivery-only identity
delivers their outputs. The peer accepts one synthetic POST. The example restarts
the caller after submission, then restarts node/store and replays the response
after removing the credential and stopping the peer. It checks the binary/Unicode
response digest and exactly one network send. The temporary realm is removed at
exit; no running launcher installation is used.

`example-station-http CONFIG.json` accepts `publish`, `receive` and `replay` modes.
Configuration includes the authority URL, realm, scoped principal/seed file,
PID/fresh generation, connector PID, request/body file, publication namespace,
endpoint revision and fixed reconciliation deadline. Preserve identical request
inputs to resume publication. Repeating publication returns the saved call.
`receive` expects separately delivered input; it does not deliver its own outputs.
`replay` performs bounded current-authorized reads and reports body length/digest.
It does not print application bodies or infer business success from HTTP status.

The example inherits the shared HTTP profile's 64 KiB request and 8 KiB metadata
bounds, 256-byte publication chunks and four-mutation turns. The loop bounds cover
one finite upload, not the cardinality of durable resources. Unlimited retention
is unchanged. Host files are input/configuration, never authoritative call state.
An uncertain Transit mutation retries identical signed bytes; exhausted retries
stop the activation for explicit recovery with fresh ownership.

Local processes share the developer account; this task proves protocol credential
separation, not OS egress isolation. Compose/reference placement qualification is
still M15 work. Growing runtime actor bindings are not advertised by this example.
