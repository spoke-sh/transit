# Unified state queries

Import `unified` from `@transit/station` for v1 KV, Table and accepted Document
queries. The existing Table v1 APIs remain available. Public source, plan and
result types are separate from the generated wire schemas; every port request
and response is runtime-validated. Shared Zig owns protocol and query semantics.

```ts
import { unified as q } from "@transit/station";

const source: q.Source = {
  kind: "kv",
  resource,
  prefix: new TextEncoder().encode("events/"),
  key: { type: "binary", version: 1 },
  value: { type: "utf8", version: 1 },
};
const bundle = await q.Bundle.prepare(
  source,
  { projection: [1] },
  {
    pages: 1000n,
    segments: 100n,
    resultBytes: 1_048_576n,
  },
);
```

`q.Client.open(config, credential, connection)` opens one owned native port.
Select `native_v1`; supply the endpoint, explicit credential and a `q.Connection`
binding source/requester processes and resources in one realm. The caller needs
no activation or writer ownership. `nativeHost` overrides installed discovery.
Import starts no process or credential access. Call `close()` in `finally`;
cleanup joins the current operation. Overlapping operations return `Busy`.

`describe(source)` checks current policy and limits. `prepareNext(namespace,
bundle)` returns one `Prepared` command. Persist its opaque `data` string before
`submit`. The returned `AdmissionReceipt.position` is input admission, not query
completion. Wait until `observe(position)` reports committed before preparing
again. A rejected observation reports the durable behavior rejection. When
preparation returns undefined, inspect `status(namespace)` for the terminal or
admitted state.

`q.Uncertain` carries the identical `prepared` value after unconfirmed dispatch.
Retain it across process loss and resubmit unchanged on a new client. Do not parse
and re-encode signed material: embedded full-width numbers must remain opaque.
`prepareCancel`, `prepareRetire` and `prepareCollect` use the same explicit
persistence/submission/observation sequence. Abandoning a Promise does not cancel
durable work.

For a complete query, `page(namespace, cursor)` returns an owned IPC segment,
typed manifest source/schema/plan commitments and optional continuation. The
cursor preserves verification progress and never grants permission. Save it only
with its exact connection/namespace. Reads recheck current access and lifecycle;
failure leaves the old cursor unchanged. Undefined next means complete verified
coverage, not merely an empty source page.

`Page.decode()` and `decodeArrow()` use shared Zig and preserve five cell states,
ordered conflict IDs, bigint values, binary, Unicode and negative zero. For the
pinned optional Apache Arrow 21.2.0 integration, `unifiedToArrow(page)` from
`@transit/station/arrow` returns the nested schema without flattening states into
nullable values. Byte getters copy owned data; native temporary buffers cannot
escape. Bundle, column/row, scalar and segment bounds are 16 KiB, eight, 4 KiB
and 64 KiB respectively.

`just bindings::unified-node table` installs fresh package tarballs and runs the
shared codec and signed recovery schedule. `kv` and `document` select the other
sources. See [proof evidence](../../../../tests/README.md) for completed runs.
