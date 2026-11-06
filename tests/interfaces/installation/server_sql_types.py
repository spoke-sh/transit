"""Required installed console/psql/mysql scalar smoke, using one copied binary."""
import argparse
import ctypes
from decimal import Decimal
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

from interfaces.installation.server import Fixture
from interfaces.installation.server_sql import wait_status
from interfaces.sql_wire.type_cases import CASES, cli_cell, native_rows
from runner.capture import provenance
from runner.paths import ROOT


class Clients:
    def __init__(self, fixture):
        self.fixture = fixture
        self.env = {k:v for k,v in os.environ.items() if not k.startswith(('PG','MYSQL'))}
        self.env.update(PGSSLMODE='disable', PGCONNECT_TIMEOUT='10', LC_ALL='C.UTF-8')
        sql = fixture.config['sql']
        self.commands = {
            'postgres': [shutil.which('psql'), '-XAtw', '-v', 'ON_ERROR_STOP=1', '-P', 'null=\\N', '-F', '\t', '-h', '127.0.0.1', '-p', str(sql['postgres']['port']), '-U', 'owner', '-d', 'transit', '-c'],
            'mysql': [shutil.which('mysql'), '--no-defaults', '--no-login-paths', '--protocol=TCP', '-h', '127.0.0.1', '-P', str(sql['mysql']['port']), '-u', 'owner', '-D', 'transit', '--ssl-mode=DISABLED', '--batch', '--raw', '--skip-column-names', '--binary-as-hex', '--default-character-set=utf8mb4', '-e'],
        }
        assert all(command[0] for command in self.commands.values()), 'psql and mysql are required; enter nix develop .#ci-experience'

    def operations(self):
        # Wire logins and the local peer have distinct account identities.
        # Inspect the wire account's original history through its public control.
        profile = self.fixture.installation / 'sql/accounts/owner/control.json'
        entries, after = [], []
        while True:
            result = subprocess.run([str(self.fixture.cli), '__transit_role_v1', 'sql_gateway',
                'control', str(profile), 'list', *after], capture_output=True, text=True,
                timeout=30, env=self.fixture.environment, check=True)
            page = json.loads(result.stdout)
            entries.extend(entry for entry in page['entries'] if entry is not None)
            if page['next'] is None:
                return entries
            after = [str(page['next'])]

    def execute(self, interface, sql, kinds=None, reject=None):
        if interface == 'console':
            result = self.fixture.console(sql+';\n', expected=1 if reject else 0)
            if reject:
                assert reject in result.stderr, result.stderr
                return
            return native_rows(result[-1]) if kinds is not None else None
        result = subprocess.run([*self.commands[interface], sql], env=self.env, text=True, capture_output=True, timeout=90)
        if reject:
            assert result.returncode != 0 and reject in result.stderr, result
            return
        assert result.returncode == 0, (interface, sql, result.stderr)
        if kinds is not None:
            return [tuple(cli_cell(text, kind, interface) for text,kind in zip(line.split('\t'),kinds,strict=True)) for line in result.stdout.splitlines()]


