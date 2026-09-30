# D6 operator objects and SQL

[D6 review](D6.md) · [Review index](README.md)

Status: **Proposal, not an executable language extension**. This appendix maps
the operator surface to the checked Transit grammar, identifies semantic owners,
and proposes a concrete SECRET lifecycle. It changes neither the grammar nor
the parser, public API, permissions or deployed configuration.

## What the current grammar means

The audit follows [TransitExtensions.g4](../../../contracts/sql/TransitExtensions.g4),
the [grammar contract](../../../contracts/sql/README.md),
[D2's earlier audit](D2.md#what-the-sql-grammar-actually-supports) and the
[production SQL guide](../../../packages/zig/transit-fuze/docs/sql.md).

Use three distinct support labels throughout this review:

| Label | Meaning |
| --- | --- |
| Executable | A qualified compiler/public operation implements the statement for its declared profile |
| Reference only | The checked reference grammar admits the syntax; production SQL does not execute it |
| Proposed | Syntax or semantics are missing and are proposed here; examples must not be offered as runnable commands |

The existing executable SELECT profile queries a supplied Table. It does not
resolve operator catalogs, invoke table functions or expose system relations.
All operator SQL in this review is **Reference only** or **Proposed**.
Existing typed grant, lifecycle or connector operations remain real, separate
foundations; their existence does not implement their proposed SQL spelling.

`secretRef : SECRET LPAREN STRING RPAREN` currently occurs only in the shared
option-value rules used by CONNECTION, SOURCE and SINK declarations. Thus this
is **Reference only**:

```sql
CREATE CONNECTION catalog_api TO HTTP (
  endpoint = 'https://catalog.example.test',
  token = SECRET('catalog-token@3')
);
```

The parser accepts one opaque string. It does not split `@3`, resolve a store,
create a secret, acquire permission or return a credential value. `SELECT
SECRET(...)` is not part of the SELECT grammar. `CREATE SECRET`, `ALTER SECRET`,
`DROP SECRET`, `SHOW SECRETS` and `DESCRIBE SECRET` have no productions.
`DESCRIBE "catalog-token"` has the existing generic DESCRIBE shape, but no
implemented object resolver. Keeping those distinctions explicit avoids
mistaking an existing keyword for an existing management interface.

## Map every Operations component

Candidate spellings below are **Proposed** unless the support column says
otherwise. Naming them is a language design question, not authorization to
implement or run them. Read catalogs must be bounded, currently authorized and
explicit about their observation basis.

| Operations component | Declarative object / read surface | SQL mapping and support | Semantic owner / missing contract |
| --- | --- | --- | --- |
| Overview | Projection of the rows below and their Workspace dependents | No new configuration object; compose authorized catalogs | Board derives a bounded summary; no combined snapshot or global readiness bit |
| Access / Authentication | Authentication profile: verifier type, issuer/audience, trust, principal mapping | `CREATE AUTHENTICATION`; `SHOW AUTHENTICATIONS` — Proposed | Identity ingress owns verification, session boundaries, mapping, freshness and failure behavior |
| Access / Principals | Stable realm-bound human/service principal and key/identity bindings | `CREATE PRINCIPAL`; `SHOW PRINCIPALS` — Proposed | Transit identity authority; external subject mapping and key replacement must preserve stable identity and ordered policy |
| Access / Grants | Action, typed target, principal, policy revision | `GRANT … ON … TO …`, `REVOKE … ON … FROM …` — Reference only | Lower to the appropriate realm/resource/service policy operations; resolve exact IDs, target kind and current policy |
| Access / Board access | Deployment admission, inspection identity, optional query identity and future operator identity | No current SQL; any future Board-access declaration needs an owner | Trusted deployment config today; attributable operator admission is new scope, not a widened inspector grant |
| Secrets & trust / Secrets | Versioned credential binding with type, store, external locator/version and permitted use | `CREATE/ALTER/DROP SECRET`; `SHOW SECRETS` — Proposed; generic `DESCRIBE name` — Reference only | Credential registry/resolver above Transit; versioned metadata and separate use/manage/disclosure rights |
| Secrets & trust / Stores | Configured resolver/provider binding and its bootstrap identity | `CREATE SECRET STORE`; `SHOW SECRET STORES` — Proposed | Trusted credential adapter; does not provision a vault, read arbitrary server files or upload an administrator key |
| Secrets & trust / Trust profiles | Explicit peer identity rules and pinned trust material | `CREATE TRUST PROFILE`; `SHOW TRUST PROFILES` — Proposed | Transport/identity verifier; public trust material and private client credentials remain separate objects |
| Capabilities | Installed transport, connector and integration profiles, versions, limits and supported directions | `SHOW CAPABILITIES` — Proposed; `DESCRIBE name` — Reference only | Owning package/deployment publishes capabilities; SQL cannot install arbitrary code |
| Capabilities / execution policy | Destination, methods, credential/header scope and attempt budgets | `CREATE CONNECTOR POLICY` — Proposed | Connector policy owner; qualify lowering to frozen endpoint and followup policy before any control is enabled |
| Runtime & storage / Bindings | PID, provider binding/incarnation, workload version and separate observations | `SHOW RUNTIME BINDINGS` — Proposed | Runtime/public-client authority; restart, drain or migration need specific typed control contracts, not generic UPDATE |
| Runtime & storage / Capacity | Named admission quotas, resource use and retained boundaries | `SHOW CAPACITY`; eventual quota/retention declarations — Proposed | Capacity and retention owners; no SQL grammar or generic mutable system table exists |
| Diagnostics | Service instance, bounded logs/metrics, freshness and loss | `SHOW SERVICES` and future diagnostic read relations — Proposed | Observability owner; lossy telemetry stays distinct from D5's durable Activity and Table snapshots |

There is deliberately no `CREATE OPERATOR`, `UPDATE system.*`, `SELECT secret_value`
or universal `RESTART` command. Navigation categories are not durable objects.
System inspection would be a new source class, as described in the
[query language](../../history/QUERY_LANGUAGE.md#later-naming-non-data-components-as-queryable-relations).
Do not manufacture executable SQL simply because a form or table needs a home.

## DuckDB as a reference

DuckDB provides named, typed secrets, provider selection, optional path scope,
temporary/persistent lifetime, SQL creation/removal and metadata discovery. Its
scope lookup selects the longest matching path prefix. These are useful examples
of a coherent management vocabulary. [DuckDB Secrets Manager](https://duckdb.org/docs/current/configuration/secrets_manager).

DuckDB documents local persistent secrets as unencrypted files, and its SQL
statement page notes that CLI history can contain CREATE SECRET text. Transit
will keep private material outside SQL and recorded definitions. This is a
proposal for Transit, not a claim that DuckDB supplies its authority model.
[DuckDB Secrets Manager](https://duckdb.org/docs/current/configuration/secrets_manager),
[CREATE SECRET](https://duckdb.org/docs/current/sql/statements/create_secret).

DuckDB also describes queries' ability to use available credentials and the
option to expose unredacted secret content. Transit should expose reference
metadata only and check scoped use at each authorized attempt; a SQL session
does not inherit ambient secret authority. [Securing DuckDB](https://duckdb.org/docs/current/operations_manual/securing_duckdb/overview#secrets).

We borrow the object vocabulary and discoverability. Transit's explicit
connection reference, immutable attempt scope and current grants remain the
selection/authority rules. No longest-prefix credential fallback, local secret
file persistence or unredacted-value option is proposed for Board.

## What managing a SECRET means

**A Transit SECRET would be a durable, realm-scoped binding to externally held
credential material. SQL manages that binding's metadata and lifetime.** It
does not carry, read back or mint the credential bytes. A secret store identifies
the configured resolver; the secret's type describes its intended use, such as
an HTTP bearer header. A connection explicitly names a binding revision.

The binding contains stable object identity, display name, revision, type,
store identity, opaque provider locator/version, permitted destination/header
policy, lifecycle and accepted change receipts. The resolver privately obtains
material only for an authorized use. Even names, locators, scopes and use
relationships need their own metadata disclosure permission.

Three versions must stay visible and distinct:

| Version | Example | Meaning |
| --- | --- | --- |
| Secret binding revision | `3` | Immutable Transit metadata snapshot; mapped to the connector's binding/version tuple |
| Provider version | `v17` | Opaque external credential version resolved by the adapter; not parsed as a Transit counter |
| Connection revision | `7` | Definition selecting secret binding revision 3 alongside its endpoint/policy |

The proposed catalog must map the stable binding ID/revision to the current
HTTP contract's name/version representation without reusing a retired identity
or changing an existing tuple's meaning. This requires a versioned adapter
contract; it is not supplied by the present deployment-file registry.

## Concrete proposed SQL

Every statement in this section is an **individual candidate**, not a runnable
script or transaction. Keyword spelling and option schemas remain in review.
The examples reuse Transit's `key = value` options rather than claiming DuckDB
syntax compatibility. New keywords and the revision precondition need grammar
work; quoted names and literals retain the existing lexical rules.

### Register a store and create a binding

```sql
CREATE SECRET STORE storefront_secrets
USING mounted_credentials
WITH (deployment_binding = 'storefront-http');
```

This references an operator-provisioned adapter binding. It does not create a
filesystem mount or accept an arbitrary path from the browser. Provider access
credentials and initial root identity remain trusted deployment bootstrap.
Managed vault providers can use the same contract later; none is selected here.

```sql
CREATE SECRET "catalog-token"
TYPE HTTP_BEARER
FROM storefront_secrets
WITH (
  locator = 'catalog-token',
  provider_version = 'v17',
  destination_policy = 'catalog_egress'
);
```

CREATE conditionally creates a new binding and accepted revision; it cannot
replace an existing name. `HTTP_BEARER` permits the configured Authorization
header, under an explicit destination policy. The policy must resolve to a
frozen typed revision covering the destination and allowed header, not remain
a floating string. Definition validation checks authorized metadata, types and
references. It does not resolve bytes or test the remote endpoint.

Bindings persist as durable Transit declarations by default. There is no
TEMPORARY or PERSISTENT modifier in this first proposal. Credential validity,
binding retirement and audit retention are separate; browser/session closure
changes none of them. Raw-value options such as token/password/private_key are
outside the accepted schema, including in SQL text and import workflows.

### Inspect and authorize use

```sql
SHOW SECRETS;
```

```sql
DESCRIBE "catalog-token";
```

SHOW is Proposed; DESCRIBE has only the existing reference syntax. Both would
return permitted metadata, current revision, provider-version reference and
dependency/availability evidence. Neither has a value-reveal mode. A returned
locator or object reference is not a bearer grant. Discovery cannot leak names
through hidden counts, suggestions, errors or inverse-dependency edges.

```sql
GRANT use_secret ON "catalog-token" TO http_executor;
```

```sql
REVOKE use_secret ON "catalog-token" FROM http_executor;
```

These fit today's **Reference only** GRANT/REVOKE grammar because privileges are
identifiers. `use_secret` is a **new semantic permission proposal**, not an
existing kernel permission bit. Metadata inspection, binding management,
authorized use and underlying provider administration are separate rights.
The implementation must specify whether each maps to an existing authority
operation or needs a separately versioned policy service; do not grant all of
them through one generic administrator checkbox.

Authorized use is available only to the scoped executor for a permitted
committed attempt. It grants neither a SQL scalar read nor a Board download.
The application caller separately needs authority to request that operation;
neither caller nor operator receives the executor's credentials by delegation.

### Reference an exact revision

```sql
CREATE CONNECTION catalog_api TO HTTP (
  endpoint = 'https://catalog.example.test',
  token = SECRET('catalog-token', REVISION 3)
);
```

The two-argument SECRET form is **Proposed**, unlike D2/D5's opaque one-string
form. It denotes a reference node in the typed definition, not an evaluated
string value. Require an explicit revision for durable dependencies; do not
resolve “latest” again during retry or replay. A future compatibility decision
must define the old one-string form or reject it with a migration explanation;
silently splitting any string containing `@` is not acceptable.

### Rotate the binding, then review its consumers

```sql
ALTER SECRET "catalog-token"
IF REVISION = 3
SET (provider_version = 'v18');
```

This accepts a new immutable binding revision, illustrated as 4. The new
provider version must already exist or have its own separately authorized
provisioning outcome. The operation does not regenerate a remote credential.
The UI says **Change binding version** and explains that existing consumers
remain pinned. A provider value must never be mutated in place under the same
recorded binding tuple; an adapter without stable versions needs an explicit
freezing contract before it can support durable use.

```sql
ALTER CONNECTION catalog_api
IF REVISION = 7
SET (token = SECRET('catalog-token', REVISION 4));
```

This is a second proposed operation. There is no atomic multi-object apply or
automatic dependent rewrite. Show partial progress and receipts separately.
New work uses the newly accepted connection only after its own policy checks;
recorded attempts keep their frozen reference. Exact receipt recovery retains
the original operation ID, expected revision and bytes outside the SQL text.
An uncertain response never starts a new rotation or external attempt.

Rollback is another new binding/connection revision with current authorization.
It cannot resurrect provider material that was revoked or destroyed, or reset
an attempt's deadline. Replay reads captured evidence without resolving secrets.

### Retire the binding

```sql
DROP SECRET "catalog-token" IF REVISION = 4 RESTRICT;
```

DROP proposes logical retirement with a permanent identity/tombstone. RESTRICT
refuses retirement while active consumer references or unsettled obligations
would be invalidated. Retained historical references preserve evidence without
requiring private bytes forever. No CASCADE, provider deletion or history erasure
is implied. A store has the same dependency restriction before retirement.

To stop new use immediately at the defined authorization boundary, revoke the
use permission through its qualified policy operation. Revocation cannot unsend
an authorized attempt. Recovery/reconciliation follows its already recorded
scope and budgets; it does not fall back to a different version. Provider token
revocation or deletion is a separate externally authorized operation.

## Lowering, previews and authority

Forms and SQL must share one typed proposal and validator. Every mutation
envelope binds realm, attributable principal, stable target, expected revision,
resolved dependency revisions, operation identity and budgets. Editing and
previewing change that local proposal only. Administrative SQL is never admitted
to Explore's Live scheduler, including syntactically valid candidate text.

The review pane separates syntax support, semantic resolution, current permission,
durable acceptance and observed application. A preview cannot promise acceptance.
Unavailable authority prevents submission; a conflict preserves the draft and
requires a new comparison. A lost response preserves the frozen operation for
receipt recovery. No resolved credential enters query history, autocomplete,
errors, telemetry, exports, diffs, fixtures or Board caches.

## Required implementation gates

Before any of these controls can execute: version the public declaration and
policy contracts; specify catalog/name resolution, secret-reference migration,
conditional revisions and permanent retirement; define attributable Board ingress
and bootstrap; qualify resolver isolation, current use checks and no implicit
credential fallback; and test lost replies, concurrent rotation/revocation,
provider outages, replay and bounded discovery. Then add grammar/parser fixtures
and typed lowering together. A parser-only PR would not establish SECRET support.

The [current HTTP contract](../../../contracts/STATION_HTTP_V1.md#requests-and-scope)
and [worker configuration](../../../apps/transit-station-http-worker/README.md)
already provide pinned binding versions, scoped private resolution and omitted
capture values. Managed stores, live catalog mutation and the operator SQL above
are additional scope under the [roadmap sequencing rule](../../roadmap/README.md#maintaining-the-sequence).
