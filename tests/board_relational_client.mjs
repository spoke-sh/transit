import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { RelationalResponse } from '../packages/ts/transit-board-client/src/validators.js';
const responses = JSON.parse(readFileSync(process.argv[2], 'utf8'));
for (const response of responses) assert(RelationalResponse(response), JSON.stringify(RelationalResponse.errors));
const page = structuredClone(responses.find(v => v.query?.page?.row));
page.query.page.row.cells[1] = {value:{atom:{unsigned:18446744073709551615}}};
assert(!RelationalResponse(page), 'Numeric JSON cannot replace the exact integer string');
console.log('Generated Board relational validator accepts real profile/plan/pages and rejects lossy integers.');
