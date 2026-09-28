#!/usr/bin/env python3
"""Pinned PyArrow/protobuf consumer of the actual native Flight metadata."""
import pathlib
import subprocess
import sys
import tempfile

import pyarrow as pa

ROOT = pathlib.Path(__file__).resolve().parents[1]


def run(fixture):
    with tempfile.TemporaryDirectory(prefix='transit-flight-metadata-') as directory:
        work = pathlib.Path(directory)
        proto = ROOT / 'packages/zig/transit-flight/proto'
        subprocess.run(['protoc', '-I', str(proto), '--python_out=' + str(work), str(proto / 'FlightSql.proto')], check=True)
        sys.path.insert(0, str(work))
        import FlightSql_pb2 as sql

        def call(command):
            (work / 'input').write_bytes(command.SerializeToString())
            subprocess.run([fixture, command.DESCRIPTOR.name, str(work / 'input'), str(work / 'output')], check=True)
            return pa.ipc.open_stream((work / 'output').read_bytes()).read_all()

        assert call(sql.CommandGetCatalogs()).to_pylist() == [{'catalog_name': 'transit'}]
        assert call(sql.CommandGetDbSchemas()).to_pylist() == [{'catalog_name': 'transit', 'db_schema_name': 'public'}]
        assert call(sql.CommandGetDbSchemas(catalog='')).num_rows == 0
        assert call(sql.CommandGetDbSchemas(db_schema_filter_pattern='p%')).num_rows == 1
        tables = call(sql.CommandGetTables(include_schema=True, table_name_filter_pattern='c%_er'))
        assert tables.schema == pa.schema([
            pa.field('catalog_name', pa.string()), pa.field('db_schema_name', pa.string()),
            pa.field('table_name', pa.string(), nullable=False), pa.field('table_type', pa.string(), nullable=False),
            pa.field('table_schema', pa.binary(), nullable=False),
        ])
        row = tables.to_pylist()[0]
        assert row['table_name'] == 'counter' and row['table_type'] == 'TABLE'
        assert pa.ipc.read_schema(pa.BufferReader(row['table_schema'])) == pa.schema([
            pa.field('id', pa.int64(), nullable=False), pa.field('count', pa.int64()),
        ])
        empty = call(sql.CommandGetTables(catalog='', include_schema=True))
        assert empty.num_rows == 0 and empty.schema == tables.schema
        assert call(sql.CommandGetTables(table_types=['VIEW'])).num_rows == 0
        assert call(sql.CommandGetTableTypes()).to_pylist() == [{'table_type': 'TABLE'}]
        info = call(sql.CommandGetSqlInfo())
        expected = pa.dense_union([
            pa.field('string_value', pa.string()), pa.field('bool_value', pa.bool_()),
            pa.field('bigint_value', pa.int64()), pa.field('int32_bitmask', pa.int32()),
            pa.field('string_list', pa.list_(pa.field('string_data', pa.string()))),
            pa.field('int32_to_int32_list_map', pa.map_(pa.int32(), pa.list_(pa.field('$data$', pa.int32())))),
        ], type_codes=list(range(6)))
        assert info.schema == pa.schema([pa.field('info_name', pa.uint32(), nullable=False), pa.field('value', expected)]), info.schema
        values = {r['info_name']: r['value'] for r in info.to_pylist()}
        assert values[0] == 'Transit Fuze' and values[3] is True and values[4] is True
        for key in (5, 9, 10, 11, 500, 501, 502, 563, 572, 573, 574):
            assert values[key] is False
        assert values[8] == 0 and values[508] == [] and values[517] == []
        requested = call(sql.CommandGetSqlInfo(info=[3, 0, 517, 508, 3]))
        assert requested.column(0).to_pylist() == [3, 0, 517, 508, 3]
        assert requested.column(1).to_pylist() == [True, 'Transit Fuze', [], [], True]
        print('Flight metadata: pinned PyArrow verified standard schemas, all six union children, optional filters, empty batches and published Table schema.')


if __name__ == '__main__':
    run(str(pathlib.Path(sys.argv[1]).resolve()))
