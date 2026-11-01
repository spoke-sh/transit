"""Independent exact fixtures across native and port ownership boundaries."""
from runner.paths import ROOT
import copy
import ctypes as c
import hashlib
import json
from pathlib import Path
import select
import struct
import subprocess
import sys
import tempfile
import jsonschema
from query.logical.fuze_types import DEFINITION
from query.files.fuze_file_query import descriptor, cell_bytes
from query.arrow.fuze_logical_arrow import recursive_cases, read_stream, arrow_cell



class Native:
    def __init__(self, library):
        self.api = api = c.CDLL(str(Path(library).resolve()))
        api.station_logical_codec.argtypes = [c.c_void_p, c.c_size_t, c.POINTER(c.c_void_p)]
        api.station_logical_codec.restype = c.c_uint32
        api.station_buffer_data.argtypes = [c.c_void_p]
        api.station_buffer_data.restype = c.c_void_p
        api.station_buffer_size.argtypes = [c.c_void_p]
        api.station_buffer_size.restype = c.c_size_t
        api.station_buffer_destroy.argtypes = [c.c_void_p]

    def call(self, action, *, invalid=False):
        raw = json.dumps(action).encode()
        request = c.create_string_buffer(raw)
        output = c.c_void_p()
        status = self.api.station_logical_codec(request, len(raw), c.byref(output))
        # Invalidate every borrowed input byte before accessing the returned owner.
        c.memset(request, 0xCC, len(raw))
        try:
            owned = c.string_at(self.api.station_buffer_data(output), self.api.station_buffer_size(output)) if output else b'null'
        finally:
            self.api.station_buffer_destroy(output)
        assert bool(status) == invalid, (status, owned)
        return json.loads(owned)


class Port:
    def __init__(self, host, root):
        config = root / 'codec.json'
        config.write_text('{"local_codec":true}')
        self.child = subprocess.Popen([str(Path(host).resolve()), str(config)], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)

    def call(self, action, *, invalid=False):
        self.child.stdin.write(json.dumps({'logical_codec': action}) + '\n')
        self.child.stdin.flush()
        assert select.select([self.child.stdout], [], [], 30)[0], 'logical port timed out'
        value = json.loads(self.child.stdout.readline())
        assert bool(value['status']) == invalid, value
        return value['value']

    def close(self):
        try:
            self.child.stdin.write('{"shutdown":{}}\n'); self.child.stdin.flush()
            assert self.child.wait(timeout=10) == 0
        finally:
            if self.child.poll() is None: self.child.kill(); self.child.wait(timeout=10)
            self.child.stdin.close(); self.child.stdout.close()


