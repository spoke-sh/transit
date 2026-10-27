"""Prepared wire handles never migrate across external schema or name changes."""
import json
import psycopg
import mysql.connector


def run(postgres, mysql_options, external):
    def applied(result):
        assert result['state'] == 'terminal', result
        assert result['outcome'] == 'applied' or (result['outcome'] == 'delegated' and result['table_outcome'] == 'applied'), result
    with psycopg.connect(**postgres) as pg, mysql.connector.connect(**mysql_options) as my:
        pg.execute('CREATE TABLE wire_schema (id BIGINT PRIMARY KEY, value BIGINT)')
        pg.execute('INSERT INTO wire_schema (id,value) VALUES (1,7)')
        select = 'SELECT value FROM wire_schema WHERE id=%s'
        update = 'UPDATE wire_schema SET value=%s WHERE id=%s'
        assert pg.execute(select,(1,),prepare=True).fetchone() == (7,)
        assert pg.execute(update,(7,1),prepare=True).rowcount == 1
        read = my.cursor(prepared=True)
        write = my.cursor(prepared=True)
        read.execute(select,(1,))
        assert read.fetchone() == (7,)
        write.execute(update,(7,1))
        assert write.rowcount == 0

        def refused(retired=False):
            for sql,args in ((select,(1,)),(update,(8,1))):
                try:
                    pg.execute(sql,args,prepare=True)
                except psycopg.Error as error:
                    assert error.sqlstate == ('42501' if retired else '55000'), str(error)
                    assert ('permission denied' if retired else 'source changed') in str(error)
                else:
                    raise AssertionError('PostgreSQL reused a stale binding')
            for cursor,sql,args in ((read,select,(1,)),(write,update,(8,1))):
                try:
                    cursor.execute(sql,args)
                except mysql.connector.Error as error:
                    assert error.errno == (1142 if retired else 1105), str(error)
                    assert ('permission denied' if retired else 'source changed') in str(error)
                else:
                    raise AssertionError('MySQL reused a stale binding')

        applied(external(900001,'ALTER TABLE wire_schema ADD COLUMN extra BIGINT'))
        refused()
        applied(external(900002,'DROP TABLE wire_schema'))
        # A frozen handle still addresses the retired original object. New
        # preparation instead resolves the currently absent name.
        refused(retired=True)
        try:
            pg.execute(select,(1,),prepare=False)
        except psycopg.Error as error:
            assert error.sqlstate == '42P01' and 'does not exist' in str(error), str(error)
        else:
            raise AssertionError('PostgreSQL prepared an absent Table')
        with my.cursor() as missing:
            try:
                missing.execute(select,(1,))
            except mysql.connector.Error as error:
                assert error.errno == 1146 and 'does not exist' in str(error), str(error)
            else:
                raise AssertionError('MySQL prepared an absent Table')
        applied(external(900003,'CREATE TABLE wire_schema (id BIGINT PRIMARY KEY, value BIGINT)'))
        refused(retired=True)
        # A fresh preparation binds the replacement and sees no old row.
        assert pg.execute(select,(1,),prepare=False).fetchall() == []
        read.close()
        write.close()
    print(json.dumps(dict(profile='database_wire_schema',external_principal=1234,alter_invalidates=True,drop_invalidates=True,name_reuse_invalidates=True,fresh_missing_name=True,both_protocols=True)),flush=True)