def run(cli, output):
    assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
    fixture = Fixture(cli, cli, cli)
    fixture.config.pop('executables')
    fixture.use_private_runtime()
    fixture.config['sql'].update(native={'local': True}, postgres={'port': fixture.reserve_port()}, mysql={'port': fixture.reserve_port()},
        tls={'mode':'disabled'}, accounts=[dict(name='owner', role='local_owner', authentication='trust', bootstrap_owner=True)])
    fixture.config['applications'] = {'port': fixture.reserve_port()}
    fixture.path.write_text(json.dumps(fixture.config))
    interfaces = ('console','postgres','mysql')
    expected_cases = [f'{creator}.{stage}' for creator in interfaces for stage in ('empty','insert','update','delete','batch','scalars','restart')]+['negative','native-projection','aggregate-aliases']
    with open(fixture.cli,'rb') as binary:
        digest = hashlib.file_digest(binary,'sha256').hexdigest()
    report = dict(profile='sql-scalar-interfaces', source=provenance(ROOT), binary_sha256=digest,
        durability='local-disk', expected=expected_cases, cases=[], complete=False)
    output.parent.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    def record(name):
        assert name in expected_cases and name not in report['cases'], name
        report['cases'].append(name)
        output.write_text(json.dumps(report,indent=2)+'\n')
        print(f'SQL type smoke: {name} passed',flush=True)
    def all_rows(sql, kinds, expected):
        for reader in interfaces:
            actual = clients.execute(reader,sql,kinds)
            # The user's exact declaration has no primary key. Synthetic Table
            # keys do not order rows by id; compare the complete multiset.
            assert sorted(actual, key=lambda row: row[0]) == sorted(expected, key=lambda row: row[0]), (reader,sql,actual,expected)
    success = False
    try:
        clients = Clients(fixture)
        report['binary_version'] = subprocess.check_output([fixture.cli,'--version'],text=True).strip()
        report['clients'] = {name:subprocess.check_output([args[0],'--version'],text=True).strip() for name,args in clients.commands.items()}
        output.write_text(json.dumps(report,indent=2)+'\n')
        fixture.start(); fixture.ready()
        wait_status(fixture,lambda s:s['service']['state']=='accepting')
        report['definition'] = fixture.record()['definition']
        for creator in interfaces:
            table = 'employees_'+creator
            clients.execute(creator,f'CREATE TABLE {table} (id INT, name VARCHAR, salary DECIMAL(10, 2))')
            kinds = ('int32','utf8','decimal')
            all_rows(f'SELECT * FROM {table}', kinds, [])
            all_rows(f'SELECT id FROM {table}', ('int32',), [])
            all_rows(f'SELECT salary FROM {table}', ('decimal',), [])
            record(creator+'.empty')
            for index,writer in enumerate(interfaces):
                clients.execute(writer,f"INSERT INTO {table} VALUES ({index}, 'snow ☃', -12345.67)")
            all_rows(f'SELECT * FROM {table}',kinds,[(i,'snow ☃',Decimal('-12345.67')) for i in range(3)])
            record(creator+'.insert')
            for index,writer in enumerate(interfaces):
                clients.execute(writer,f'UPDATE {table} SET salary=0.01 WHERE id={index}')
            all_rows(f'SELECT * FROM {table}',kinds,[(i,'snow ☃',Decimal('0.01')) for i in range(3)])
            record(creator+'.update')
            for index,writer in enumerate(interfaces):
                clients.execute(writer,f'DELETE FROM {table} WHERE id={index}')
            all_rows(f'SELECT * FROM {table}',kinds,[])
            record(creator+'.delete')
            values = ','.join(f"({i},NULL,{i}.01)" for i in range(65))
            clients.execute(creator,f'INSERT INTO {table} VALUES {values}')
            for count in (1,32,33,65):
                all_rows(f'SELECT * FROM {table} WHERE id < {count} LIMIT {count}',kinds,[(i,None,Decimal(f'{i}.01')) for i in range(count)])
            record(creator+'.batch')
            columns = ','.join(f'v{i} {case.aliases[0]}' for i,case in enumerate(CASES))
            clients.execute(creator,f'CREATE TABLE scalars_{creator} ({columns})')
            clients.execute(creator,f'INSERT INTO scalars_{creator} VALUES ('+','.join(case.literal for case in CASES)+')')
            all_rows(f'SELECT * FROM scalars_{creator}',[case.kind for case in CASES],[tuple(case.value for case in CASES)])
            record(creator+'.scalars')
        clients.execute('console','CREATE TABLE alias_items (value BIGINT)')
        clients.execute('console','INSERT INTO alias_items VALUES (1), (1), (1), (2), (3), (3)')
        for reader in interfaces:
            # Preserve returned order: sorting in the test would hide a failure
            # to resolve the aggregate alias in ORDER BY.
            assert clients.execute(reader,
                'SELECT value, COUNT(*) AS count FROM alias_items GROUP BY value ORDER BY count ASC',
                ('int64','uint64')) == [(2,1),(3,2),(1,3)], reader
            assert clients.execute(reader,
                'SELECT value, SUM(value) AS sum FROM alias_items GROUP BY value HAVING sum > 2 ORDER BY sum DESC',
                ('int64','int64')) == [(3,6),(1,3)], reader
        record('aggregate-aliases')
        for protocol in ('postgres','mysql'):
            before = len(clients.operations())
            clients.execute(protocol,f'CREATE TABLE refused_{protocol} (bad INT128)',reject='bad')
            assert len(clients.operations()) == before, 'Rejected DDL admitted durable work'
            clients.execute(protocol,f'SELECT * FROM refused_{protocol}',reject='does not exist')
        record('negative')
        clients.execute('console','CREATE TABLE native_wide (id INT, opaque INT128)')
        clients.execute('console','INSERT INTO native_wide VALUES (7, 123)')
        for protocol in ('postgres','mysql'):
            assert clients.execute(protocol,'SELECT id FROM native_wide',('int32',)) == [(7,)]
            clients.execute(protocol,'SELECT * FROM native_wide',reject='opaque')
        record('native-projection')
        fixture.stop(); fixture.start(); fixture.ready()
        for creator in interfaces:
            all_rows(f'SELECT * FROM employees_{creator}',('int32','utf8','decimal'),[(i,None,Decimal(f'{i}.01')) for i in range(65)])
            all_rows(f'SELECT * FROM scalars_{creator}',[case.kind for case in CASES],[tuple(case.value for case in CASES)])
            record(creator+'.restart')
        assert set(report['cases']) == set(expected_cases)
        report['complete'] = success = True
    finally:
        report['seconds'] = round(time.monotonic()-started,3)
        output.write_text(json.dumps(report,indent=2)+'\n')
        fixture.cleanup()
        if success: shutil.rmtree(fixture.root)
        else: print(f'Private failed SQL type installation retained: {fixture.root}',file=sys.stderr)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cli',type=Path,required=True)
    parser.add_argument('--output',type=Path,default=ROOT/f'.cache/sql-types/smoke-{time.time_ns()}.json')
    args = parser.parse_args()
    run(args.cli.resolve(),args.output.resolve())
