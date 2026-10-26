# Deterministic implementation schedules

[Verification](../README.md) · [Contribution rules](AGENTS.md)

These drivers execute real implementation transitions with independent oracles,
saved schedules and deterministic replay. Modeled atomic storage and finite
scheduling assumptions do not establish physical disk or network guarantees.

| Owner | Entry point | Required execution |
| --- | --- | --- |
| Authority transitions and resources | [Method and bounds](transitions/README.md), [Zig driver](transitions/transition_driver.zig), [corpus](transitions/corpus/) | `just test::properties` |
| Authority and delivery | [Method and bounds](storage/README.md), [driver](storage/delivery_simulation.zig), [corpus](storage/corpus/) | `just test::simulation` |
| Page faults and resource publication | [Method and bounds](resources/README.md), [driver](resources/resource_simulation.zig), [corpus](resources/corpus/) | `just test::resource-simulation` |
| Shared Session and courier scheduling | [Method and bounds](scheduler/README.md), [driver](scheduler/scheduler_simulation.zig), [corpus](scheduler/corpus/) | `just test::scheduler-simulation` |
| Component implementations | [Method and bounds](domains/README.md), [domain runner](domains/domain_simulation.py) and package-owned simulation tests | `just test::domain-simulation` |

The [verification method](../../../docs/handbook/internals/verification-method.md)
explains independence and correspondence boundaries. Each scenario guide owns its
seeds, trace limits, failure classification and replay methods. Production guard controls
belong to the [mutation campaigns](../mutations/README.md).

[Block storage](storage/simulation_blocks.zig) and the
[modeled store](storage/simulation_store.zig) are explicit Zig module dependencies.
Their behavior is shared fixture machinery; expected outcomes stay in each
independent Python oracle. Runtime packaging does not depend on these modules.
