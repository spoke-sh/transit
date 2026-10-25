# Local PostgreSQL and MySQL access

The local bundle runs a shared SQL service. Its private Unix socket provides
independent console sessions by default, using an OS peer check and a managed
`local` login. PostgreSQL, MySQL and native HTTP/TLS listeners are independently
opt-in. All adapters share account coordination and current authorization.

## Native HTTP/TLS sessions

For remote consoles, configure the native listener and an enabled account:

```yaml
sql:
  native:
    local: true
    http:
      address: 0.0.0.0
      port: 19109
      tls: true
      certificate_file: ./secrets/server.pem
      key_file: ./secrets/server.key
  accounts:
    - name: developer
      role: local_owner
      authentication: password
      password_file: ./secrets/developer.password
      bootstrap_owner: true
```

The certificate must cover the hostname used by clients. The
[console connection file](console.md#configuration-and-trust) supplies the HTTPS
endpoint, SQL account/database and password/CA references. No server signing key,
installation record or filesystem mount is needed. Native HTTP uses the same
shared runtime with both database-wire listeners disabled. Native TLS uses its
explicit certificate/key independently of `sql.tls`, which governs PG/MySQL.
Plain HTTP is admitted only for an explicitly configured loopback trust profile.

`sql.native.local: false` disables local admission. It does not delete accepted
work. The reserved `local` account cannot be redeclared in `sql.accounts`.
Source bindings use `sql.native.sources_file` for local sessions or
`sql.accounts[].sources_file` for network accounts; see
[source declarations](../../../packages/zig/transit-sql/docs/sources.md).
The configured sources are service-owned identities, never supplied by a console.

Use the same installed bundle throughout an installation's lifetime. A
compatible installation can enable SQL by changing its YAML configuration and
restarting `transit server`. An incompatible definition or executable hash
rejects before opening retained state. Keep the matching old bundle to resolve
its accepted work; initializing a different directory is a separate operation.
The server never deletes or resets an incompatible installation.

## Start locally without TLS

Use Linux x86_64, the [local bundle](../../../nix/README.md#transit-cli-packages),
and ordinary `psql` and Oracle `mysql` clients. The development shell supplies
both clients. Add this section to `transit.yaml`, selecting free ports:

```yaml
sql:
  postgres:
    port: 5434
  mysql:
    port: 13306
  tls:
    mode: disabled
  accounts:
    - name: owner
      role: local_owner
      authentication: trust
      bootstrap_owner: true
```

Run `transit server` for both a new installation and an existing compatible one. SQL setup creates
its account ledger and records the owner credential binding automatically. Once
SQL reports `accepting`, connect without certificates or password files:

```sh
psql -h localhost -p 5434 -U owner -d transit
mysql --protocol=TCP -h localhost -P 13306 -u owner -D transit --ssl-mode=DISABLED
```

Both listeners bind IPv4 loopback. `trust` accepts a client's claimed configured
SQL login: any local process able to connect can use that login's privileges.
It does not verify the operating-system user. Unknown or disabled SQL names
reject. Native role eligibility, database access, Table grants and current
credential checks apply to every session and protected operation.

`bootstrap_owner: true` explicitly binds a newly enrolled SQL account to the
installation's original `local_owner` role. It uses the shared authorization
operations and a saved request/receipt journal. It runs once per account;
restart never rebinds a disabled credential or restores revoked privileges.
Keep this declaration unchanged for that account. It cannot be enabled later on
an account enrolled without it, or used with another role. A recreated role with
the same name cannot replace the original owner. SQL workers never receive the
installation's administrator credential.

The local profile selects database `transit` and schema `public`; it does not
create a database matching the OS username. Account names contain 1–63 ASCII
letters, digits, underscores or hyphens. Both listeners remain opt-in. Configuring
a listener without an enabled account fails validation before child startup.

The core ready record includes `sql.state` and `sql.status_file`. SQL setup
continues independently of core readiness. Status transitions, actual connection
commands and failures are printed to stderr and saved in `.transit/sql/status.json`.
Configured ports and accepting ports are distinct. The file is the supervisor's
last observed snapshot and can remain after shutdown; the private `/health`
probe checks admission readiness and `/recovery` checks worker readiness at
`sql.health_port` (19108 by default).

## Select TLS and password authentication

Transport encryption and login authentication are independent settings:

| Setting | Behavior |
| --- | --- |
| `sql.tls.mode: disabled` | No TLS files are created or opened; PostgreSQL and MySQL trust logins use plaintext |
| `sql.tls.mode: optional` | One listener accepts plaintext or TLS; TLS setup must succeed before either is exposed |
| `sql.tls.mode: required` | Default; plaintext connections receive a protocol error |
| Account `authentication: trust` | No password file or password exchange; loopback only |
| Account `authentication: password` | Default; an explicit `password_file` supplies the initial verifier |

PostgreSQL password authentication uses SCRAM with or without TLS. MySQL's
full `caching_sha2_password` exchange requires TLS. With optional TLS a plaintext
MySQL password login rejects before requesting the password; a MySQL listener
with disabled TLS and an enabled password account fails configuration validation.
Trust works with any of the three TLS modes.

For passwords, create a private file outside Git containing exactly 1–128
printable ASCII bytes, without a trailing newline. For example, in Bash or Zsh:

```sh
umask 077
read -r -s sql_password
printf '%s' "$sql_password" > sql-owner.password
unset sql_password
```

Set `sql.tls.mode: required` and replace the owner's `authentication: trust`
with `authentication: password` and `password_file: ./sql-owner.password` **when
first enrolling it**. Keep `bootstrap_owner: true` to record the owner binding
automatically. Existing credential files are never silently regenerated by
configuration changes; the rotation workflow below replaces password verifiers.
A trust credential has no password verifier, and cannot authenticate a password
login merely because its configuration changed.

## Enroll other roles explicitly

For an account with `bootstrap_owner: false` (the default), setup publishes
reviewable proposals under `.transit/sql/accounts/<name>/`. At `awaiting_role`,
prepare/apply `create-role.json`; at `awaiting_binding`, prepare/apply
`bind-credential.json`. Use the shared
[authorization client](../../../packages/zig/transit-client/docs/authorization.md)
with the generated administrator profile. Prepare the typed action at its
recorded policy revision, persist the signed record, then explicitly submit and
observe each step until publication. The CLI does not provide administration
commands, and these proposals cannot be executed as console SQL.

Inspect the preparation preview. If apply reports `pending`, repeat apply on the
same saved file until it reports a published terminal outcome. A rejected unsent
proposal with `StaleAuthorizationRevision` needs a refreshed proposal and review.
Do not prepare another operation to recover a lost reply. The
[authorization guide](../../../packages/zig/transit-client/docs/authorization.md) explains exact recovery.

New roles start without data rights. Grant their database/schema access and
Table privileges explicitly using the examples below. The generated
`authorization.yaml` and `catalog.yaml` select a separate private administrator
with root-role membership; protect their seed as full administrative access.
SQL receives separate worker, ingress, coordinator and Table
credentials. Account initialization and normal admission use separate fenced
activations. One initialized account can serve connections while others await
authorization.

## Connect and share a Table

For the password configuration, use verified TLS (substitute your configured ports):

```sh
PGSSLMODE=verify-full PGSSLROOTCERT="$PWD/.transit/sql/tls/ca.pem" \
  psql -X -h localhost -p 15432 -U owner -d transit -W

mysql --protocol=TCP -h localhost -P 13306 -u owner -D transit --password \
  --ssl-mode=VERIFY_IDENTITY --ssl-ca="$PWD/.transit/sql/tls/ca.pem" \
  --default-character-set=utf8mb4
```

Substitute the status file's CA path and ports when using another installation
path or supplied trust. Both listeners bind `127.0.0.1`. The certificate identifies
`localhost` and `127.0.0.1`. TLS policy is enforced before login.

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

After binding, review `access.json` and prepare it through `AuthorizationSet`. It grants the role the catalog-process transport rights,
settings inspection, database CONNECT and schema USAGE. It grants no Table
SELECT/INSERT/UPDATE/DELETE or schema CREATE privilege. Repeat bounded apply on
the saved changeset until all intents finish.

Catalog name resolution requires CONNECT and schema USAGE even for a policy
administrator. First review and explicitly apply the generated discovery grant:

Use the same shared authorization lifecycle to prepare and apply
`.transit/sql/catalog-access.json` as a scoped changeset.

This grants CONNECT on the local database and USAGE on its public schema to the
administrator's selected root role. It grants no Table data privileges. Repeat
apply on that saved file if pending. Startup refreshes the proposal's policy
basis but never applies it or restores revoked discovery rights.

Then put the desired Table grant in `writer.sql`:

```sql
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.shared_rows TO writer;
```

Compile the statement through the Table bridge/service `compile_authorization`
operation under the selected catalog binding. Check that the resolved plan
matches the selected realm, principal and role. Convert it to its native action
and use the authorization bridge `prepare` action with the recorded policy
revision. Persist the resulting record and explicitly submit/observe its steps
through the shared client.

Use the same workflow for `GRANT SELECT ON TABLE public.shared_rows TO reader;`
and for REVOKE. Authorization SQL uses this dedicated public compiler and apply
workflow. Executing a GRANT through a database connection is not supported.
Existing and new sessions check current authority. Restart never restores these
grants or a credential that an operator disabled. An enrolled account's role,
database and schema bindings are immutable; use a new account name for a different
binding, preserving the old account's recovery identity.

## Trust and password rotation

Without `sql.tls` file references, Transit generates an installation-local CA
and server certificate through its pinned TLS library when TLS is optional or required. The CA is valid for ten
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
Idle PostgreSQL/MySQL connections remain open by default (`sql.idle_ms: 0`).
A positive value enables idle expiry; PostgreSQL reports `57P05`, and MySQL
reports `4031`. An existing `idle_ms: 30s` entry still enables that timeout.
Native HTTP sessions use the independent renewable `sql.native.session_lease_ms`
lease. See [configuration](../../../docs/handbook/reference/configuration.md) for bounds.

A `busy` SQL status with `HttpCapacity` means the supervisor could not complete
its account observation because native request capacity was full. It does not
restart the SQL process or establish current readiness. The next scheduled
check retries the observation; sessions continue to enforce current authorization.
Connection hints appear once for each listener process, including replacements.

Connection, authentication, statement/idle/drain deadlines and initial per-account
operation/byte/pending quotas have explicit bounded settings. Initial ledger
quotas are frozen at enrollment; changing their YAML defaults does not resize an
existing ledger. Use its explicit capacity control. Retained historical account
count is independent of resident memory. See the generated
[settings reference](../../../contracts/configuration-settings-v1.json) for defaults and bounds.
