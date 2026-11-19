# Modular Queue program fixture with functions, guards and procedures

`OrderId`, `AccountId` and `AuditId` share `BIGINT` representations while
retaining distinct source domain identities across `types.transit`,
`resources.transit`, `helpers.transit`, `workflow.transit` and `build.transit`.
Two explicit resource and Dataflow sets (`*_a` and `*_b`) instantiate the same
modules without sharing durable objects.

`helpers.transit` exercises private and public pure `FUNCTION` declarations,
ordered `GUARD` composition and atomic `PROCEDURE` inlining:

- Private `clean_note`, `tier_window`, `fee_schedule` and `compliance_profile`
  compose into public `valid_amount`, `preserve_order`, `preserve_account`,
  `same_token`, `amount_band`, `risk_label`, `settlement_profile` and
  `format_summary` helpers, expanding each order Dataflow declaration beyond
  4 KiB within the 65,536-byte program bound and 1 MiB SQL statement bound.
- `helpers.same_token(RANDOM_TOKEN(16))` exercises single-evaluation hoisting of
  a multi-use impure call argument before lowering `same_token`.
- Public `verify_account` reads the `accounts` Table, checks nominal `AccountId`
  equality and delegates in lexical order to private `require_supported_tier`
  before checking credit headroom.
- Public `settle_order` binds a local `summary` without colliding with the
  caller's `summary` binding, inserts into `ledger`, and calls private
  `publish_outputs` to append to both `events` (Stream) and `followup` (Queue)
  inside the caller's single atomic block, returning the nominal `OrderId` for a
  caller-side equality check before the post-call rollback guard. A second Dataflow (`modular_dispatch_*`)
  consumes `followup` into `dispatched`.

In pipeline `a`, order `101` commits across `ledger`, `events` and `followup`,
and `modular_dispatch_a` commits into `dispatched`. Order `102` refuses on a
missing account before `settle_order`; orders `103` and `104` refuse on
inactive status and credit headroom in lexical guard order; order `105` fails a
post-call `REQUIRE` after `settle_order`, rolling back the Table insert, Stream
append and Queue append together. Pipeline `b` independently accepts order `201`.

`expected.sql` records the deterministic compiler output, while `oracle.sql` is
independently authored scalar SQL with no hygienic `__t$` bindings, runtime
functions, guards or procedures. Source helpers, visibility and domains are
compile-time abstractions erased before runtime preparation; they grant no
runtime privileges and do not qualify effects, protected values, migrations or
external providers.
