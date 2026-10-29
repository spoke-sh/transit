# Table checkpoint and outbox

Run [transaction.sql](transaction.sql) one statement at a time in the same Transit
SQL session, using an account authorized to create and mutate these Tables. It
commits application data, a consumer checkpoint and one durable intent together.
Before COMMIT, the updates and their counts are provisional. Another session sees
none of those three changes until the common decision is published. Preserve the
original command token and transaction handle if a commit reply is uncertain.

The application owns the meaning of `position` and `state`: 0 is pending and 1 is
an attempted delivery whose external outcome may be unknown. This example creates
no connector, credentials, automatic dispatcher, Stream or Queue. A dispatcher
must read committed intents under current Table rights and separately check its
current effect permission. It must not dispatch from replay or aborted work.
Record an attempt before external I/O; a missing remote response remains unknown
until the connector policy reconciles it. Database commit does not prove external
success or make repeating the external action safe.

The installed transaction fixture consumes this exact SQL file, loses the commit
reply, verifies all three public values and repeats the original COMMIT token.
It separately exercises aborted intent exclusion and an application-owned fake
dispatcher with denied/replay gates and an unknown remote outcome. That policy
fixture does not qualify a real connector or exactly-once delivery.

Native input acknowledgments, KV/Document mutations and Stream/Queue settlements
cannot participate in this Table transaction. Their participant categories are
reserved in the shared envelope and reject until their owning contracts execute.
See [transactions](../../docs/handbook/reference/sql/transactions.md) and
[connectors](../../docs/handbook/reference/connectors.md).
