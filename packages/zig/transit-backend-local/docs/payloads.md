# Standalone immutable payloads

`PayloadStore` stores the bytes named by an accepted native `declare_payload`.
It borrows one request lane's native engine and uses the same exclusive local
backend. The caller remains responsible for authenticated public operations;
this internal physical adapter grants no caller permissions. It checks the
complete current accepted payload record under the native publication fence.
Native payload keys are reserved from direct data adapters.

A trusted publisher calls `createPayloadOnce` once after its declaration is
accepted. The declaration binds the payload ID, process, publisher, SHA-256,
byte length and deletion opt-in. Values are nonempty and at most 64 KiB. A durable
attempt marker precedes immutable object publication. Concurrent creators with
the same identity produce at most one attempt; an existing marker reports
`PayloadCreationAttempted`. Neither creation nor verification publishes
`payload_ready`; that remains a separate authorized command from the publisher.

After an uncertain creation result or restart, call `verifyPayload` on the
original declaration. It verifies the marker, complete bytes and hashes, then
syncs the observed marker/content/descriptor files and their directories.
Readable data after a crash is not sufficient evidence of durable publication.
Verification repeats no PUT and never restores missing content. Missing bytes
remain unavailable/uncertain; the caller must not issue another creation attempt
because an error or missing observation cannot prove the first attempt did not
happen. Corruption and failed recovery barriers reject verification.

Retention defaults to unlimited. Physical retirement requires the current
accepted `retiring` record, creation-time `allow_delete`, and the native process
retirement rules. `reclaimPayload` verifies that exact record, removes the
descriptor/content/checksum pair and retains the small attempt marker permanently.
The accepted retirement and marker prevent delayed recreation. Deletion can be
retried after uncertainty; it does not publish `payload_deleted` automatically.
The caller records that separate native evidence only after confirmed physical
completion. Ordinary native object collection does not own standalone payloads.

Creation charges the shared encoded-file quota. Refusal leaves the accepted
declaration unresolved and grants no expiry authority. Confirmed deletion releases
actual removed lengths once; the marker remains charged. Uncertain I/O can leave
conservative reservations until exclusive reopen recounts files. Verification
uses bounded buffers, including a 64 KiB payload buffer and the object store's
chunk-validation scratch. An engine and its page cache belong to one request
lane; independent lanes share the backend's publication and allocation locks.

`readPayload` copies ready bytes into the caller's bounded buffer, verifies the
marker and content, and releases the publication fence before transport. A service
guard runs under that fence for every physical operation; direct component callers
remain trusted. The installed local node provides the
[authenticated payload route](../../../../contracts/SERVICE_V1.md#standalone-payload-bytes).
Its maintenance task rechecks current deletion authority under the same fence,
confirms physical removal, then publishes the separate native deletion evidence.
The [proof ledger](../../../../docs/history/qualification/README.md) records the executed disk,
concurrency, corruption and sync-failure cases. The
[native contract](../../../../contracts/TRANSIT_V1.md#payloads-and-working-catalog-collection)
owns readiness/retirement transitions, and the
[storage contract](../../../../contracts/TRANSIT_STORAGE_V1.md#local-standalone-payloads)
owns the physical layout.
