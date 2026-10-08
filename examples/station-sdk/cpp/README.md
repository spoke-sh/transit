# Typed C++ Station examples

`transit/sdk_examples.hpp`
contains typed counter/requester and Table/query handlers using the public C++17
Station SDK. Variant message types distinguish service and requester payloads;
the C application library owns the shared versioned byte codec. No native ABI
actions appear in application handlers.
`just bindings::c-sdk-test` runs installed counter CLI roles, typed query handlers,
retained state and original IPC through the shared authority schedule.

`transit-cpp-counter URL service|requester REALM PRINCIPAL PID GENERATION SEED_FILE
PEER COMMITS PENDING_FILE` runs committed inputs using an explicit persistence
store. Configuration assumes existing authorized processes and associations;
delivery remains a separate Transit role. Unknown outcomes stop for explicit
recovery with the persisted exact request. The query requester streams owned
IPC segments into its consumer callback. Callback effects still need an
application idempotency policy because their handler turn is private.

The [Table queue contract](../TABLES.md) defines resumable four-column creation,
ordered mutations, original operation identities and explicit busy query replies.
