# What is Transit?

Transit is programmable data infrastructure for applications. It stores and
queries tables, key-value data and collaborative documents, and provides durable
execution for transforming data and coordinating work around it.

Its declarative interfaces describe data and computation; its execution system
preserves accepted changes, progress and outcomes across failures.

Start with the data your application needs: its shape, how it changes, what you
want to compute from it, and who may use it. The [data model](../reference/data-model.md)
connects these concerns to their supported interfaces. The
[local quickstart](quickstart.md) takes you from an empty installation to a Table
you define, query and change through the console.

## Describe intent and inspect the result

The question that organizes Transit is:

> Can someone describe the data, computation and policies they need, then inspect
> whether Transit is fulfilling that declaration?

For a Table, that means defining columns, keys and defaults, then inspecting its
published schema and committed rows. For a query, it means identifying its inputs
and computation, then observing a complete result against a specific data basis.
For a maintained result, it also means knowing which input changes it includes
and whether processing has stopped or is still catching up.

These observations have different meanings. A valid definition may still need
publication or activation. An accepted operation may still be running. A complete
result describes the source versions it read; newer input can exist. Current
permissions govern both execution and inspection.

The product direction is:

> Declare your data, the computations that derive from it, and the policies
> governing its use. Transit manages the execution and lifecycle needed to keep
> those definitions useful.

The supported path is most complete for Tables: create and evolve their schemas,
read and change rows, and inspect outcomes through a configured catalog. KV and
Documents have client/service APIs, but their SQL declarations compile offline
without creating objects. Named captured and maintained relational queries have
typed Zig interfaces with explicit host activation and scheduling; SQL view and
subscription declarations are unavailable. See the [capability map](../reference/data-model.md#declarations-and-current-interfaces)
for the boundary between the direction and today's operations.

## Work with data

| Need | Start here |
| --- | --- |
| Store records with typed columns, keys and defaults | [Tables and schema evolution](../reference/tables.md) |
| Store keys and values under an explicit encoding | [KV resources](../reference/state.md) |
| Accept structured edits and collaborative text with explicit conflicts | [Documents](../reference/documents.md) |
| Read, filter, join or aggregate supported sources | [SQL](../reference/sql.md) and [query lifetimes](../reference/data-model.md#choose-a-computation-lifetime) |
| Control access, retention and resource budgets | [Permissions](../reference/security.md) and [retention](../reference/retention.md) |
| Inspect definitions, results and progress | [Observe the lifecycle](../reference/data-model.md#inspect-whether-a-declaration-is-being-fulfilled) |
| Capture external observations or coordinate external actions | [Connectors and recorded outcomes](../reference/connectors.md) |

SQL, language SDKs, HTTP APIs and Board expose different operations over shared
owners and contracts. [Choose an interface](choose-interface.md) for the data
kind, computation lifetime and operations you need. An interface that reads a
source does not necessarily create it or maintain a derived result.

## Durable execution supports the data lifecycle

Transit records accepted mutations and keeps partially staged data private until
its complete successor is published. A reader retains its selected data version
while later writes proceed. After an uncertain write, the original operation's
recorded outcome tells the caller whether it applied. Repeating SQL creates new
work; a lost connection alone does not establish failure.

Custom workers extend this model with application-defined transformations,
validation and coordination. A durable process gives that work an identity,
ordered input and recoverable progress. Its worker can restart without replacing
accepted work. [Processes and turns](../reference/processes.md) explain the commit
mechanism; [build an application](applications.md) explains how to supply your
own worker.

Station provides application behaviors and data owners above the generic kernel.
Fuze executes queries over authorized sources. Board presents observed state,
and connectors record external attempts and outcomes. These components support
the same data and execution boundaries; their [architecture](../reference/architecture.md)
explains the division of responsibilities.

## Continue from a working dataset

1. [Run Transit locally](quickstart.md), define a Table and inspect its schema.
2. Read and change its rows from independent console sessions.
3. Use the [data model](../reference/data-model.md) to choose representations,
   computation lifetimes and policies for your application.
4. Explore [workload recipes across languages](workload-examples.md), then add
   custom execution or connectors where the application needs them.

Retention defaults to unlimited and requires explicit opt-in to expiry. A name,
resource reference or retained snapshot never grants access. The
[verification reference](../reference/verification.md) explains the guarantees
and limits behind the supported operations.
