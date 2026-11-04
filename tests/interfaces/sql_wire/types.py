"""Pinned independent drivers qualify scalar aliases, metadata and bind modes."""
from decimal import Decimal
import psycopg
import mysql.connector

from interfaces.sql_wire.type_cases import CASES, UNSUPPORTED_ALIASES


def run(postgres, mysql_options, inventory, external):
    columns = [(alias, case) for case in CASES for alias in case.aliases]
    schema = ','.join(f'v{i} {alias}' for i,(alias,_) in enumerate(columns))
    expected = tuple(case.value for _,case in columns)
    modes = ('pg_text','pg_binary','mysql_text','mysql_binary')
    with psycopg.connect(**postgres) as pg, mysql.connector.connect(**mysql_options) as my:
        for mode in modes:
            table = 'scalar_'+mode
            create = f'CREATE TABLE {table} (id INT PRIMARY KEY, {schema})'
            if mode.startswith('pg'):
                pg.execute(create)
            else:
                with my.cursor() as writer: writer.execute(create)
            # Metadata exists even without a first row.
            for binary in (False,True):
                with pg.cursor(binary=binary) as reader:
                    reader.execute(f'SELECT * FROM {table}',prepare=True)
                    assert reader.fetchall() == []
                    assert [c.type_code for c in reader.description] == [23]+[case.pg_oid for _,case in columns]
                    for field,(_,case) in zip(reader.description[1:],columns,strict=True):
                        if case.kind == 'decimal': assert (field.precision,field.scale) == (38,2), field
                with my.cursor(prepared=binary) as reader:
                    reader.execute(f'SELECT * FROM {table}')
                    assert reader.fetchall() == []
                    assert [c[1] for c in reader.description] == [3]+[case.mysql_code for _,case in columns]
            if mode.startswith('pg'):
                marker = '%b' if mode == 'pg_binary' else '%t'
                with pg.cursor(binary=mode == 'pg_binary') as writer:
                    writer.execute(f'INSERT INTO {table} VALUES ('+','.join([marker]*(len(columns)+1))+')',(1,*expected),prepare=True)
                    assert writer.rowcount == 1
            else:
                with my.cursor(prepared=mode == 'mysql_binary') as writer:
                    if mode == 'mysql_text':
                        # COM_QUERY has SQL text, not typed bindings. In particular
                        # binary literals use X'hex', never invalid UTF-8 SQL bytes.
                        writer.execute(f'INSERT INTO {table} VALUES (1,'+','.join(case.literal for _,case in columns)+')')
                    else:
                        writer.execute(f'INSERT INTO {table} VALUES ('+','.join(['%s']*(len(columns)+1))+')',(1,*expected))
                    assert writer.rowcount == 1
            pg.execute(f'INSERT INTO {table} VALUES (2,'+','.join(['NULL']*len(columns))+')')
            want = [(1,*expected),(2,*([None]*len(columns)))]
            for binary in (False,True):
                with pg.cursor(binary=binary) as reader:
                    reader.execute(f'SELECT * FROM {table}',prepare=True)
                    actual = reader.fetchall()
                    assert sorted(actual,key=lambda row:row[0]) == want, (mode,'postgres',binary,actual,want)
                with my.cursor(prepared=binary) as reader:
                    reader.execute(f'SELECT * FROM {table}')
                    actual = reader.fetchall()
                    assert sorted(actual,key=lambda row:row[0]) == want, (mode,'mysql',binary,actual,want)
            print(f'SQL type drivers: {mode}, all aliases, typed empty/NULL and cross-interface values passed.',flush=True)

        for alias in UNSUPPORTED_ALIASES:
            for protocol in ('postgres','mysql'):
                before = len(inventory())
                query = f'CREATE TABLE unsupported_{protocol} (bad {alias})'
                try:
                    if protocol == 'postgres': pg.execute(query)
                    else:
                        with my.cursor() as cursor: cursor.execute(query)
                except (psycopg.Error,mysql.connector.Error) as error:
                    assert error.sqlstate == ('0A000' if protocol == 'postgres' else '42000') and 'bad' in str(error), (alias,error)
                    if protocol == 'mysql': assert error.errno == 1235
                else: raise AssertionError((protocol,alias,'unsupported declaration accepted'))
                assert len(inventory()) == before

        external(910001,'CREATE TABLE native_parameters (id INT, opaque INT128)')
        before = len(inventory())
        query = 'SELECT id FROM native_parameters WHERE opaque=%s'
        try: pg.execute(query,(1,),prepare=True)
        except psycopg.Error as error: assert error.sqlstate == '0A000' and 'parameter' in str(error) and 'int128' in str(error), error
        else: raise AssertionError('Unsupported PostgreSQL parameter accepted')
        with my.cursor(prepared=True) as reader:
            try: reader.execute(query,(1,))
            except mysql.connector.Error as error: assert error.errno == 1235 and 'parameter' in str(error) and 'int128' in str(error), error
            else: raise AssertionError('Unsupported MySQL parameter accepted')
        assert len(inventory()) == before

        pg.execute('CREATE TABLE decimal_bounds (id INT, value DECIMAL(10,2), required BOOLEAN NOT NULL)')
        for parameters in ((2**31,Decimal('1.00'),True),(1,Decimal('100000000.00'),True),(1,Decimal('1.001'),True)):
            for marker in ('%t','%b'):
                try: pg.execute('INSERT INTO decimal_bounds VALUES ('+','.join([marker]*3)+')',parameters,prepare=True)
                except psycopg.Error as error: assert error.sqlstate == '22003', error
                else: raise AssertionError(('Invalid numeric parameter accepted',parameters))
            with my.cursor(prepared=True) as writer:
                try: writer.execute('INSERT INTO decimal_bounds VALUES (%s,%s,%s)',parameters)
                except mysql.connector.Error as error: assert error.sqlstate == '22003', error
                else: raise AssertionError(('Invalid MySQL numeric parameter accepted',parameters))
        assert pg.execute('SELECT COUNT(*) FROM decimal_bounds').fetchone() == (0,)
        try: pg.execute('INSERT INTO decimal_bounds VALUES (%s,%s,%s)',(1,Decimal('1.00'),None),prepare=True)
        except psycopg.Error as error: assert error.sqlstate == '23502', error
        else: raise AssertionError('Required NULL accepted')
        with my.cursor(prepared=True) as writer:
            try: writer.execute('INSERT INTO decimal_bounds VALUES (%s,%s,%s)',(1,Decimal('1.00'),None))
            except mysql.connector.Error as error: assert error.sqlstate == '23000', error
            else: raise AssertionError('Required MySQL NULL accepted')
        pg.execute('CREATE TABLE decimal_defaults (a DECIMAL, b NUMERIC)')
        pg.execute('INSERT INTO decimal_defaults VALUES (%s,%s)',(Decimal('99999999999999999999999999999999999999'),Decimal('-1')),prepare=True)
        assert pg.execute('SELECT * FROM decimal_defaults').fetchone() == (Decimal('99999999999999999999999999999999999999'),Decimal('-1'))
        pg.execute('CREATE TABLE pg_decimal_scale (value DECIMAL(38,38))')
        pg.execute('INSERT INTO pg_decimal_scale VALUES (%b)',(Decimal('0.00000000000000000000000000000000000001'),),prepare=True)
        with pg.cursor(binary=True) as reader:
            reader.execute('SELECT * FROM pg_decimal_scale')
            assert reader.fetchone() == (Decimal('1e-38'),)
        with my.cursor() as reader:
            try: reader.execute('SELECT * FROM pg_decimal_scale')
            except mysql.connector.Error as error: assert error.errno == 1235 and error.sqlstate == '42000' and 'value' in str(error), error
            else: raise AssertionError('MySQL silently widened its scale domain')
            try: reader.execute('CREATE TABLE mysql_scale_refused (fraction DECIMAL(38,31))')
            except mysql.connector.Error as error: assert error.errno == 1235 and 'fraction' in str(error), error
            else: raise AssertionError('MySQL declared an unsupported decimal scale')
    print('SQL type drivers: unsupported declarations, numeric range/exactness and protocol scale limits passed.',flush=True)
