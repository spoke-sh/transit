# Physical application qualification

These owned fixtures extend the [native composition](browser.md). They are
finite qualification tasks, not persistent application launchers or an automatic
growing runtime controller. Both Compose and reference recovery pass for the
selected Table/browser profile; measurements and limits belong in the
[test ledger](../../../tests/README.md#m23-application-declaration-boundary).

```sh
nix develop
just transit-board::install
just test::work-items-placement compose
just test::work-items-placement reference
```

Reference needs the existing pinned reference infrastructure and runtime image.
The fixture creates a new namespace and checks its UID on cleanup; it does not
update the default launcher installation. Each profile initializes its own realm,
owned disk WAL and bounded hot storage backed by the pinned cold-store fixture.

Compose places data, publication, requester, delivery, gateway, authority and
storage in separate containers. Only authority joins both the private client and
storage networks. Workers mount only their own credential/configuration and
activation directory. Roots are read-only, capabilities are dropped, and process,
CPU, memory and log limits are explicit in the Compose file.

Reference places the three logical owners in separate Substrate/gVisor actors.
Each generates a fresh ephemeral key, emits its public registration and waits for
the exact native ownership generation. The trusted operator validates realm,
principal, PID, generation, actor, template and physical worker identity before
regranting access and recording ownership. Foreign requester-resource grants
must be reissued after data-worker key replacement; associations are insufficient.
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
accepted upload. The fixture then stops all owners, the gateway, node and disk
store. Recovery preserves logical PIDs/resources, registers new worker keys and
generations, migrates and verifies the target Table, updates query policy,
publishes the matching interface and explicitly releases normal writes. The
browser reloads, settles the original signed upload, rejects continued execution
under its old source contract, cancels that original work and explicitly runs a
new query. Finally, current value-read denial clears protected results.

Provider state, TLS, template identity and restored disk history never grant
execution rights. These fixtures do not qualify distributed authority movement,
provider snapshot recovery, root bootstrap recovery after every possible lost
operator reply, automatic supervision or application migration across realms.
