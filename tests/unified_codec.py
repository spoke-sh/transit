"""Independent v1 binary fixtures and Arrow through native and local port APIs."""
import copy
import ctypes as c
import hashlib
import json
from pathlib import Path
from fuze_file_query import descriptor, cell_bytes
from fuze_logical_arrow import arrow_cell
import struct
import subprocess
import sys
import tempfile

import pyarrow as pa

ROOT = Path(__file__).resolve().parents[1]


def arrow_fixture(producer):
    types = dict(int64=pa.int64(), uint64=pa.uint64(), float64=pa.float64(), boolean=pa.bool_(), utf8=pa.string(), binary=pa.binary())
    values = dict(int64=-(2**63), uint64=2**64-1, float64=-0.0, boolean=False, utf8='café é 東京🙂', binary=b'\0\xff\x80')
    scalar = dict(int64={'signed': str(-(2**63))}, uint64={'unsigned': str(2**64-1)}, float64={'float_bits': struct.pack('<d', -0.0).hex()},
                  boolean={'boolean': False}, utf8={'utf8': values['utf8']}, binary={'binary': values['binary'].hex()})
    columns = []
    rows = [{} for _ in range(5)]
    expected_rows = [[] for _ in range(5)]
    for tag, name in enumerate(types, 1):
        columns.append(dict(name=name, type={name: {}}, nullable=True, optional=True))
        for state in range(5):
            rows[state][name] = dict(state=state, kind=[0, 0, 25, tag, 0][state], value=values[name] if state == 3 else None, alternatives=[])
        rows[4][name]['alternatives'] = [dict(counter=2**64-1, replica=1, state=3, kind=tag, value=values[name]),
            dict(counter=2**64-1, replica=2, state=1, kind=0, value=None)]
        wanted = [{'missing': {}}, {'null': {}}, {'type_error': 'map'}, {'value': {'atom': scalar[name]}}, {'conflict': [
            dict(counter=str(2**64-1), replica='1', value={'value': {'atom': scalar[name]}}),
            dict(counter=str(2**64-1), replica='2', value={'null': {}})]}]
        for target, cell in zip(expected_rows, wanted, strict=True): target.append(cell)

    def ipc(data):
        # The decoder admits Transit's canonical schema message. Generate that
        # header with the real codec, then independently produce the batch with
        # PyArrow. This also lets malformed state/payload fixtures reach decode.
        with tempfile.TemporaryDirectory(prefix='transit-query-arrow-') as directory:
            path = Path(directory) / 'batch.json'
            path.write_text(json.dumps(dict(columns=columns, rows=expected_rows if data else [])))
            generated = subprocess.run([producer, '--batch', str(path)], capture_output=True, check=True, timeout=30).stdout
        physical = pa.ipc.open_stream(generated).schema
        assert physical.metadata[b'transit.definition'] == b'transit.fuze.logical-arrow.v1.2026-09-30'
        assert physical.metadata[b'transit.logical_schema'] == descriptor({'structure': columns}).hex().encode()
        batches = list(pa.ipc.open_stream(generated))
        assert len(batches) == 1 and batches[0].num_rows == (5 if data else 0)
        for i, row in enumerate(expected_rows if data else []):
            for j, value in enumerate(row):
                assert arrow_cell(batches[0].column(j), i, columns[j]['type']) == cell_bytes(value, columns[j]['type'])
        sink = pa.BufferOutputStream()
        with pa.ipc.new_stream(sink, physical) as writer:
            writer.write_batch(pa.RecordBatch.from_pylist(data, schema=physical))
        foreign = sink.getvalue().to_pybytes()
        def prefix_length(value):
            assert value[:4] == b'\xff' * 4
            return 8 + struct.unpack_from('<I', value, 4)[0]
        return (generated[:prefix_length(generated)] + foreign[prefix_length(foreign):]).hex()

    return columns, rows, expected_rows, ipc


