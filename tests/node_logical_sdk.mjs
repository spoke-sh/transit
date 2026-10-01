import assert from 'node:assert/strict';
import { createInterface } from 'node:readline';
import { logical } from '@transit/station';

const codec = await logical.Codec.open();
const saved = [];
const hex = bytes => Buffer.from(bytes).toString('hex');
const fromJson = document => logical.Value.fromJson(codec, document);
async function call(action) {
  const [kind, value] = Object.entries(action)[0];
  let result;
  if (kind === 'type_json') result = await logical.Type.fromJson(codec, value);
  else if (kind === 'type_bytes' || kind === 'value_bytes') {
    const bytes = Buffer.from(value, 'hex');
    // Do not let Buffer's forgiving hex parser turn invalid strings into valid input.
    if (hex(bytes) !== value) throw new TypeError('noncanonical hex');
    result = await (kind === 'type_bytes' ? logical.Type : logical.Value).fromBytes(codec, bytes);
    bytes.fill(0xcc);
  } else if (kind === 'value_json') result = await fromJson(value);
  else if (kind === 'bind') result = await logical.Value.bind(codec, await logical.Type.fromJson(codec, value.type_json), value.literal);
  else if (kind === 'cast') result = await (await fromJson(value.value_json)).cast(codec, await logical.Type.fromJson(codec, value.type_json), value.rounding ?? 'reject');
  else if (kind === 'equal' || kind === 'order') return {[kind]: await codec[kind](await fromJson(value.left_json), await fromJson(value.right_json))};
  else if (kind === 'hash') return {hash: hex(await codec.hash(await fromJson(value)))};
  else if (kind === 'arrow') {
    const ipc = await codec.arrow(await fromJson(value));
    saved.push([ipc, hex(ipc)]);
    return {arrow: {ipc: hex(ipc)}};
  } else throw new Error(kind);
  const original = hex(result.bytes);
  result.bytes.fill(0xcc);
  assert.equal(hex(result.bytes), original);
  saved.push([result, original]);
  if (kind.startsWith('type_')) return {type: {json: result.json, bytes: original, fingerprint: hex(result.fingerprint), equality: result.equality, ordering: result.ordering}};
  return {value: {json: result.json, bytes: original}};
}
try {
  for await (const line of createInterface({input: process.stdin})) {
    const action = JSON.parse(line);
    if ('close' in action) break;
    try { console.log(JSON.stringify({status: 0, value: await call(action)})); }
    catch (error) { console.log(JSON.stringify({status: 1, value: error.name})); }
  }
} finally { await codec.close(); }
for (const [value, expected] of saved) assert.equal(hex(value instanceof Uint8Array ? value : value.bytes), expected);
await assert.rejects(logical.Type.fromJson(codec, '{}'));
console.log('{"closed":true}');
