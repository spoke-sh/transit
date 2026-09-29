# What is Transit?

Transit is a runtime for applications that need durable messages, state and
recoverable work. An application runs in its own worker and proposes changes;
Transit validates and records which changes commit. A worker can restart without
turning accepted work into a new request.

Use Transit when the identity and recovery of work matter beyond the lifetime of
a process or network connection. It is experimental: the implemented profiles
have explicit limits and tested configurations, rather than a general production
compatibility promise. Start on the qualified Linux x86_64 local profile.

## The pieces you use

| Component | What you use it for |
| --- | --- |
| Transit | Durable process identities, ordered mailboxes, state resources, authorization and commit decisions |
| Station | Application behaviors, durable calls, typed Tables, Documents and supervision above Transit |
| Fuze | Finite queries over declared KV, Table and Document sources, with Arrow results |
| Connectors | Recorded HTTP and gRPC exchanges with explicit retry and unknown-outcome handling |
| Board | Inspect authorized system evidence and use separately configured query/application workspaces |
| `transit` CLI | Start a local server, install a separately compiled application and query through the console |

Application code decides what a message means. Transit does not run application
handlers inside the node or prove their computation correct. Storage and runtime
providers supply persistence and physical placement; durable Transit history
remains execution authority.

## Start with a working path

1. [Run Transit locally](quickstart.md) and query its initial empty Table.
2. [Build an application](applications.md) separately and install its workers.
3. [Choose an interface](choose-interface.md) for your application's clients.
4. Learn [processes and turns](../reference/processes.md), [state](../reference/state.md) and
   [permissions](../reference/security.md) before adding writes or external effects.

## Three distinctions to keep

**Accepted is not completed.** A receipt records admission. Observe a committed
application outcome or a complete query result before claiming success.

**A timeout is not a rejection.** Keep the original operation identity and frozen
request. Reconcile or retry that exact request after uncertainty; a new identity
means new work. Disconnecting does not cancel durable work.

**An identity is not a permission.** Knowing a PID, resource, cursor or ticket
never grants access. Current scoped authorization is checked independently from
worker ownership, including on reads and replay.

Retention is unlimited unless an application explicitly opts into a finite
policy. Memory pressure, disk pressure and restarts do not authorize deletion.
See the [scope](../reference/architecture.md), [interface matrix](choose-interface.md) and
[verification limits](../reference/verification.md) before choosing a profile.
