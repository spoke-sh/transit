# Station exchange capture v1

Status: M15 implementation contract; connector qualification is still in progress.
This is a framework layout over growing KV and [publication v1](STATION_PUBLICATION_V1.md),
not a new kernel effect or a permission carried by a reference.

## Ownership and identity

An exchange is `(resource:u64, id:u64)`, with a nonzero application-assigned ID.
It owns that publication namespace exclusively. A fenced exchange writer owns
the resource; the caller PID/input and optional parent exchange are immutable
lineage. The executor has its own current dispatch/observation grants. A caller
must have an explicit resource grant to read the capture. Associations and
references do not grant access. Resource admission must cover the promised
caller/replay lifetime; the first profile uses independent, unlimited capture
resources, with explicit release after dependents no longer need them.

One exchange records one kernel effect/attempt. Redirects, explicit retries and
reconciliation requests create new exchanges with parent lineage and new effects.
The executor binds a real dispatch receipt before capture of remote observations.
Recovery cannot use that binding as permission to send again. Dispatch and
observation remain the existing kernel operations. Only the authenticated effect
origin can resolve a waiting caller; capture alone does not resolve an effect.

## Bounded capture and completion

The immutable descriptor records caller/input, protocol format, lineage, finite
capture budgets, a finite reconciliation deadline, attempt/executor, segment
count, byte count and a coverage commitment. States are preparing, capturing,
complete, unknown and retired. Completion and unknown are terminal for capture;
retirement closes reads before member reclamation. No transition resets budgets
or reuses an ID. Captured prefixes do not imply a complete response.

Each segment has a nonzero adapter-defined kind, canonical Publication content,
and a monotonically increasing ordinal. At most one segment is staged at a time.
Its publication ID is ordinal + 1. The adapter bounds the buffer used to determine
length/digest before beginning a segment; loss before that commit remains a gap.
A begin reserves publication capacity and records the pending kind together.
A seal publishes the immutable bytes, writes one member and advances coverage in
one turn: two Publication mutations plus member and exchange descriptor, exactly
four mutations. No operation loads all members or bodies into memory.

Coverage is SHA-256 over a domain-separated chain of ordinal, kind, length and
Publication digest. The final descriptor fixes the segment count, bytes and
coverage chain, plus adapter terminal code. The adapter is responsible for proving
its protocol reached a terminal state and that the kinds/order cover the request
and response. The common library proves only the declared immutable coverage.
Empty bodies are explicit adapter records; no missing data is inferred empty.

Finishing capture and submitting the kernel observation are separate decisions.
If observation loses to closure, the sealed capture remains orphaned evidence;
it cannot be delivered as a successful outcome. Exact signed observation retry
recovers the original decision. A reference accepted by the kernel points to
already sealed capture. Cleanup first retires current exchange availability and
requires the owning application to discharge replay dependencies.

## Reads and cleanup

Reads resolve current availability before reading a captured source. A retained
old root must not turn a retired exchange into an available one. The caller
provides a fresh current-authority reader for every bounded read; the native
cursor is trusted local state, not a bearer token. Each member verifies its
Publication digest; only the last verified member and final coverage commitment
establish complete replay. Unknown capture is inspectable as partial evidence,
but complete replay rejects it. Replay APIs have no transport or secret resolver.

Retirement preserves the final descriptor. Cleanup visits one publication at a
time and deletes at most two chunks per turn, preserving descriptors and terminal
IDs. A staging record is abandoned before cleanup. Historical protected roots
remain subject to resource rights and their own release; this is logical cleanup,
not physical erasure. Unlimited retention is the default; neither capacity nor
worker restart authorizes retirement.

## Encoding and proof boundary

All integers in values are little endian; keys use big endian identity/ordinal.
Values have magic/version prefixes, reject unknown tags, trailing bytes and
inconsistent counters. Public Zig types own the exact codecs and shared fixtures;
host APIs must reuse those codecs. Resource values remain at most 256 bytes and
turns at most four mutations. Configured per-exchange limits bound live work,
while resource quotas bound durable history independently of resident memory.

M15 must qualify these contracts with HTTP and disk recovery before completion;
M16 must reuse the same corpus for its binary and directional records. This
contract alone is not evidence of network isolation, complete HTTP/gRPC capture,
SDK compatibility or remote exactly-once execution.
