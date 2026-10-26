# Deterministic implementation schedules

[Verification](../README.md) · [Contribution rules](AGENTS.md)

These drivers execute real implementation transitions with independent oracles,
saved schedules and deterministic replay. Modeled atomic storage and finite
scheduling assumptions do not establish physical disk or network guarantees.

| Owner | Entry point | Required execution |
| --- | --- | --- |
| Authority transitions and resources | [transitions](transitions/transitions.py), [Zig driver](transitions/transition_driver.zig), [corpus](transitions/corpus/) | `just test::properties` |
| Authority and delivery | [storage schedules](storage/simulation.py), [driver](storage/delivery_simulation.zig), [corpus](storage/corpus/) | `just test::simulation` |
| Page faults and resource publication | [resource schedules](resources/resource_simulation.py), [driver](resources/resource_simulation.zig), [corpus](resources/corpus/) | `just test::resource-simulation` |
| Shared Session and courier scheduling | [scheduler](scheduler/scheduler_simulation.py), [driver](scheduler/scheduler_simulation.zig), [corpus](scheduler/corpus/) | `just test::scheduler-simulation` |
| Component implementations | [domain runner](domains/domain_simulation.py) and package-owned simulation tests | `just test::domain-simulation` |

The [verification method](../../../docs/handbook/internals/verification-method.md)
explains independence and correspondence boundaries. Current seeds, trace limits,
failure classification and replay methods are in the
[scenario guide](../README.md#generated-transitions). Production guard controls
belong to the [mutation campaigns](../mutations/README.md).

[Block storage](storage/simulation_blocks.zig) and the
[modeled store](storage/simulation_store.zig) are explicit Zig module dependencies.
Their behavior is shared fixture machinery; expected outcomes stay in each
independent Python oracle. Runtime packaging does not depend on these modules.
