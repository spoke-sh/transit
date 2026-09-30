# Application declarations

The application compiler accepts `CREATE INTERFACE`, `CREATE THEME`,
`CREATE SCREEN`, `CREATE BINDING` and `CREATE ACTION` as one complete interface
definition. These statements use the separate
[Application.g4 grammar](../../../contracts/application/Application.g4), not the
query console's `SELECT` grammar. Parsing, formatting and generating a module
perform no publication, query submission, grant change or effect dispatch.

## Program syntax

```text
CREATE INTERFACE name WITH (option = value [, ...]);
CREATE THEME interface_name.member_name WITH (option = value [, ...]);
CREATE SCREEN interface_name.member_name WITH (option = value [, ...]);
CREATE BINDING interface_name.member_name WITH (option = value [, ...]);
CREATE ACTION interface_name.member_name WITH (option = value [, ...]);
value := 'text' | unsigned_integer
```

The interface declaration comes first, followed by its members. Every declaration
requires a semicolon and a nonempty option list. All member prefixes must match
the interface name. Forward references resolve against the complete definition;
a member is not an independently applied command.

Unquoted ASCII identifiers fold to lowercase; double quotes preserve case.
Strings escape a single quote by doubling it. Integers use canonical unsigned
decimal digits without leading zeros, except `0` itself. Option values are
strings or integers, not booleans, `NULL`, expressions or `SECRET` references.
Line and nested block comments are accepted; nesting is bounded to 16 levels.

The tables below list required SQL options. Defaults on native model fields do
not make those options optional in the SQL compiler. Unknown, duplicate, missing
or incorrectly typed options reject the complete program.

## CREATE INTERFACE

Declares the interface identity and the initial screen and theme.

| Option | Value |
| --- | --- |
| `realm` | Positive native identity within the protocol counter range |
| `revision` | Positive full-width u64 interface revision |
| `components` | Supported component contract version: `1` |
| `entry` | String naming a declared screen |
| `theme` | String naming a declared theme |

The revision describes the definition. Publishing still requires an authorized,
conditional proposal; changing this integer cannot bypass the publication owner.

## CREATE THEME

Declares a static presentation variant. Its only option is `density`, with string
value `'comfortable'` or `'compact'`. A definition contains one or two themes.
The statement cannot load CSS, JavaScript or a remote theme artifact.

## CREATE SCREEN

Declares a route and its renderer/binding pair.

| Option | Value |
| --- | --- |
| `path` | Unique absolute route string, at most 128 bytes |
| `label` | Nonempty display string, at most 128 bytes |
| `area` | `'workspace'` or `'operations'` |
| `renderer` | `'atlas'`, `'worksheet'`, `'records'`, `'activity'`, `'definition'`, `'operations'` or `'work_items'` |
| `binding` | String naming a compatible declared binding |

Worksheet and work-item renderers require query bindings; the other renderers
require compatible inspection projections. Paths use letters, digits, `/`, `-`
and `_`, with no `//`. `/api`, `/assets`, `/health`, `/openapi`, `/processes` and
`/recovery`, including their children, are reserved. The
[application contract](../../../contracts/APPLICATION_V1.md#declared-route-and-query-binding-acquisition)
owns routing and source acquisition rules.

## CREATE BINDING

Declares one source of inspection data, a finite query, or an explicit command.
`kind` selects the required options:

| `kind` | Other required options |
| --- | --- |
| `'inspection'` | `projection`: `'atlas'`, `'resources'`, `'processes'`, `'records'`, `'capabilities'` or `'activity'`; `page_budget`: `1` |
| `'query'` | `resource`: native identity; `source`: declared source name string; `source_kind`: `'table'`, `'kv'` or `'document'`; `schema`: 64 hex digits in a string; `profile`: `'table_v1'` or `'unified_v1'`; `query`: SQL string; `refresh`: `'snapshot'` or `'follow'`; `starts`: integer budget |
| `'command'` | `service`, `target`, `revision`: native identities/counters; `codec`: positive u16 |

The query schema value is the complete `SourceDefinition.fingerprint()` commitment,
including resource and decoder/projection identity. It is not merely a column
schema hash. The compiler checks embedded SQL syntax; source acquisition and the
owning Fuze compiler additionally check authorized source/type compatibility.

Snapshot queries require `starts = 1`. Follow requires a query v1 Table source
and `starts` from 1 through 8. KV/Document Follow rejects, as does a non-Table
source with `table_v1`. A binding supplies no permission or new runtime source.

## CREATE ACTION

Declares a labeled interaction. All three options are required:

| Option | Value |
| --- | --- |
| `label` | Nonempty display string, at most 128 bytes |
| `kind` | `'navigate'`, `'follow'` or `'command'` |
| `target` | Local screen name for navigation; compatible binding name for Follow or command |

A Follow target must be a query binding configured for Follow. A command target
must be a command binding. Declaring an action does not invoke it. Actual commands
use their exact service, destination, binding revision and codec under current
authorization.

## Complete example

This complete program can be validated offline. It declares an inspection screen
and navigation action without publishing them:

```sql
CREATE INTERFACE inspector WITH (
  realm = 49, revision = 1, components = 1, entry = 'overview', theme = 'mono'
);
CREATE THEME inspector.mono WITH (density = 'comfortable');
CREATE BINDING inspector.catalog WITH (
  kind = 'inspection', projection = 'atlas', page_budget = 1
);
CREATE SCREEN inspector.overview WITH (
  path = '/overview', label = 'Overview', area = 'workspace',
  renderer = 'atlas', binding = 'catalog'
);
CREATE ACTION inspector.open WITH (
  label = 'Open overview', kind = 'navigate', target = 'overview'
);
```

Save the program as `interface.sql`, then use the repository's
[offline compiler](../../../packages/zig/transit-station-app/README.md):

```sh
nix develop
zig build transit-app
zig-out/bin/transit-app parse interface.sql
zig-out/bin/transit-app module interface.sql
```

`parse` returns the validated model; `module` emits a TypeScript proposal module.
`transit-app format interface.json` validates a model and emits canonical SQL.
Canonical output preserves semantic values, not comments or original formatting.

## Bounds, validation and publication

A definition is at most 64 KiB of UTF-8, with identifiers up to 64 bytes, up to
two themes and sixteen each of screens, bindings and actions. It requires at
least one theme and screen. Embedded SQL is at most 4096 bytes and retains the
query compiler's own identifier/literal bounds.

Validation rejects duplicate member names or paths, dangling references,
unsupported component versions, incompatible renderers/actions and unsupported
source/refresh combinations. Structural JSON validity alone is insufficient.
All semantic checks complete before a definition can be published.

Publication is a separate reviewed operation with current operator authority,
an exact body and an expected active revision. An accepted-but-lost reply requires
reconciliation of that same proposal. Interface publication does not install code,
migrate data or grant rights. See [application definitions](../applications.md)
and the [application v1 contract](../../../contracts/APPLICATION_V1.md).
