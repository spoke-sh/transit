"""Installed public Python values; no private/native imports."""
import json
import sys
from transit_station.logical import Codec

codec = Codec()
saved = []


def call(action):
    kind, value = next(iter(action.items()))
    if kind in ('type_json', 'value_json'):
        result = getattr(codec, kind)(value)
    elif kind in ('type_bytes', 'value_bytes'):
        data = bytes.fromhex(value)
        if data.hex() != value: raise ValueError('noncanonical hex')
        result = getattr(codec, kind)(data)
    elif kind == 'bind': result = codec.bind(codec.type_json(value['type_json']), value['literal'])
    elif kind == 'cast': result = codec.cast(codec.value_json(value['value_json']), codec.type_json(value['type_json']), rounding=value.get('rounding', 'reject'))
    elif kind in ('equal', 'order'):
        return {kind: getattr(codec, kind)(codec.value_json(value['left_json']), codec.value_json(value['right_json']))}
    elif kind == 'hash': return {'hash': codec.hash(codec.value_json(value)).hex()}
    elif kind == 'arrow':
        ipc = codec.arrow(codec.value_json(value))
        saved.append((ipc, bytes(ipc)))
        return {'arrow': {'ipc': ipc.hex()}}
    else: raise AssertionError(kind)
    saved.append((result, (result.json, result.bytes)))
    if kind.startswith('type_'):
        return {'type': dict(json=result.json, bytes=result.bytes.hex(), fingerprint=result.fingerprint.hex(), equality=result.equality, ordering=result.ordering)}
    return {'value': dict(json=result.json, bytes=result.bytes.hex())}


try:
    for line in sys.stdin:
        action = json.loads(line)
        if 'close' in action: break
        try: output = dict(status=0, value=call(action))
        except Exception as error: output = dict(status=1, value=type(error).__name__)
        print(json.dumps(output), flush=True)
finally:
    codec.close()
for value, snapshot in saved:
    assert (value if isinstance(value, bytes) else (value.json, value.bytes)) == snapshot
try: codec.type_json('{}')
except RuntimeError: pass
else: raise AssertionError('closed codec accepted a call')
print('{"closed":true}', flush=True)
