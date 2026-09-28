"""One pinned ADBC C/Python workload shared by all physical placements."""
import hashlib
import json
from pathlib import Path
import subprocess


def verify(uri, certificate_path, root, token, schema, expected):
    certificate = certificate_path.read_bytes()
    import adbc_driver_flightsql as adbc
    from adbc_driver_flightsql import dbapi
    with dbapi.connect(uri, db_kwargs={adbc.DatabaseOptions.AUTHORIZATION_HEADER.value: 'Bearer ' + token, adbc.DatabaseOptions.TLS_ROOT_CERTS.value: certificate.decode()}, autocommit=True) as connection:
        assert connection.adbc_get_table_schema('items', catalog_filter='transit', db_schema_filter='public') == schema
        for sequence, query_text, expected_rows in (
            (3, 'SELECT id, value FROM items', expected),
            (4, 'SELECT * FROM items WHERE id < 0', []),
            (5, 'SELECT count(*) FROM items', [{'count': 41}]),
            (6, 'SELECT sum(value) FROM items', [{'sum': sum(row['value'] or 0 for row in expected)}]),
        ):
            with connection.cursor() as cursor:
                cursor.adbc_statement.set_options(**{adbc.StatementOptions.RPC_CALL_HEADER_PREFIX.value + 'x-transit-request-sequence': str(sequence)})
                cursor.execute(query_text)
                assert cursor.fetch_arrow_table().to_pylist() == expected_rows
    print('ADBC Python: native schema, exact rows, empty result, count, sum and unprepared fallback passed.', flush=True)
    source = Path(__file__).resolve().parent / 'flight'
    pin = json.loads((source / 'upstream.json').read_text())['files'][0]
    assert hashlib.sha256((source / pin['path']).read_bytes()).hexdigest() == pin['sha256']
    consumer = root / 'adbc-c'
    subprocess.run(['cc', '-std=c11', '-Wall', '-Wextra', '-Werror', str(source / 'adbc.c'), '-ldl', '-o', str(consumer)], check=True)
    subprocess.run([str(consumer), adbc._driver_path(), uri, str(root / 'credential'), '7', str(certificate_path)], check=True, timeout=180)
