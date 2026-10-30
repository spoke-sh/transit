# Storage and durable recovery checks

This owner covers accepted data, WAL/object state, bounded residency, retention
and recovery. Read the [storage reference](../../docs/handbook/reference/storage.md),
[storage runtime](../../docs/handbook/internals/storage-runtime.md) and
[contribution instructions](AGENTS.md).

| Boundary | Drivers |
| --- | --- |
| Local objects, WAL and accepted Table maintenance process-death recovery | [Objects](local/local_objects.py), [storage faults](local/local_storage_faults.py), [collection faults](local/local_native_collection_faults.py) |
| Local native collection and maintenance | [local/](local/), [growth](local/storage_growth.py) |
| Automatic native/direct collection scheduling, restart, revocation and idle convergence | [Node collection schedule](../../apps/transit-node/local_collection_test.zig); `just test::local-catalog` |
| Local owner replacement and atomic state/block/version/intent recovery | [Recovery schedule](local/local_owner_recovery.py), [real-node fault wrapper](local/local_owner_fault_node.zig); `just test local-owner-recovery` |
| Authenticated standalone payload lifecycle | [Local payload service](local/local_payload_service.py); `just test local-payload-service` |
| Direct Table graph collection, expiry and retained pins | [Disk collection](local/direct_collection.zig), [collection process faults](local/local_native_collection_faults.py) |
| Direct Table service, slow body/response pressure, reserved original-outcome recovery and restart | [Direct Table schedule](tables/direct_table_service.py) |
| Automatic Table/Stream maintenance, retained reads, admission pressure and restart | [Method and resource observations](tables/maintenance.md), [schedule](tables/direct_table_maintenance.py), [Table caller](tables/direct_table_maintenance.zig), [Stream caller](../interfaces/native/direct_table_client.zig); `just test direct-table-maintenance` |
| Queue FIFO claims, uncertain replies, automatic retired-lease expiry and original payloads after restart | [Signed caller](tables/direct_queue.zig), [HTTP schedule](tables/direct_table_service.py); `just test direct-table-service queues` (also included in the default direct-service gate) |
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

The local-owner recovery schedule publishes each fault selection atomically and
requires its exact counter before treating a request as faulted. Fault delivery
and receipt recovery share the existing 15-second original-outcome budget;
earlier transport timeouts repeat the same saved signed request. The node keeps
its two-second request deadline. An unobserved fault or an unresolved original
outcome fails the schedule and retains the private installation.

The direct Table service schedule measures backing bytes for a retained scan
whose values the public caller verifies independently. Its response-pressure
arm repeats that same immutable read on one bounded keep-alive connection with
a small client receive window. A blocked response remains charged while partial
bodies exhaust the configured aggregate allowance. Both disconnect and request
deadline schedules require all backing bytes to return to zero; signed control
inspection must still recover the original accepted operation during pressure.
The numeric record includes request limits, retained response bytes and whole-node
CPU, RSS and I/O observations. It does not treat socket buffers or the OS page
cache as part of the request allocator, or measure these schedules as latency
benchmarks.

`just test::local-data-collection` exercises explicit Table history expiry,
snapshot retention, original receipts and admitted work through physical
collection and disk reopen. It also runs the direct profile of the shared
collection fault harness: actual SIGKILL at each observed sync, file removal,
progress publication and reply boundary. The same checks are included by the
native components/faults aggregate. Run `just test::local-native-collection` for
the native page/block profile. These component checks do not establish automatic
installed maintenance or physical power-loss behavior.
