# transit-test

Bounded application assertions over the ordinary SQL session owner. The pure
[compiler](https://github.com/spoke-sh/transitc/blob/main/packages/transitc-compiler/README.md) supplies canonical SQL, source locations
and typed expectations. This library owns neither a SQL interpreter nor storage.
The [application source contract](https://github.com/spoke-sh/transitc/blob/main/contracts/APPLICATION_SOURCE_V1.md#isolated-table-tests)
owns syntax, selection, limits and completion semantics.

`Runner.run` borrows compiled steps/expectations and an initialized SQL `Session`.
Its structural case interface accepts either the pure compiler product or a
validated [compiled-case request](../../../contracts/TEST_HOST_V1.md).
Source resolution and suite orchestration live in transitc. The runner executes
setup and assertions through normal preparation and durable settlement, consumes
complete typed results, and closes readers on every exit. Exact canonical row
bytes form a bounded multiset, preserving duplicate counts and NULL without
retaining borrowed cells across batches. Command counts and refusal reasons come
from verified owner outcomes. No write is replayed to obtain a convenient result.

Public Queue programs execute through the managed SQL owner. A
[WORKFLOW assertion](https://github.com/spoke-sh/transitc/blob/main/contracts/APPLICATION_SOURCE_V1.md#queue-program-tests)
observes exact recorded completed/refused counts under the
same frozen declaration, current authorization and a bounded polling budget.
Activation alone cannot satisfy it. Stream row assertions retain normal result
completion and disclosure checks. A matching counter observation does not assert
program idleness; host cleanup still joins workers and readers. These controls observe the real database;
they do not simulate clocks, effects or recovery.

`Bootstrap` provisions a disposable realm through signed public native and policy
operations. The root key is separate from the statement caller. The embedding
CLI owns its private directory, local endpoint, storage quotas, runtime activation,
session deadlines, explicit warm-pin draining and final disposal. It must join borrowers before releasing
that endpoint. Source declarations cannot choose a remote server or credentials.

The package's `zig build test` checks assertion bookkeeping. The repository `application-test-host` task exercises the native host with real
local storage, signed policy, revocation and fault checks. transitc owns the source
build and test command integration schedules. Unit checks alone do not establish integration,
crash recovery, distributed execution or power-loss durability.
