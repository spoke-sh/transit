// Consume an actual Board response using the same generated runtime validator.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { Response as validate } from '../../../packages/ts/transit-board-client/src/validators.js';
const value = JSON.parse(readFileSync(0, 'utf8'));
assert(validate(value));
for (const mutate of [
  copy => { copy.observation.realm = 9007199254740992; },
  copy => { copy.observation.processes.pop(); },
  copy => { copy.observation.processes[0].state = 'not-hex'; },
  copy => { delete copy.observation.cut; },
  copy => { copy.secret = 'unexpected'; },
]) {
  const copy = structuredClone(value);
  mutate(copy);
  assert(!validate(copy));
}
console.log('Generated Board client validates actual Zig responses and rejects malformed identities/values.');
