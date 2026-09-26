# Transit public Station C SDK

M11's public [transit/station.h](include/transit/station.h)
defines codec callbacks, a sequential handler runner, mutation recovery hooks,
scoped KV/Table helpers, retained read versions and original query IPC. The
runner and typed operations delegate protocol/framework behavior to Zig's
growing Station ABI. Clean installed examples and the shared runner authority
schedule pass on pinned Zig/Linux x86_64. Other M11 targets and the public
mixed-language matrix remain separate qualification work.

The C11 interface has explicit owned handles and typed result structures; its
implementation uses C++17. It directly depends on the independent
[C client SDK](../transit-client/README.md) and the generated client/Station ABI
packages declared in `build.zig.zon`. Build from this package with `zig build`.
Native artifact lookup and the 8 MiB bounded worker follow the client SDK.
See [installation, ownership and recovery](docs/USAGE.md) for the public contract.
M15 adds [HTTP request publication, correlated calls and owned replay](docs/HTTP.md)
through the shared Zig bindings package.

Callbacks borrow turns and decoded messages. Retaining a turn keeps its local
handle safe to inspect after the handler turn, where operations fail with
TURN_EXPIRED; it does not extend a private proposal or grant. Calls from a
different thread or recursive calls through a codec fail with BUSY. Decoded
values, pages, cursors, rows, pending operations, events and IPC segments each
have an explicit destroy function. Input pointers and callback contexts must
remain valid through their synchronous use; runner callback contexts/codecs
must outlive the runner, and codec destroy callbacks must not throw.

Choose stop or recorded block-input handling, and explicitly choose a persistence
store or fresh-ownership recovery. Every permit, open and commit passes through
the persistence hook before dispatch. Failed confirmation hooks retain the
known receipt and do not rerun the handler. Native or host read failure poisons
the turn even if the handler catches the error. Close joins owned work and
returns pending/last-event evidence; it never acknowledges a private turn.

`just bindings::c-sdk-test` builds independent pkg-config archives and runs both
installed C11/C++17 counter CLIs plus the shared recovery/Table/query schedule.
The C++ test controller selects the direct C runner with the compiled C callback
library, then the public C++ runner/handlers. It checks scope/reentry failures,
stop/block policies, exact seedless recovery, current grants and six original IPC
segments independently decoded after close. [Proof details](../../../tests/README.md)
distinguish shared native allocation checks from this SDK's host error paths.
