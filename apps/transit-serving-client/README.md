# Serving caller host

`transit-serving-client` runs one bounded request through the shared Zig
`transit_serving.Caller`. It prepares and inspects frozen Serving commands,
dispatches an original command once, observes Serving state and signs an
application-owned read context. It retains no journal, sequence allocator,
credentials or background work between invocations.

Build with `nix build .#transit-serving-client`. The installed binary retains its
Nix closure. It requires no source checkout, Zig compiler or ambient PATH lookup.
Linux amd64 is the executed consumer profile; evaluation elsewhere is not proof.
The [Go adapter](../../sdks/go/serving/README.md) invokes the same installed host.

The process accepts one newline-terminated JSON `Caller.Request` on stdin and
writes one `Caller.Result` on stdout. Those exported Zig types own the process
contract. The native definition must match exactly. Input is at most 64 KiB;
HTTP output is at most 1 MiB. A request arena owns decoded values until exit.
Malformed input exits unsuccessfully before dispatch. Finite native error names
do not include credentials, request bodies or server text.

Configuration requires an exact HTTPS origin, positive bounded native identities,
an absolute external seed-file path and a 1–60000 ms request timeout. Optional
`ca_file` selects an absolute PEM trust file; host/certificate verification remains
enabled. Loopback HTTP requires `development_allow_insecure_http = true` and
cannot also specify a CA. Redirects are refused by the shared transport.

`prepare` returns canonical recovery bytes containing the exact signed native
command and its origin/service. Persist them durably before `dispatch`. `inspect`
validates canonical bytes and the original definition, realm, principal, ingress,
role and service; it does not read a signing seed. It is classification, not proof
of native acceptance or current permission. The authority verifies the original
signature when the exact command is dispatched. Credential changes cannot
authorize replacement of uncertain work.

`observe` uses the shared Serving subject proof. `application_read` takes the
application-owned context digest/body and a relative same-origin path. The
application owns that body's meaning and response validation; the host owns the
native proof and bounded transport. No caller can infer business completion from
HTTP 202. Any lost or malformed command response leaves the outcome unknown.
