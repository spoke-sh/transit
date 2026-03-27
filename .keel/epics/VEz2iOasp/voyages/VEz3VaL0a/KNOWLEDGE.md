---
created_at: 2026-03-27T00:00:03
---

# Knowledge - VEz3VaL0a

> Automated synthesis of story reflections.

## Story Knowledge

## Story: Add Tail Session Support To Rust Client (VEz8XrwHS)

### VL5mQ8pTs: Rust Tail Grant Credit Is A Poll Alias

| Field | Value |
|-------|-------|
| **Category** | architecture |
| **Context** | When exposing logical tail sessions through the Rust client. |
| **Insight** | The server protocol has no separate grant-credit operation; additional credit is supplied on `poll_tail_session(session_id, credit)`, so a Rust `grant_credit()` method should be a thin alias over poll rather than a new client-side protocol layer. |
| **Suggested Action** | Keep Rust tail APIs explicit about the underlying credit-on-poll protocol and avoid inventing extra local session machinery unless the server contract changes. |
| **Applies To** | `crates/transit-client/src/client.rs`, `crates/transit-core/src/server.rs` |
| **Applied** | yes |



---

## Story: Deliver Comprehensive Rust Client Proof Example (VEz8YBlYR)

### VN7uR5mKb: Native Client Proofs Should Boot The Server In Process

| Field | Value |
|-------|-------|
| **Category** | architecture |
| **Context** | When delivering repo-local proof programs for thin client libraries. |
| **Insight** | An in-process server bootstrap via `ServerHandle::bind` keeps the proof self-contained, avoids shell orchestration, and still exercises the exact same network boundary the client uses. |
| **Suggested Action** | Prefer in-process local server startup for native client proof examples unless the story specifically requires the external CLI lifecycle. |
| **Applies To** | `crates/transit-client/examples/proof.rs`, proof binaries/examples |
| **Applied** | yes |



---

## Story: Add Lineage Inspection To Rust Client (VEz8Y3TQE)

### VM6kT4nQe: Thin Client Tests Should Assert Both Ack And Body

| Field | Value |
|-------|-------|
| **Category** | testing |
| **Context** | When adding thin wrapper methods to `transit-client`. |
| **Insight** | Wrapper tests need to assert both the acknowledgement envelope and the returned body shape, because the client contract is to preserve server durability/topology/error semantics while also surfacing the underlying operation result unchanged. |
| **Suggested Action** | For new Rust client methods, include one success-path test that checks `ack()` fields and body contents together, plus one error-path test that checks the remote error envelope without depending on brittle message text. |
| **Applies To** | `crates/transit-client/src/client.rs` |
| **Applied** | yes |



---

## Synthesis

### 5Fmz3YimW: Rust Tail Grant Credit Is A Poll Alias

| Field | Value |
|-------|-------|
| **Category** | architecture |
| **Context** | When exposing logical tail sessions through the Rust client. |
| **Insight** | The server protocol has no separate grant-credit operation; additional credit is supplied on `poll_tail_session(session_id, credit)`, so a Rust `grant_credit()` method should be a thin alias over poll rather than a new client-side protocol layer. |
| **Suggested Action** | Keep Rust tail APIs explicit about the underlying credit-on-poll protocol and avoid inventing extra local session machinery unless the server contract changes. |
| **Applies To** | `crates/transit-client/src/client.rs`, `crates/transit-core/src/server.rs` |
| **Linked Knowledge IDs** | VL5mQ8pTs |
| **Score** | 0.82 |
| **Confidence** | 0.97 |
| **Applied** | yes |

### QShAoKNPo: Native Client Proofs Should Boot The Server In Process

| Field | Value |
|-------|-------|
| **Category** | architecture |
| **Context** | When delivering repo-local proof programs for thin client libraries. |
| **Insight** | An in-process server bootstrap via `ServerHandle::bind` keeps the proof self-contained, avoids shell orchestration, and still exercises the exact same network boundary the client uses. |
| **Suggested Action** | Prefer in-process local server startup for native client proof examples unless the story specifically requires the external CLI lifecycle. |
| **Applies To** | `crates/transit-client/examples/proof.rs`, proof binaries/examples |
| **Linked Knowledge IDs** | VN7uR5mKb |
| **Score** | 0.80 |
| **Confidence** | 0.96 |
| **Applied** | yes |

### roDFnsAv0: Thin Client Tests Should Assert Both Ack And Body

| Field | Value |
|-------|-------|
| **Category** | testing |
| **Context** | When adding thin wrapper methods to `transit-client`. |
| **Insight** | Wrapper tests need to assert both the acknowledgement envelope and the returned body shape, because the client contract is to preserve server durability/topology/error semantics while also surfacing the underlying operation result unchanged. |
| **Suggested Action** | For new Rust client methods, include one success-path test that checks `ack()` fields and body contents together, plus one error-path test that checks the remote error envelope without depending on brittle message text. |
| **Applies To** | `crates/transit-client/src/client.rs` |
| **Linked Knowledge IDs** | VM6kT4nQe |
| **Score** | 0.76 |
| **Confidence** | 0.94 |
| **Applied** | yes |