def boolean_bundle_fixtures():
    from unified_contract import current_definition
    types = ['int64', 'uint64', 'float64', 'boolean', 'utf8', 'binary']
    literals = [
        {'signed': str(-(2**63))}, {'unsigned': str(2**64-1)},
        {'float_bits': struct.pack('<d', -0.0).hex()}, {'boolean': True},
        {'utf8': 'café é 🙂'}, {'binary': '00ff80'}, {'utf8': 'x'*512},
    ]
    names = ['signed-min', 'unsigned-max', 'negative-zero', 'boolean', 'unicode', 'binary', 'larger-plan', 'all-and-not-null', 'max64']
    rows = []
    for index, name in enumerate(names):
        tag = [1, 2, 3, 4, 5, 6, 5, 1, 1][index]
        source = dict(resource=7, source=dict(kv=dict(prefix='', key=dict(type=types[tag-1]), value=dict(type='uint64'))))
        source_bytes = b'UQS1' + current_definition() + struct.pack('<QB', 7, 1) + bytes([0, 1, tag, 1, 2])
        schema = {'structure': [dict(name='key', type={types[tag-1]: {}}, nullable=True, optional=True), dict(name='value', type={'uint64': {}}, nullable=True, optional=True)]}
        if index < 7:
            literal = literals[index]
            program = [{'atom': {'compare': {'column': 0, 'op': 'eq', 'value': literal}}},
                       {'negate': {}}, {'atom': {'state': {'column': 0, 'value': 'null'}}}, {'disjunction': {}}]
            cell = cell_bytes({'value': {'atom': literal}}, schema['structure'][0]['type'])
            code = bytes([0, 2, 0, 0]) + struct.pack('<H', len(cell)) + cell + bytes([1, 0, 1, 0, 1, 3])
        elif index == 7:
            program = [{'atom': {'all': {}}}, {'atom': {'state': {'column': 0, 'value': 'null'}}}, {'negate': {}}, {'conjunction': {}}]
            code = bytes([0, 0, 0, 1, 0, 1, 1, 2])
        else:
            program = [{'atom': {'all': {}}}] + [{'negate': {}}]*63
            code = bytes([0, 0]) + bytes([1])*63
        plan_bytes = (b'FQP1' + hashlib.sha256(b'transit.fuze.logical-plan.v1:bound-schema:ordered-predicates:output-names').digest() +
                      hashlib.sha256(b'transit.query.source.v1\0' + source_bytes).digest() + hashlib.sha256(descriptor(schema)).digest() +
                      bytes([0, 1, 0, 0, 0]) + struct.pack('<Q', 0) + bytes([3, len(program)]) + code)
        wire = b'UQB1' + current_definition() + struct.pack('<HHQQQ', len(source_bytes), len(plan_bytes), 1000, 500, 1048576) + source_bytes + plan_bytes
        digest = hashlib.sha256(b'transit.station.publication.v1\0' + struct.pack('<II', 0x31425155, len(wire))).digest()
        for chunk_index, offset in enumerate(range(0, len(wire), 256)):
            chunk = wire[offset:offset+256]
            digest = hashlib.sha256(b'\1' + digest + struct.pack('<IH', chunk_index, len(chunk)) + chunk).digest()
        rows.append(dict(name=name, type=tag, bundle=dict(source=source, plan=dict(projection=[0], predicate=dict(program=program)),
                         limits=dict(pages='1000', segments='500', result_bytes='1048576')), wire_hex=wire.hex(),
                         spec=dict(format=0x31425155, length=len(wire), digest=list(digest))))
    return rows


