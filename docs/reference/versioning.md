# Versioning and hard cutovers

Before Transit 1.0, the versioning policy requires one supported definition per
Transit-owned protocol, named **v1**. Breaking changes replace that definition in a hard cutover. There
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

## Implementation boundary

The current implementation still exposes bounded native v2 and growing native v3,
plus Table query v1 and unified query v2. These are the inputs to the hard cutover,
not an exception allowing continued parallel support. Existing versioned guides
and contracts describe those implemented interfaces until their coordinated
replacement lands. This policy alone does not rename a wire format or establish
compatibility with v1 clients.
