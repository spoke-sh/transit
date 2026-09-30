"""Independent v2 binary fixtures and Arrow through native and local port APIs."""
import copy
import ctypes as c
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile

import pyarrow as pa

ROOT = Path(__file__).resolve().parents[1]


def arrow_fixture():
    types = dict(int64=pa.int64(), uint64=pa.uint64(), float64=pa.float64(), boolean=pa.bool_(), utf8=pa.string(), binary=pa.binary())
    values = dict(int64=-(2**63), uint64=2**64-1, float64=-0.0, boolean=False, utf8='café é 東京🙂', binary=b'\0\xff\x80')
    scalar = dict(int64={'int64': str(-(2**63))}, uint64={'uint64': str(2**64-1)}, float64={'float_bits': struct.pack('<d', -0.0).hex()},
                  boolean={'boolean': False}, utf8={'utf8': values['utf8']}, binary={'binary': values['binary'].hex()})
    fields, columns = [], []
    rows = [{} for _ in range(5)]
    expected_rows = [[] for _ in range(5)]
    for tag, (name, datatype) in enumerate(types.items(), 1):
        alt = pa.struct([pa.field('counter', pa.uint64(), nullable=False), pa.field('replica', pa.uint64(), nullable=False),
            pa.field('state', pa.uint8(), nullable=False), pa.field('kind', pa.uint8(), nullable=False), pa.field('value', datatype)])
        fields.append(pa.field(name, pa.struct([pa.field('state', pa.uint8(), nullable=False), pa.field('kind', pa.uint8(), nullable=False),
            pa.field('value', datatype), pa.field('alternatives', pa.list_(pa.field('item', alt, nullable=False)), nullable=False)]), nullable=False))
        columns.append(dict(name=name, type=name))
        for state in range(5):
            rows[state][name] = dict(state=state, kind=[0, 7, 8, tag, 0][state], value=values[name] if state == 3 else None, alternatives=[])
        rows[4][name]['alternatives'] = [dict(counter=2**64-1, replica=1, state=3, kind=tag, value=values[name]),
            dict(counter=2**64-1, replica=2, state=1, kind=7, value=None)]
        wanted = [{'missing': {}}, {'null': {}}, {'type_error': 'map'}, {'value': scalar[name]}, {'conflict': [
            dict(counter=str(2**64-1), replica='1', value={'value': scalar[name]}),
            dict(counter=str(2**64-1), replica='2', value={'null': {}})]}]
        for target, cell in zip(expected_rows, wanted, strict=True): target.append(cell)

    def ipc(data):
        sink = pa.BufferOutputStream()
        with pa.ipc.new_stream(sink, pa.schema(fields)) as writer:
            writer.write_batch(pa.RecordBatch.from_pylist(data, schema=pa.schema(fields)))
        return sink.getvalue().to_pybytes().hex()

    return columns, rows, expected_rows, ipc


