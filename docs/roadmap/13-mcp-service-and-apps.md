# 13. MCP service and interactive Apps

[Roadmap](README.md) · **Status:** Planned

Expose selected published resources, computations and application operations to
agent hosts through MCP. Deliver useful structured/text results and optional
interactive views over the same evidence and access contracts as other callers.
MCP is a protocol adapter; it owns no independent catalog, permission authority,
query semantics or durable workflow engine.

## Prerequisites and scope

Consume the [access plane](10-control-and-policy-plane.md),
[published resources and results](11-published-resources-and-investigations.md)
and [reviewed collaboration](12-reviewed-data-collaboration.md) for each exposed
operation. A read-only protocol spike can precede collaboration implementation;
it does not qualify branch or approval capabilities. Shared adapter parity follows
[service and SDK coverage](09-service-and-sdk-coverage.md).

## Delivery sequence

1. **Select and qualify the protocol implementation.** Evaluate
   [mcp.zig](https://github.com/muhammad-fiaz/mcp.zig) as a candidate, not an
   adopted dependency. Pin the reviewed revision and transitive dependencies;
   compile with Transit's exact Zig toolchain and clean offline Nix builds.
   Assess request-scoped identity, concurrent isolation, actual HTTP streaming,
   cancellation, quotas, origin policy, authentication integration and task
   storage. Reuse qualified transport/lifecycle owners where appropriate.
   In-memory library task state cannot own durable Transit work.
2. **Define an exact host/protocol/extension matrix.** Test independent hosts
   against selected upstream revisions; do not mix older session/subscription
   methods with newer per-request protocols. Upstream MCP revisions are distinct
   from Transit's current-v1 definitions. Advertise only implemented capabilities
   and reject incompatible peers before work. Keep the library replaceable behind
   a small adapter over shared contracts.
3. **Install authenticated Streamable HTTP ingress.** Integrate TLS, exact
   Host/Origin policy, trusted identity bindings, audience validation and bounded
   request/response/concurrency work. Configure the endpoint through
   `transit server`; the public CLI remains `server` and `console`. Consider a
   separately packaged stdio bridge only for demonstrated host needs. Never
   expose Board's shared inspection credential as a per-user capability.
4. **Project deliberately published capabilities.** Generate resource, tool and
   optional prompt descriptors from shared definitions. Support bounded discovery,
   description, query and result inspection before selected application actions.
   No automatic tool/resource per Table, KV, Document or binding; no unrestricted
   arbitrary-URL tool. Admit read-only queries through semantic validation.
   Resource URIs and cursors confer no access. Ordinary queries return results
   or meaningful failures without requiring users to manage recovery workflows.
5. **Preserve evidence and operation semantics.** Return bounded summaries,
   lossless structured results and authorized continuation/resource references.
   Share the result contract, source basis, completeness and diagnostics. Preserve
   original intent across retries and multi-round input/approval; a fresh JSON-RPC
   ID cannot duplicate a business operation. Cancellation does not promise rollback.
   Keep large transfers on qualified data interfaces, including Flight where its
   supported profile applies.
6. **Render optional MCP Apps.** Generate selected `ui://` resources and tool UI
   metadata from shared presentation bindings. Use strict TypeScript/Vite+ and
   runtime-validated shared types; reuse suitable Board components without its
   privileged context. Bind selection, drilldown and review to exact result and
   candidate revisions. Reauthorize every call, constrain asset/network origins
   and keep credentials out of UI bundles. Text/structured fallback retains
   critical evidence and errors when the host has no Apps support.

## Completion evidence

Run one published business resource through at least two selected independent
hosts, with exact versions recorded, and an Apps-capable host plus a non-UI path.
Compare results to SDK/native callers. Exercise wrong audience, concurrent users,
revocation between pages, slow readers, truncated responses, host reconnect,
lost mutation replies, repeated approvals and source changes during interaction.
Verify visible and model-supplied selections refer to the same result revision.

Include malicious instructions in source content and tool metadata: they cannot
select stronger credentials, broaden scope or authorize another destination.
Capability annotations and model confidence are not security decisions. Host
context inclusion and extension support require actual evidence, not inference
from a successful MCP connection. Packaging must pass committed-source clean checks.

## Primary references

- [MCP versioning](https://modelcontextprotocol.io/specification/2026-07-28/basic/versioning), [tools](https://modelcontextprotocol.io/specification/2026-07-28/server/tools) and [resources](https://modelcontextprotocol.io/specification/2026-07-28/server/resources).
- [MCP Apps](https://modelcontextprotocol.io/extensions/apps/overview) and [security guidance](https://modelcontextprotocol.io/docs/2026-07-28/tutorials/security/security_best_practices).

These references inform the design; the tested support matrix owns shipped claims.
