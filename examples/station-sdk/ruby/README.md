# Ruby public SDK examples

Installable counter/requester and Table/query handlers use the
[shared codecs](../README.md), Ruby pattern matching and value objects. Native
framework transitions remain behind the public SDK. The installed
`transit-ruby-counter CONFIG service --commits 1` (or `requester`) reads explicit
growing-profile configuration and requires provisioned ownership, grants and a
`data` association.

Build/install through `just bindings::ruby-build` in `nix develop .#bindings`,
then `gem install --local --user-install .cache/bindings/ruby/*.gem`.
`require 'transit/sdk_examples'` exposes `Transit::Examples` without starting work.
CONFIG contains `url`, `profile: "native_v1"`, `realm`, `pid`, `principal`,
`generation`, `seed_file` and `peer`. The counter CLI observes a configured number
of confirmed turns and closes through the runner block. It selects fresh-owner
recovery; applications needing exact crash retry supply persistence hooks.

`TableService` and `QueryRequester` are library examples. The requester takes a
block consuming owned original IPC segments. Its side effects need their own
replay/idempotency policy. Full-width integers and nullable rows stay exact.

The Table service follows the [durable FIFO contract](../TABLES.md), with four
typed columns, text and list defaults, explicit creation quotas, and queued
insert/update/delete commands. Each self continuation advances the original
mutation by one bounded step. Terminal outcomes and queue progress commit within
four writes; queries receive NotReady while accepted work remains pending.

`just bindings::ruby-sdk-test` installs all five gems outside the repository,
checks shared codec fixtures, invokes both CLI roles across ownership replacement,
and proves retained Tables and six query segments with independent PyArrow after
runner disposal. Read the [SDK guide](../../../packages/ruby/transit-station/docs/USAGE.md)
and [test evidence](../../../tests/README.md).
