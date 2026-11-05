# Filesystem publication qualification

Issue [#382](https://github.com/spoke-sh/transit/issues/382) reports EFS rejecting
Linux `renameat2(RENAME_NOREPLACE)` during first installation. The runtime now
uses explicit directory claims/commits and hard-link publication for named
immutable files. This is a current-v1 cutover: earlier installations, saved
operations and staging directories require their matching build. Never adopt
or delete the four reported old assemblies as part of this proof.

## Local regression

From the repository root:

```sh
nix develop --command just test::server-filesystem
nix develop --command zig build test-cli-lifecycle
```

The first check runs actual embedded server processes with an inherited Linux
seccomp filter: `renameat2` with `RENAME_NOREPLACE` returns `EINVAL`, and
`openat(O_TMPFILE)` returns `EOPNOTSUPP`. Negative controls prove both restrictions
are active and ordinary rename/hard links still work. It checks first startup,
SQL enrollment, an accepted Table write, application installation, duplicate
manager refusal, abrupt manager replacement, stable durable identities and the
same retained row. It reports the executable SHA-256. Unit fault schedules inject
errors before and after publication operations, including sync and cleanup,
and check exact recovery or refusal of an unclaimed destination.

These checks do not simulate NFS server crashes, network partitions, cache
coherence, cross-client advisory locks or power loss. No local pass qualifies EFS.

## Hosted EFS acceptance

The Platform deployment owns this acceptance. Use an explicitly disposable EFS
access-point child path and the intended UID/GID, mount options, task networking,
Fargate platform, CPU and memory limits. Freeze the promoted release tag, Git
revision, manifest/checksums and OCI digest before running. Do not rebuild the
runtime from the proof driver's checkout or use a mutable image tag. Build the worker/operator test artifacts and private operation fixture from
that exact source revision and definition when running the source-side harness;
keep their provenance separate from the published runtime under test.

The driver accepts explicit binary paths and a mounted parent without injection:

```sh
python3 -B tests/runner/launch.py tests/interfaces/installation/server_filesystem.py \
  /artifacts/transit /artifacts/transit-work-items /artifacts/work-items \
  --parent /mnt/disposable-efs-parent --native-filesystem
```

`TEST_TRANSIT_OPERATIONS` selects the matching private operation fixture.
The driver owns a new random child, never an existing installation. Successful
runs join their processes and remove only that child. Failures retain it privately;
logs, seeds, saved operations and installation files must not be uploaded.
The executable hash and completion summary are safe proof metadata.

Also execute these checks with separate clients/tasks; the one-host driver cannot
establish them:

1. Hold the installation and backend locks from one task. A second task on the
   same EFS path must refuse management before activation or mutation. Record
   lock scope and the actual client identities.
2. Lose or partition the original client, observe readiness withdrawal, and
   replace it only after exclusive ownership is established. Verify the original
   retained installation, accepted rows, application/resource identities and
   exact saved outcomes; never submit an uncertain write as a new operation.
3. Verify competing exclusive creation and hard-link publication preserve an
   existing file, empty directory, populated directory and symlink across clients.
   Exercise interruption before/after claim, commit and parent sync. Unmarked
   mkdir residues must remain refused and preserved.
4. Run the intended SQL listeners and application workload under the production
   resource envelope. Confirm no storage/authority readiness bypass, unexplained
   identity change, missing retained write, leaked manager or resource-budget exit.

Record each command, artifact identity, environment, observed result and remaining
limits in #382. Unsupported lock-loss fencing or inconclusive sync evidence is a
failed prerequisite for that deployment profile, not permission to weaken the
publication checks. Keep existing production state and failed old assemblies
unchanged until a separately reviewed recovery/cutover decision.
