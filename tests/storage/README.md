# Storage and durable recovery checks

This owner covers accepted data, WAL/object state, bounded residency, retention
and recovery. Read the [storage reference](../../docs/handbook/reference/storage.md),
[storage runtime](../../docs/handbook/internals/storage-runtime.md) and
[contribution instructions](AGENTS.md).

| Boundary | Drivers |
| --- | --- |
| Local objects and WAL process-death recovery | [Objects](local/local_objects.py), [storage faults](local/local_storage_faults.py), [collection faults](local/local_native_collection_faults.py) |
| Local native collection and maintenance | [local/](local/), [growth](local/storage_growth.py) |
| Direct Table service and restart behavior | [Direct Table schedule](tables/direct_table_service.py) |
| Physical codecs and independent bytes | [Codec fixtures](codecs/column_codecs.py) |
| Ursula/provider-specific conformance | [Provider storage](providers/storage.py), [pages](providers/pages.py), [blocks](providers/block_storage.py), [authority growth](providers/growing.py), [cold-store fixture](providers/cold_storage.py) |
| Expiry, deletion, capacity and maintenance | [retention/](retention/), [real ENOSPC](retention/capacity.py) |

Use [test recipes](../../tasks/test.just) for explicit binary and provider inputs.
Repository Python drivers use the shared test launcher. Local WAL/Table and
Ursula schedules preserve separate guarantees; a filename or common helper does
not establish the backend. Performance drivers and budgets live in
[performance](../performance/README.md), and application actor execution in runtime.

Physical disk, process death, injected failure and modeled power loss are
distinct evidence. Automatic runner records identify completed commands; archived
results do not qualify current source.
