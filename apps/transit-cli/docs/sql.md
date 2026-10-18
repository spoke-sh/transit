# Local PostgreSQL and MySQL access

The local bundle includes `transit-sql-gateway`. PostgreSQL and MySQL are
independently disabled by default. A server that has never enabled either
protocol creates no SQL accounts, credentials, operation ledgers or gateway
process. Enabling a listener selects exposure; native authorization controls
login, database access and each Table operation.

Use the same installed bundle throughout an installation's lifetime. A
compatible installation can enable SQL by changing its YAML configuration and
restarting `transit server`. An incompatible definition or executable hash
rejects before opening retained state. Keep the matching old bundle to resolve
its accepted work; initializing a different directory is a separate operation.
The server never deletes or resets an incompatible installation.

## Configure and enroll an account

Run these commands from the installation's working directory. Use Linux x86_64,
the [local bundle](../../../nix/README.md#transit-cli-packages), and ordinary
`psql` and Oracle `mysql` clients. The development shell supplies both clients.
Choose free loopback ports; the defaults below also require port 19108 for
private SQL recovery/readiness checks.

Create a private password file using Bash or Zsh. Enter 1–128 printable ASCII
bytes; the file contains exactly those bytes, without a trailing newline.

```sh
umask 077
read -r -s sql_password
printf '%s' "$sql_password" > sql-owner.password
unset sql_password
```

Add this section to `transit.yaml`:

```yaml
sql:
  postgres: {port: 15432}
  mysql: {port: 13306}
  command_ms: 180s
  accounts:
    - name: owner
      role: local_owner
      password_file: ./sql-owner.password
```

`local_owner` is the existing local catalog owner. Binding this account to that
role explicitly gives it the role's existing rights. A new role starts without
data rights. The local profile selects database `transit` and schema `public`;
other catalog mappings require the standalone gateway deployment interface.
Account names contain 1–63 ASCII letters, digits, underscores or hyphens.

The example explicitly allows a statement to wait up to three minutes for its
durable result. The default is 30 seconds; the maximum is 270 seconds. Storage
work can exceed a client wait. A timeout or lost connection does not establish
that a write failed. Inspect its retained operation before considering new work.

Start `transit server` for an existing installation, or add `--initialize` only
for a deliberately new installation. The core ready record includes `sql.state`,
the authorization/catalog profiles and `sql.status_file`. Read that status file
while completing enrollment, for example with the default installation path:

```sh
cat .transit/sql/status.json
```

The status file is the supervisor's last observed snapshot and can remain after
shutdown. Confirm that the server is running; use the live private `/health`
probe for admission readiness or `/recovery` for worker readiness. Their port is
`sql.health_port` (19108 by default).

The core administration interfaces remain available while SQL awaits
authorization. The status file lists account names, roles, database/schema,
initialization state and control profiles. At `awaiting_binding`, the supervisor
has published a reviewable credential-binding proposal. Prepare and explicitly
apply it through the existing authorization commands:

```sh
transit auth prepare --config .transit/sql/authorization.yaml \
  --file .transit/sql/accounts/owner/bind-credential.json \
  --output owner-binding.saved.json
transit auth apply --config .transit/sql/authorization.yaml \
  --file owner-binding.saved.json --steps 64
```

Inspect the preparation preview. If apply reports `pending`, repeat **apply on
the same saved file** until it reports a published terminal outcome. Do not
prepare another change to recover a lost reply. If preparation rejects an unsent
proposal with `StaleAuthorizationRevision`, wait for the supervisor to refresh
that proposal, review it again, and prepare it. No command was submitted by the
failed preparation. The [authorization guide](authorization.md) explains
abandonment and exact recovery for saved work.

The generated `authorization.yaml` and `catalog.yaml` select a private local
administrator with its own native command sequence and explicit root-role
membership. Protect this profile and seed as full local administrative access.
The SQL process receives separate worker, ingress, coordinator, Table and
private-reader credentials; it receives neither the administrator nor the
operator control credential.

After binding, setup initializes the account's durable ledger in one fenced
activation and starts admission in a new activation. Wait for `accepting` in the
status file. It publishes the actual configured ports and CA path. A configured
listener can be available while another account still awaits authorization.

## Connect and share a Table

With the managed local CA and default paths, use verified TLS:

```sh
PGSSLMODE=verify-full PGSSLROOTCERT="$PWD/.transit/sql/tls/ca.pem" \
  psql -X -h localhost -p 15432 -U owner -d transit -W

mysql --protocol=TCP -h localhost -P 13306 -u owner -D transit --password \
  --ssl-mode=VERIFY_IDENTITY --ssl-ca="$PWD/.transit/sql/tls/ca.pem" \
  --default-character-set=utf8mb4
```

Substitute the status file's CA path and ports when using another installation
path or supplied trust. Both listeners bind `127.0.0.1`. The certificate identifies
`localhost` and `127.0.0.1`; there is no plaintext SQL authentication fallback.

Run one statement at a time. In `psql`:

```sql
CREATE TABLE shared_rows (id BIGINT PRIMARY KEY, label UTF8);
INSERT INTO shared_rows (id, label) VALUES (1, 'snow ☃');
SHOW DATABASES;
SHOW SCHEMAS;
SHOW TABLES;
SHOW sql.postgres.port;
```

In `mysql`, against the same catalog:

```sql
SELECT id, label FROM shared_rows;
UPDATE shared_rows SET label = NULL WHERE id = 1;
SELECT COUNT(*) FROM shared_rows WHERE label IS NULL;
DELETE FROM shared_rows WHERE id = 1;
```

The [SQL gateway reference](../../transit-sql-gateway/README.md) defines the
supported autocommit SQL, scalar types, prepared statements and protocol limits.
Transactions, general ORM compatibility and remote listener exposure are outside
this local interface. Stop with Ctrl-C and resume with `transit server`; retained
Tables, account identities and operation history remain available.

## Separate writer and reader roles

Add accounts named `writer` and `reader`, each with its own password file and a
same-named role, to `sql.accounts`, then restart. For each new role the account
status is `awaiting_role`. Prepare/apply its generated `create-role.json` using
the workflow above, then its `bind-credential.json`. These are explicit policy
changes; startup does not create SQL login roles or rebind revoked credentials.

After binding, review and apply `access.json` with `transit auth prepare-set`
instead of `prepare`. It grants the role the catalog-process transport rights,
settings inspection, database CONNECT and schema USAGE. It grants no Table
SELECT/INSERT/UPDATE/DELETE or schema CREATE privilege. Repeat bounded apply on
the saved changeset until all intents finish.

Catalog name resolution requires CONNECT and schema USAGE even for a policy
administrator. First review and explicitly apply the generated discovery grant:

```sh
transit auth prepare-set --config .transit/sql/authorization.yaml \
  --file .transit/sql/catalog-access.json --output catalog-access.saved.json
transit auth apply --config .transit/sql/authorization.yaml \
  --file catalog-access.saved.json --steps 64
```

This grants CONNECT on the local database and USAGE on its public schema to the
administrator's selected root role. It grants no Table data privileges. Repeat
apply on that saved file if pending. Startup refreshes the proposal's policy
basis but never applies it or restores revoked discovery rights.

Then put the desired Table grant in `writer.sql`:

```sql
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.shared_rows TO writer;
```

Compile and apply it:

```sh
transit catalog compile-authorization --config .transit/sql/catalog.yaml \
  --file writer.sql --output writer.plan.json
transit auth prepare-plan --config .transit/sql/authorization.yaml \
  --file writer.plan.json --output writer.saved.json
transit auth apply --config .transit/sql/authorization.yaml \
  --file writer.saved.json --steps 64
```

Use the same workflow for `GRANT SELECT ON TABLE public.shared_rows TO reader;`
and for REVOKE. Authorization SQL uses this dedicated public compiler and apply
workflow. Executing a GRANT through a database connection is not supported.
Existing and new sessions check current authority. Restart never restores these
grants or a credential that an operator disabled. An enrolled account's role,
database and schema bindings are immutable; use a new account name for a different
binding, preserving the old account's recovery identity.

## Trust and password rotation

Without `sql.tls` file references, Transit generates an installation-local CA
and server certificate through its pinned TLS library. The CA is valid for ten
years and the server certificate for one year. Their private checkpoint precedes
PEM publication. Missing exported managed PEM files can be recreated from that
checkpoint; missing retained trust state rejects rather than generating a new
identity. There is no automatic renewal.

To supply or replace trust, configure all three references together:

```yaml
sql:
  tls:
    certificate_file: ./private/server-chain.pem
    key_file: ./private/server.key
    ca_file: ./private/ca.pem
```

Merge this into the existing `sql` object. The leaf must be valid now, match the
private key, chain to the supplied CA, permit TLS server use, and have SANs for
both local names above. Invalid or expired trust prevents SQL admission while
retained ledger recovery and core administration remain available. Replace
files/configuration and restart. Distribute the replacement CA explicitly to
clients when changing trust; the server does not modify a client trust store.

The initial password file creates a salted verifier once. Changing that input
file does not rotate an enrolled account. Write a new private password file and
use the existing operator control with a strictly increasing verifier revision:

```sh
transit-sql-gateway control .transit/sql/accounts/owner/control.json \
  credential ./new-password .transit/sql/accounts/owner/verifier.json 2
```

The replacement is atomic. Sessions compare the complete credential revision
before new requests. Password rotation does not alter data privileges or
reinitialize the operation ledger. Keep passwords and signing keys out of
connection URLs, shell arguments and shared logs.

## Disable admission and inspect uncertain writes

Set either listener to `null`, or omit it, and restart to close that protocol.
Set an account's `enabled` to false or remove its declaration to prevent its next
login after restart. These changes preserve the account's credentials, immutable
catalog binding, ledger and accepted work. Completed removed accounts remain
inspectable through their retained control profiles without a resident worker.
Accounts with unsettled operations continue recovery with current worker rights.

With both listeners disabled, retained workers require no PEM files and open no
SQL sockets. The private `/recovery` probe describes worker readiness; `/health`
also requires configured SQL admission. Disabling a listener is not cancellation.
A bounded shutdown stops accepting connections, drains tasks and joins workers;
native generations fence replacements. Revoked worker authority must be restored
by an explicit operator decision before recovery can progress.

SQL setup or worker failures leave core administration available. The supervisor
stops admission after a failure and makes at most three setup/start attempts per
server invocation. Inspect `error_type` in the SQL status, repair the reported
configuration or authority, and restart to resume. Uncertain native transport
outcomes retain their exact requests and retry observation without consuming
this failure budget or allocating replacement work.

Each account's status names its `control.json` profile. If a connection loses a
write response, retain any reported operation ID. If it did not report one,
inspect the account's paginated inventory and correlate the original attempt:

```sh
transit-sql-gateway control .transit/sql/accounts/owner/control.json list
transit-sql-gateway control .transit/sql/accounts/owner/control.json status OPERATION_ID
transit-sql-gateway control .transit/sql/accounts/owner/control.json pending
```

`list` returns a cursor when more records exist. `status` distinguishes current
operation state from a confirmed Table outcome. Use the documented
[reconcile/cancel controls](../../transit-sql-gateway/docs/configuration.md#signed-operator-controls)
with the original ID where appropriate. Their saved pending file preserves exact
control identity; neither closing a socket nor an empty result justifies blindly
resubmitting SQL. Current authorization still governs operator inspection.

Local configuration admits at most 32 simultaneous active/recovering accounts.
Connection, authentication, statement/idle/drain deadlines and initial per-account
operation/byte/pending quotas have explicit bounded settings. Initial ledger
quotas are frozen at enrollment; changing their YAML defaults does not resize an
existing ledger. Use its explicit capacity control. Retained historical account
count is independent of resident memory. See the generated
[settings reference](../../../contracts/configuration-settings-v1.json) for defaults and bounds.
