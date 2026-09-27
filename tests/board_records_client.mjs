import { readFileSync } from "node:fs";
import assert from "node:assert/strict";
import { RecordsResponse as validateRecords } from "../packages/ts/transit-board-client/src/validators.js";
const pages = JSON.parse(readFileSync(0, "utf8"));
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
