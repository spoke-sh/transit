# Physical application qualification

These owned fixtures extend the [native composition](browser.md). They are
finite qualification tasks, not persistent application launchers or an automatic
growing runtime controller. Executed Compose/reference results are tied to their
source revisions; measurements and limits belong in the
[test ledger](../../../docs/history/qualification/deployment.md#work-items-direct-storage-in-compose--2026-10-24).

```sh
nix develop
just transit-board::install
just test::work-items-placement compose
just test::work-items-placement reference
```

Reference needs the existing pinned reference infrastructure and runtime image.
The fixture creates a new namespace and checks its UID on cleanup; it does not
update the default launcher installation. Each profile explicitly initializes
its own realm in the local native owner. Native history and direct Table storage
share that owner's persistent directory: a host bind mount for Compose and a
separate PVC for Reference. After native provisioning, the operator enables the
Table service, restarts the node and initializes the catalog through the public
typed caller. Ordinary replacement opens the existing history.

The fixture also runs Ursula and pinned native MinIO as isolated denial targets;
they do not store this application's data. Their addresses, including the exact
MinIO port, appear in egress probes. The fixture owns and joins the MinIO process
separately from placement cleanup.

Compose places data, publication, requester, delivery, gateway, authority and
the isolated storage target in separate containers. Only authority joins both
the private client and storage networks. Workers mount only their own
configuration, credential and activation directory. Roots are read-only,
capabilities are dropped, and process, CPU, memory and log limits are explicit
in the Compose file.

Reference places the three logical owners in separate Substrate/gVisor actors.
Each generates a fresh ephemeral key, emits its public registration and waits for
the exact native ownership generation. The trusted operator validates realm,
principal, PID, generation, actor, template and physical worker identity before
conditionally rotating the same principal's key and ownership generation.
Existing native roles, Table-role selection and foreign requester-resource grants
survive that rotation. Associations alone remain insufficient for reads.
The courier and provisioning/migration caller remain separate trusted operator
processes. The gateway uses a confined Kubernetes pod with its own read/query
keys, without the operator key or Kubernetes service-account credentials.

The browser reaches a pinned nginx TLS edge on loopback. Independent peers check
certificate trust and hostname rejection; Chromium pins the fixture's public
key. Its private backend remains stable through gateway replacement. The reused
edge limits bodies to 8 KiB; this fixture uses bounded Table query requests and
publishes declarations through the native operator. It does not qualify the
gateway's larger operator-upload body limit through that edge. Workers cannot
reach the cold store, Ursula or the public Internet. The reference probes also
reject Kubernetes and Substrate control endpoints.

The shared browser proof first verifies all three result pages and saves a lost
accepted upload. The fixture then stops all owners, the gateway, node and isolated
storage target. Recovery preserves the native/Table directory and logical
PIDs/resources, registers new worker keys and generations, migrates and verifies
the target Table, updates query policy,
publishes the matching interface and explicitly releases normal writes. The
browser reloads, settles the original signed upload, rejects continued execution
under its old source contract, cancels that original work and explicitly runs a
new query. Finally, current value-read denial clears protected results.

The finite queries each have a 180-second verification deadline. The browser's
separate wait for external physical replacement and migration is 180 seconds in
Compose and 600 seconds in Reference. A longer placement wait does not renew a
query, replenish its budget or replace its accepted identity.

Provider state, TLS, template identity and restored disk history never grant
execution rights. These fixtures do not qualify distributed authority movement,
provider snapshot recovery, root bootstrap recovery after every possible lost
operator reply, automatic supervision or application migration across realms.
