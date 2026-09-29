# HTTP serving profile v1

Status: qualified M19 neutral listener profile, used by Board and application
serving. The [proof ledger](../tests/README.md#m19-qualification) records separate
application admission, TLS and deployment evidence. [Serving](../docs/reference/serving.md) owns the architecture.

The listener accepts bounded HTTP/1.1 origin-form requests, requires exactly one
valid Host and uses one request per connection. Consumers check their exact
configured Host/Origin, trusted termination boundary, method, media type and
authenticated scope. No forwarded identity is trusted implicitly.

Headers fit 8 KiB; targets fit 1024 bytes; Host fits 200 bytes. Duplicate Host,
Content-Length, Transfer-Encoding, Origin, Authorization, Content-Type or Upgrade
reject. Content-Length together with Transfer-Encoding rejects. Chunked request
bodies are allowed under the consumer's decoded-body limit; other transfer
encodings, compressed request content and Expect are unsupported. Parsing a
header or writing a response never establishes durable operation acceptance.
The profile follows [RFC 9112](https://www.rfc-editor.org/rfc/rfc9112.html);
it selects stricter rejection rather than repairing ambiguous framing.

Options bound accepted sockets (2–64), concurrent data work, separate health
work, header time and total request time (at most 300 seconds). Header parsing
uses a finite deadline before data admission. Data exhaustion returns an explicit
503 when response capacity exists; socket/task exhaustion closes the transport.
Neither refusal can erase work accepted by a preceding attempt. Accepted sockets
have no resident pending queue beyond the configured pool. Each connection closes
or is transferred to a separately qualified upgraded protocol before reuse.

Timer and handler tasks are joined before socket/buffer reuse, including parent
cancellation and scheduling failure. Handlers must be bounded and cooperative;
the deadline is not a preemptive sandbox for arbitrary computation. A long response
uses one data slot and cannot borrow the reserved health slots. Header-flood
capacity and application per-principal fairness need separate measured proofs.

TLS, application service bindings, caller provenance, command/reply records,
stable operation identity and current read policy remain with M19's serving
consumer. The [serving example's local nginx termination](../examples/serving/docs/termination.md)
passes its real signed-call/recovery proof; remote TLS placement remains separate. SSE and
WebSocket are M20 extensions and remain unavailable until their own proofs.
