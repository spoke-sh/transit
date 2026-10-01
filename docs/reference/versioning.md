# Versioning and hard cutovers

Before Transit 1.0, every Transit-owned protocol has one supported definition,
named **v1**. Breaking changes replace that definition in a hard cutover. There
is no concurrent support for older definitions, deprecation window, fallback
decoder or compatibility route. This keeps implementation, verification and
documentation focused on the same current behavior.

## Scope

The policy covers native commands and HTTP envelopes, state and query contracts,
Station messages, serving and reactive bindings, installation/bootstrap schemas,
configuration formats, saved-operation formats and language-neutral ABIs.
Transit-owned version fields, signature domains, routes, file names and generated
declarations must agree with their owning v1 contract.

Upstream standards keep their own identifiers: HTTP/2, OpenAPI, AsyncAPI, Arrow,
Flight, ADBC and provider formats are not renumbered. Package and release versions
identify software artifacts. Application schema revisions, resource revisions,
ownership generations, sequence numbers and permission epochs retain their
domain meanings; they are not protocol generations.

## Compatibility between builds

The v1 label names the current contract; it does not promise that two pre-1.0
builds interoperate. Deploy clients, SDKs, workers and services from a matching
source revision or an explicitly verified release set. Their compatibility checks
must distinguish incompatible contract definitions even when both are called v1.
Do not infer compatibility from a shared version number or successful JSON parsing.

A cutover updates all affected producers and consumers together. Mixed old/new
deployments and rolling upgrades across an incompatible definition are unsupported.
Reject incompatible peers and artifacts before mutation, disclosure or external
dispatch. Canonical bytes, signing fixtures and generated schemas change with
their implementation owners.

## Durable data and pending operations

A hard cutover does not authorize deletion or reinterpretation of accepted work.
Old histories, checkpoints, saved signed requests, cursors and installation
records require an explicit compatibility decision. Never re-sign an uncertain
operation as a new request, reset its sequence, replay an effect or restore
authority from an older snapshot to make an upgrade succeed.

If a format is incompatible, refuse to open it. Preserve the original data and
recovery material. Operators resolve pending work with its matching build and
choose an explicitly supported offline conversion or a separately initialized
installation. A converter requires its own contract and proof; the policy does
not supply one or permit automatic reset. Starting a fresh installation is an
explicit operator action, not an upgrade fallback.

## Completing a cutover

Remove superseded code, public exports, routes, configuration switches, schemas,
fixtures and tests that exist only to support the old definition. Move required
consumers to the current implementation. Preserve regression coverage for
authority, fencing, exact retry, recovery, bounded memory and current permissions;
add rejection cases for incompatible inputs and stored data.

Current guides, exact contracts, examples, generated descriptions and site
navigation document only the supported definition. Git history and dated internal
reviews preserve earlier designs and proof results. Historical passing results
do not qualify the replacement; record newly executed evidence with the cutover.

## Current native definition

The native service, authority, shared client and Station use the paged v1
implementation. Native command and query routes are `/v1/command` and `/v1/query`.
The [native reference](native.md) and [service contract](../../contracts/SERVICE_V1.md)
identify their owning specifications. Retained artifacts from incompatible
builds require the recovery procedure above.

The native contract carries an opaque `definition` identifier in canonical
signed requests and queries, query responses, persisted authority heads and
saved-operation envelopes. Local installation records and the launchers'
installation, candidate and selected-artifact records also require it. The
current identifier is exported as `x-transit.definition` in the
[generated schema](../../contracts/transit-v1.schema.json), from the shared
protocol type. Unsupported identifiers reject; stored heads and saved requests
without one reject before use. Signed bytes from an older definition cannot
authenticate as the current definition.

Generated ABI contracts carry the same identifier. Native SDK loaders compare
it through the ABI definition-check export; port adapters validate the required
definition in their capability response. A missing export or incompatible
capability response fails loading. Replace the identifier whenever an
incompatible wire, ABI or stored framework definition changes, including changes
that retain the same fields but alter their meaning. It is a compatibility token,
not an automatically computed source hash or a substitute for verification.

Table mutation casts carry the full immutable request reference, including the
resource and content commitment. Namespace-only casts are incompatible and
reject. This stored framework contract is covered by the same native definition;
its hard cutover requires matching node, worker, client and SDK builds. Pending
work under an earlier definition requires that earlier build's recovery procedure,
not a replacement reference or automatic data reset.

The local server uses the combined Table query/writer owner and its two-turn
initialization. The current shared definition rejects earlier query-only local
installation records and history. Recover those installations with their matching
build; enabling the new local default does not convert or reset retained state.

Finite query plans carry a mandatory plan-definition identifier and optional
owned output names. Their `FZP1` layout and fingerprints differ from earlier
plans without those fields. The shared native definition covers this stored
framework change. Old standalone plans, saved requests and authority heads
reject; recover accepted work using its matching build before a cutover.

Publication identity includes its domain, namespace and record ID. Domain-aware
keys and 72-byte references replace the prior layouts under the current shared
definition. Native SDK publication actions use the application domain; typed
framework owners use their declared domains. Earlier authority heads, signing
fixtures and saved mutation commands are incompatible. Recover pending work
with its matching build; no fallback decoder, conversion or reset is supplied.