def check(caller, *, capabilities=True):
    validators = {}
    for name in ('type', 'value'):
        schema = json.loads((ROOT / f'packages/zig/transit-fuze/api/logical-{name}.schema.json').read_text())
        jsonschema.Draft202012Validator.check_schema(schema)
        validators[name] = jsonschema.Draft202012Validator(schema)
    if capabilities:
        caps = caller.call({'capabilities': {}})['capabilities']
        assert caps['definition'] == DEFINITION.decode() and caps['logical_json'] and not caps['durable_file_queries']
    count = 0
    documents = []
    for case in json.loads((ROOT / 'packages/zig/transit-fuze/src/fixtures/types.json').read_text())['cases']:
        kind = case['kind']; raw_type = bytes.fromhex(case['type_hex'])
        params = ({'precision': raw_type[-2], 'scale': raw_type[-1]} if kind == 'decimal' else 'utc') if kind in ('decimal', 'timestamp') else {}
        typ = json.dumps({'definition': DEFINITION.decode(), 'type': {kind: params}})
        result = caller.call({'type_json': typ})['type']
        assert result['bytes'] == case['type_hex']
        assert result['fingerprint'] == hashlib.sha256(raw_type).hexdigest()
        validators['type'].validate(json.loads(result['json']))
        assert caller.call({'type_bytes': result['bytes']})['type'] == result
        value = caller.call({'bind': {'type_json': typ, 'literal': case['literal']}})['value']
        assert value['bytes'] == case['value_hex'], case['name']
        assert caller.call({'hash': value['json']})['hash'] == case['logical_hash'], case['name']
        documents.append((json.loads(value['json']), value['bytes']))
    for typ, cell in recursive_cases():
        for variant in [cell, {'null': {}}, {'missing': {}}, {'type_error': 'utf8'}, {'conflict': [
            {'counter': '9007199254740993', 'replica': '18446744073709551615', 'value': cell},
            {'counter': '18446744073709551615', 'replica': '1', 'value': {'null': {}}}]}]:
            doc = {'definition': DEFINITION.decode(), 'field': {'name': 'value', 'type': typ, 'nullable': True, 'optional': True}, 'cell': variant}
            desc = descriptor(typ)
            expected = b'FVL1' + struct.pack('<H', len(desc)) + desc + b'\3' + cell_bytes(variant, typ)
            documents.append((doc, expected.hex()))
    for document, expected in documents:
        validators['value'].validate(document)
        value = caller.call({'value_json': json.dumps(document)})['value']
        assert value['bytes'] == expected
        assert caller.call({'value_bytes': expected})['value'] == value
        # Separate returned owners survive later codec calls and port buffers.
        saved = copy.deepcopy(value)
        arrow = caller.call({'arrow': value['json']})['arrow']
        assert value == saved
        _, batches = read_stream(bytes.fromhex(arrow['ipc']))
        assert len(batches) == 1
        typ = document['field']['type']
        assert arrow_cell(batches[0].column(0), 0, typ) == cell_bytes(document['cell'], typ)
        for bad in [expected[:-2], expected + '00', expected.upper()]:
            caller.call({'value_bytes': bad}, invalid=True)
        for definition in [None, 'foreign']:
            bad = copy.deepcopy(document)
            if definition is None: del bad['definition']
            else: bad['definition'] = definition
            assert not validators['value'].is_valid(bad)
            caller.call({'value_json': json.dumps(bad)}, invalid=True)
        count += 1
    for case in json.loads((ROOT / 'packages/zig/transit-fuze/src/fixtures/companion-values.json').read_text())['cases']:
        if case['error'] is None:
            continue
        document = dict(definition=DEFINITION.decode(), field=case['field'], cell=case['cell'])
        caller.call({'value_json': json.dumps(document)}, invalid=True)
        caller.call({'value_bytes': case['value_hex']}, invalid=True)
    # Decimal rescaling and full-domain casts share Zig semantics.
    decimal = lambda scale: json.dumps({'definition': DEFINITION.decode(), 'type': {'decimal': {'precision': 8, 'scale': scale}}})
    first = caller.call({'bind': {'type_json': decimal(3), 'literal': '1.255'}})['value']['json']
    cast = {'value_json': first, 'type_json': decimal(2)}
    caller.call({'cast': cast}, invalid=True)
    rounded = caller.call({'cast': {**cast, 'rounding': 'nearest_even'}})['value']['json']
    assert json.loads(rounded)['cell']['value']['atom']['decimal'] == '126'
    assert caller.call({'equal': {'left_json': rounded, 'right_json': rounded}}) == {'equal': True}
    assert caller.call({'order': {'left_json': rounded, 'right_json': rounded}}) == {'order': 'eq'}
    return count


if __name__ == '__main__':
    with tempfile.TemporaryDirectory(prefix='transit-logical-codec-') as directory:
        native = Native(sys.argv[1]); port = Port(sys.argv[2], Path(directory))
        try:
            assert check(native) == check(port) == 236
        finally:
            port.close()
    print('Logical codecs: 236 independent scalar/companion/recursive/state fixtures through C ABI and port, exact binary/hash/Arrow, generated schemas, rejected definitions and owned buffers passed.')