def run(host, library, producer):
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
        dict(resource=7, source=dict(table=dict(scope=dict(realm=1, resource=7, catalog='9'), owner=3, object='9', metadata=dict(id='1', spec=dict(format=0x54434d01, length=200, digest=[1]*32)), row_type=dict(structure=[dict(name='id', type={'int64': {}}), dict(name='label', type={'utf8': {}}, nullable=True)])))),
        dict(resource=7, source=dict(document=dict(reference=dict(resource=7, document=str(2**64-1), epoch='3', type_revision=1, revision='42'),
            projections=[project('title', 'scalar'), project('body', 'text')])))]
    fixtures = json.loads((ROOT / 'packages/zig/transit-query/src/fixtures/bundles.json').read_text())
    definitions = json.loads((ROOT / 'packages/zig/transit-query/src/fixtures/sources.json').read_text())
    actions, expected = [], []

    def check(action, value=None, valid=True):
        result = call(action)
        assert (result['status'] == 0) == valid, (next(iter(action)), result)
        if value is not None: assert result['value'] == value, (result, value)
        actions.append(action)
        expected.append(result)
        return result['value']

    for index, source in enumerate(sources):
        plan = dict(projection=[1, 0], limit=str(2**64-1), predicate=dict(compare=dict(column=1, op='ne', value={'unsigned': str(2**64-1)} if index == 0 else {'utf8': 'x'*512})))
        bundle = dict(source=source, plan=plan, limits=dict(pages='1000', segments='500', result_bytes='1048576'))
        prepared = check({'prepare': bundle})['prepared']
        fixture = fixtures[index]
        assert prepared['bytes'] == fixture['wire_hex']
        reference = bytes.fromhex(fixture['reference_hex'])
        assert prepared['spec'] == dict(format=0x31425155, length=len(bytes.fromhex(fixture['wire_hex'])), digest=list(reference[-32:]))
        decoded = check({'decode': fixture['wire_hex']})['bundle']
        assert check({'prepare': decoded})['prepared'] == prepared
        named = copy.deepcopy(bundle)
        named['plan']['output_names'] = ['Result', None]
        named_prepared = check({'prepare': named})['prepared']
        assert named_prepared['bytes'] == fixture['named_wire_hex']
        named_decoded = check({'decode': fixture['named_wire_hex']})['bundle']
        assert named_decoded['plan']['output_names'] == ['Result', None]
        assert check({'prepare': named_decoded})['prepared'] == named_prepared
        for names in ([], ['Result'], ['Result', None, None], ['', None], ['nul\0name', None]):
            invalid_names = copy.deepcopy(named)
            invalid_names['plan']['output_names'] = names
            check({'prepare': invalid_names}, valid=False)
        counted = copy.deepcopy(bundle)
        counted['plan'] = dict(projection=[1], aggregate='count_values', output_names=['present'])
        counted_prepared = check({'prepare': counted})['prepared']
        assert counted_prepared['bytes'] == fixture['counted_wire_hex']
        counted_decoded = check({'decode': counted_prepared['bytes']})['bundle']
        assert counted_decoded['plan']['aggregate'] == 'count_values'
        assert counted_decoded['plan']['projection'] == [1]
        assert check({'prepare': counted_decoded})['prepared'] == counted_prepared
        # A matching version label cannot make an old accepted plan compatible.
        old = bytearray.fromhex(counted_prepared['bytes'])
        plan_offset = old.index(b'FQP1')
        old[plan_offset+4:plan_offset+36] = bytes.fromhex('58ae72e1f9a4b589536e5a0d262d6e6aebcc2fab40698b4bfea6833281ad9f3c')
        check({'decode': old.hex()}, valid=False)
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

    # Independent schema-bound FQP1 bytes, reconstructed UQB1 framing and publication
    # commitment. Both real transports must preserve the exact neutral program.
    for fixture in boolean_bundle_fixtures():
        bundle = fixture['bundle']
        wire = bytes.fromhex(fixture['wire_hex'])
        source_length = struct.unpack_from('<H', wire, 36)[0]
        prepared = check({'prepare': bundle})['prepared']
        assert prepared == dict(bytes=wire.hex(), spec=fixture['spec'])
        decoded = check({'decode': wire.hex()})['bundle']
        assert decoded['plan']['predicate'] == bundle['plan']['predicate']
        assert check({'prepare': decoded})['prepared'] == prepared
        old = bytearray(wire)
        old[64+source_length+4:64+source_length+36] = bytes.fromhex('58ae72e1f9a4b589536e5a0d262d6e6aebcc2fab40698b4bfea6833281ad9f3c')
        check({'decode': old.hex()}, valid=False)

    for program in ([], [{'negate': {}}], [{'atom': {'all': {}}}]*2,
                    [{'atom': {'all': {}}}] + [{'negate': {}}]*64,
                    [{'atom': {'program': [{'atom': {'all': {}}}]}}],
                    [{'atom': {'state': {'column': 8, 'value': 'null'}}}],
                    [{'atom': {'all': {}}}, {'atom': {'compare': {'column': 0, 'op': 'eq', 'value': {'unsigned': '1'}}}}, {'disjunction': {}}]):
        invalid = copy.deepcopy(bundle)
        invalid['plan']['predicate'] = {'program': program}
        check({'prepare': invalid}, valid=False)
    maximum = copy.deepcopy(bundle)
    maximum['plan']['predicate'] = {'program': [{'atom': {'all': {}}}] + [{'negate': {}}]*63}
    check({'prepare': maximum})

    columns, rows, expected_rows, ipc = arrow_fixture(producer)
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
    print(f'Unified native/port codecs: {len(actions)} shared cases; three source bundles, nine compound plans, six Arrow types, five cell states, full-width values, Unicode and malformed rejection passed')


if __name__ == '__main__':
    run(*sys.argv[1:])
