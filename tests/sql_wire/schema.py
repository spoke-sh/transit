"""Prepared wire handles never migrate across external schema or name changes."""
import json
import psycopg
import mysql.connector


def run(postgres, mysql_options, external):
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

        def refused():
            for sql,args in ((select,(1,)),(update,(8,1))):
                try:
                    pg.execute(sql,args,prepare=True)
                except psycopg.errors.ObjectNotInPrerequisiteState as error:
                    assert 'source changed' in str(error)
                else:
                    raise AssertionError('PostgreSQL reused a stale binding')
            for cursor,sql,args in ((read,select,(1,)),(write,update,(8,1))):
                try:
                    cursor.execute(sql,args)
                except mysql.connector.Error as error:
                    assert error.errno == 1105 and 'source changed' in str(error)
                else:
                    raise AssertionError('MySQL reused a stale binding')

        assert external(900001,'ALTER TABLE wire_schema ADD COLUMN extra BIGINT')['outcome'] == 'applied'
        refused()
        assert external(900002,'DROP TABLE wire_schema')['outcome'] == 'applied'
        assert external(900003,'CREATE TABLE wire_schema (id BIGINT PRIMARY KEY, value BIGINT)')['outcome'] == 'applied'
        refused()
        # A fresh preparation binds the replacement and sees no old row.
        assert pg.execute(select,(1,),prepare=False).fetchall() == []
        read.close()
        write.close()
    print(json.dumps(dict(profile='database_wire_schema',external_principal=1235,alter_invalidates=True,name_reuse_invalidates=True,both_protocols=True)),flush=True)
