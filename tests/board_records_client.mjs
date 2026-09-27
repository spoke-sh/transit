import { readFileSync } from "node:fs";
import assert from "node:assert/strict";
import { RecordsResponse as validateRecords, HttpResponse as validateHttp } from "../packages/ts/transit-board-client/src/validators.js";
const { pages, metadata } = JSON.parse(readFileSync(0, "utf8"));
assert(validateHttp(metadata));
const changed = structuredClone(metadata);
changed.terminal.timing.elapsed_ns = Number(changed.terminal.timing.elapsed_ns);
assert(!validateHttp(changed));
const privateValue = structuredClone(metadata);
privateValue.policy.host = "private.test";
assert(!validateHttp(privateValue));
for (const page of pages) {
  assert(validateRecords(page));
  const lens = page.exchanges.find((item) => item !== null);
  if (lens) {
    const detail = Object.values(lens.declaration)[0];
    detail.exchange = Number(detail.exchange);
    assert(!validateRecords(page));
  }
}
console.log("Board records: actual generated models reject numeric exchange identities.");