def run(host, library):
    native = c.CDLL(str(Path(library).resolve()))
    native.station_unified_query_codec.argtypes = [c.c_char_p, c.c_size_t, c.POINTER(c.c_void_p)]
    native.station_unified_query_codec.restype = c.c_uint32
    native.station_buffer_data.argtypes = [c.c_void_p]
    native.station_buffer_data.restype = c.c_void_p
    native.station_buffer_size.argtypes = [c.c_void_p]
    native.station_buffer_size.restype = c.c_size_t
    native.station_buffer_destroy.argtypes = [c.c_void_p]
    native.station_buffer_destroy.restype = None

    def call(action):
        data = json.dumps(action, ensure_ascii=False).encode()
        pointer = c.c_void_p()
        status = native.station_unified_query_codec(data, len(data), c.byref(pointer))
        try:
            value = json.loads(c.string_at(native.station_buffer_data(pointer), native.station_buffer_size(pointer))) if pointer.value else None
            return dict(status=status, value=value)
        finally:
            native.station_buffer_destroy(pointer)

    def project(name, mode):
        return dict(column=dict(name=name, type='utf8'), path=[name], mode=mode)

    sources = [dict(resource=7, source=dict(kv=dict(prefix=b'data/'.hex(), key=dict(type='binary'), value=dict(type='uint64')))),
        dict(resource=7, source=dict(table=dict(id=9, names=['id', 'label'], value_type='utf8'))),
        dict(resource=7, source=dict(document=dict(reference=dict(resource=7, document=str(2**64-1), epoch='3', type_revision=1, revision='42'),
            projections=[project('title', 'scalar'), project('body', 'text')])))]
    fixtures = json.loads((ROOT / 'packages/zig/transit-query/src/fixtures/bundles.json').read_text())
    definitions = json.loads((ROOT / 'packages/zig/transit-query/src/fixtures/sources.json').read_text())
    actions, expected = [], []

    def check(action, value=None, valid=True):
        result = call(action)
        assert (result['status'] == 0) == valid, (action, result)
        if value is not None: assert result['value'] == value, (result, value)
        actions.append(action)
        expected.append(result)
        return result['value']

    for index, source in enumerate(sources):
        plan = dict(projection=[1, 0], limit=str(2**64-1), predicate=dict(compare=dict(column=1, op='ne', value={'uint64': str(2**64-1)} if index == 0 else {'utf8': 'x'*512})))
        bundle = dict(source=source, plan=plan, limits=dict(pages='1000', segments='500', result_bytes='1048576'))
        prepared = check({'prepare': bundle})['prepared']
        fixture = fixtures[index]
        assert prepared['bytes'] == fixture['wire_hex']
        reference = bytes.fromhex(fixture['reference_hex'])
        assert prepared['spec'] == dict(format=0x31425155, length=len(bytes.fromhex(fixture['wire_hex'])), digest=list(reference[-32:]))
        decoded = check({'decode': fixture['wire_hex']})['bundle']
        assert check({'prepare': decoded})['prepared'] == prepared
        declared = check({'source': source})['source']
        assert declared['bytes'] == definitions[index]['wire_hex']
        assert bytes(declared['digest']).hex() == definitions[index]['digest']
        changed = copy.deepcopy(bundle)
        changed['plan']['version'] = 99
        check({'prepare': changed}, valid=False)
        check({'decode': fixture['wire_hex'][:-2]}, valid=False)
        check({'decode': fixture['wire_hex'] + '00'}, valid=False)
    invalid = copy.deepcopy(sources[0])
    invalid['source']['kv']['value']['version'] = 2
    check({'source': invalid}, valid=False)
    for value in ('01', '-1', str(2**64)):
        invalid = copy.deepcopy(bundle)
        invalid['limits']['pages'] = value
        check({'prepare': invalid}, valid=False)

    columns, rows, expected_rows, ipc = arrow_fixture()
    for data, wanted in ((rows, expected_rows), ([], [])):
        check({'inspect_arrow': dict(columns=columns, rows=len(data), ipc=ipc(data))}, {'rows': wanted})
    bad = copy.deepcopy(rows)
    bad[0]['int64']['value'] = 1
    check({'inspect_arrow': dict(columns=columns, rows=5, ipc=ipc(bad))}, valid=False)
    with tempfile.TemporaryDirectory(prefix='transit-unified-codec-') as directory:
        config = Path(directory) / 'local.json'
        config.write_text(json.dumps({'local_codec': True}))
        process = subprocess.run([host, str(config)], input=''.join(json.dumps({'unified_query_codec': action})+'\n' for action in actions),
            text=True, capture_output=True, timeout=30, check=True)
        actual = [json.loads(line) for line in process.stdout.splitlines()]
        assert actual == expected, (actual, expected)
    print(f'Unified native/port codecs: {len(actions)} shared cases; three independent bundles, six Arrow types, five cell states, full-width values, Unicode and malformed rejection passed')


if __name__ == '__main__':
    run(*sys.argv[1:])
