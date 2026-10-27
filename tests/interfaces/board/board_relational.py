"""Real direct Board queries, original pin journal, current rights and host loss."""
from runner.paths import ROOT
import copy
import json
import os
from pathlib import Path
import subprocess
import time
import urllib.error
import urllib.request

from catalog.tables.catalog_abi import CONTRACT, Native
from harness.services import free_port, wait_ready

SQL = 'SELECT l.k, COUNT(*) AS rows, COUNT(r.v) AS present, SUM(r.v) AS total FROM rel_left l LEFT JOIN rel_right r ON l.k = r.k GROUP BY l.k'


def exercise(library, board, root, authority, service, profile, restart, policy, fault, proof, browser=False):
    library, board = str(Path(library).resolve()), str(Path(board).resolve())
    connection = dict(scope=dict(profile['catalog']['scope'], catalog=str(profile['catalog']['scope']['catalog'])),
                      branch='1', audience=profile['catalog']['audience'], principal=101, role=None)
    catalog = Native(library, authority, connection, seed_byte=29, service_url=service)
    def execute(sql, operation, create_object=None):
        compiled = catalog.call(dict(compile=dict(namespace=1, operation=str(operation), create_object=create_object,
            sql=sql, dialect='transit', ingestion='bulk')))['compiled']
        reference = catalog.call(dict(stage=compiled['summary']['id']))['staged']
        catalog.call(dict(admit=reference))
        result = catalog.call(dict(operation=dict(reference=reference, command='execute', steps=32)))['observation']
        assert 'committed' in next(iter(result.values())), result
    execute('CREATE TABLE rel_left (k BIGINT, v BIGINT)', 1001, '1001')
    execute('CREATE TABLE rel_right (k BIGINT, v BIGINT)', 1002, '1002')
    execute('INSERT INTO rel_left VALUES (7,10),(7,20),(9,30),(NULL,40)', 1003)
    execute('INSERT INTO rel_right VALUES (7,7),(7,1),(NULL,4)', 1004)
    recovery = root / 'board-recovery'
    recovery.mkdir()
    seed = root / 'board-reader.seed'
    seed.write_text('1d' * 32)
    seed.chmod(0o600)
    inspector = root / 'board-inspector.seed'
    inspector.write_text('0c' * 32)
    inspector.chmod(0o600)
    port = free_port()
    origin = f'http://127.0.0.1:{port}'
    query = dict(definition=CONTRACT['definition'], catalogs=[connection, connection], service_url=service,
        spill_directory=str(root), options=dict(consistency='independent_table_snapshots', resident_bytes='16777216',
        spill_bytes='16777216', result_bytes='8388608', output_rows='1000', work_steps='100000',
        source_pins=2, requests='100000', spill_work='100000'))
    config = dict(upstream=authority, realm=42, principal=104, seed_file=str(inspector), public_origin=origin, port=port,
        request_timeout_ms=5000, upstream_timeout_ms=1000,
        relational=dict(seed_file=str(seed), recovery_directory=str(recovery), query=query))
    config_path = root / 'relational-board.json'
    http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    log = (root / 'relational-board.log').open('w+')
    child = None
    observed = []
    def start():
        config_path.write_text(json.dumps(config))
        process = subprocess.Popen([board, str(config_path)], stdout=log, stderr=subprocess.STDOUT)
        try:
            wait_ready(http, process, origin + '/health')
        except BaseException:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=15)
            raise
        return process
    def stop(crash=False):
        if child is not None and child.poll() is None:
            (child.kill if crash else child.terminate)()
            child.wait(timeout=15)
    def request(action, status=200, extra=None):
        headers = {'Origin': origin, 'Content-Type': 'application/json'}
        if extra:
            headers.update(extra)
        payload = json.dumps(action).encode()
        for attempt in range(8):
            req = urllib.request.Request(origin + '/api/v1/relational', payload, headers)
            try:
                response = http.open(req, timeout=10)
            except urllib.error.HTTPError as error:
                response = error
            with response:
                actual, value = response.status, json.loads(response.read())
            if actual == 429 and attempt < 7:
                time.sleep(.15)
                continue
            assert actual == status, (action, actual, value)
            if status == 200:
                observed.append(value)
            return value
        raise AssertionError('Board stayed rate-limited')
    def saved():
        return json.loads((recovery / 'relational.json').read_text())
    def propose(number, routes=(0, 1)):
        statement = dict(namespace=1, sql=SQL, routes=list(routes))
        explanation = request(dict(query=dict(explain=statement)))['query']['explained']
        return dict(id=f'{number:032x}', statement=statement, sources=explanation['sources']), explanation
    def pin_status(record):
        statuses = []
        for source, pin in zip(record['input']['sources'], record['pins'], strict=True):
            owner = dict(definition=CONTRACT['definition'], connection=connection,
                object=source['binding']['interpretation']['interpretation']['object'], operation=str(pin['operation']))
            statuses.append(catalog.call(dict(retention=dict(status=owner)))['retention']['status'])
        return statuses
    def recover(record):
        request(dict(recover=dict(id=record['input']['id'])))
        request(dict(recover=dict(id=record['input']['id'])))
        after = saved()
        assert after['input'] == record['input']
        assert [p['operation'] for p in after['pins']] == [p['operation'] for p in record['pins']]
        assert after['state'] == 'closed' and all(p['released'] for p in after['pins'])
        for status, source in zip(pin_status(record), record['input']['sources'], strict=True):
            if not status['released']:
                assert status['snapshot'] is None
                assert status['current_position']['partition'] == source['position']['partition']
                assert status['retired'] or int(status['current_position']['next_lsn']) > int(source['position']['next_lsn'])
        assert request({'describe': {}})['description']['recovery'] is None
    try:
        child = start()
        request({'describe': {}}, 403, {'Origin': 'http://foreign.invalid'})
        description = request({'describe': {}})['description']
        assert description['active'] is None and description['recovery'] is None
        assert len(description['routes']) == 2 and description['capabilities']['interactive']
        assert not description['capabilities']['maintained']
        for number, routes in ((201, (0, 0)), (202, (0, 1))):
            original, explanation = propose(number, routes)
            opened = request(dict(query=dict(open=original)))['query']['opened']
            assert request(dict(query=dict(open=original)))['query']['opened'] == opened
            assert opened['description'] == explanation
            record = saved()
            assert record['input'] == original and record['state'] == 'active'
            assert all(p['snapshot'] is not None and not p['released'] for p in pin_status(record))
            changed = copy.deepcopy(original)
            changed['sources'][0]['position']['next_lsn'] = '1'
            assert request(dict(query=dict(open=changed)), 409)['diagnostic']['cause'] == 'QueryIdentityMismatch'
            reference = opened['reference']
            progress = request({'describe': {}})['description']['active']
            assert progress['opened'] == opened and progress['ordinal'] == '0' and not progress['read']
            rows = []
            for ordinal in range(4):
                action = dict(query=dict(page=dict(reference=reference, ordinal=str(ordinal))))
                page = request(action)['query']['page']
                assert request(action)['query']['page'] == page
                if ordinal == 3:
                    assert page['complete_coverage'] and page['row'] is None
                else:
                    assert not page['complete_coverage']
                    rows.append([None if 'null' in c else int(next(iter(c['value']['atom'].values()))) for c in page['row']['cells']])
                if ordinal in (0, 3):
                    policy(False)
                    try:
                        assert request(action, 403)['diagnostic']['category'] == 'access'
                        request({'describe': {}}, 403)
                    finally:
                        policy(True)
                    assert request(action)['query']['page'] == page
            assert rows == [[None, 1, 0, None], [7, 4, 4, 16], [9, 1, 0, None]], rows
            request(dict(query=dict(close=reference)))
            request(dict(query=dict(close=reference)))
            assert all(p['released'] for p in pin_status(record))
        # An accepted acquisition with a lost reply keeps its original operation
        # in the journal. An identical retry obtains that exact pin and cut.
        original, _ = propose(203)
        fault['next'] = 'pin'
        failure = request(dict(query=dict(open=original)), 503)
        assert failure['diagnostic']['outcome'] == 'unknown', failure
        interrupted = saved()
        assert interrupted['state'] == 'acquiring' and interrupted['pins'][0]['handle'] is None
        accepted = fault['accepted'][-1]
        assert accepted['action']['owner']['operation'] == interrupted['pins'][0]['operation']
        opened = request(dict(query=dict(open=original)))['query']['opened']
        assert saved()['pins'][0]['handle'] == accepted['result']['pin']
        # Release acceptance has the same uncertainty rule and survives both
        # service replacements without replaying the query or changing its cut.
        fault['next'] = 'release'
        failure = request(dict(query=dict(close=opened['reference'])), 503)
        assert failure['diagnostic']['outcome'] == 'unknown', failure
        record = saved()
        assert record['state'] == 'closing' and not record['pins'][0]['released']
        stop(crash=True)
        restart()
        child = start()
        description = request({'describe': {}})['description']
        assert description['active'] is None and description['recovery']['state'] == 'closing'
        assert request(dict(query=dict(open=original)), 409)['diagnostic']['cause'] == 'RelationalRecoveryRequired'
        recover(record)
        # Replacement with an accepted pin whose handle was never received closes
        # the original owner, including the not-yet-dispatched second pin.
        original, _ = propose(204)
        fault['next'] = 'pin'
        assert request(dict(query=dict(open=original)), 503)['diagnostic']['outcome'] == 'unknown'
        record = saved()
        stop(crash=True)
        restart()
        child = start()
        assert saved()['state'] == 'closing' and saved()['input'] == original
        recover(record)
        # An active executor is deliberately lost with its host. Its durable pins
        # remain visible until an explicit recovery closes them.
        original, _ = propose(205)
        opened = request(dict(query=dict(open=original)))['query']['opened']
        record = saved()
        stop(crash=True)
        child = start()
        assert all(not p['released'] for p in pin_status(record))
        request(dict(query=dict(page=dict(reference=opened['reference'], ordinal='0'))), 400)
        assert request({'describe': {}})['description']['active'] is None
        recover(record)
        # Data can change after explanation without changing its schema. A
        # rejected open still preserves original ownership for explicit closure.
        original, _ = propose(206)
        execute('INSERT INTO rel_right VALUES (9,99)', 1005)
        execute('DELETE FROM rel_right WHERE k = 9', 1006)
        failure = request(dict(query=dict(open=original)), 409)
        assert failure['diagnostic']['cause'] == 'RelationalSourceChanged', failure
        record = saved()
        assert record['input'] == original and all(pin['handle'] is None for pin in record['pins'])
        recover(record)
        # A replacement credential for the same principal can close original
        # ownership. Neither the stored journal nor its source bindings change.
        original, _ = propose(208)
        request(dict(query=dict(open=original)))
        record = saved()
        stop(crash=True)
        policy(False)
        seed.write_text('37' * 32)
        previous = catalog
        try:
            catalog = Native(library, authority, connection, seed_byte=55, service_url=service)
            child = start()
            recover(record)
        finally:
            stop()
            if catalog is not previous:
                catalog.close()
            catalog = previous
            policy(True)
            seed.write_text('1d' * 32)
        child = start()
        responses = root / 'board-relational-responses.json'
        responses.write_text(json.dumps(observed))
        subprocess.run(['vp', 'exec', 'node', str(ROOT / 'tests/interfaces/board/board_relational_client.mjs'), str(responses)], check=True, timeout=30)
        if browser:
            original, _ = propose(207)
            request(dict(query=dict(open=original)))
            interrupted = saved()
            stop(crash=True)
            child = start()
            env = os.environ | dict(BOARD_TEST_URL=origin, BOARD_RELATIONAL_PROOF=proof,
                BOARD_RELATIONAL_AUTHORITY=service, BOARD_RELATIONAL_PROFILE=str(root / 'profile.json'), BOARD_RELATIONAL_SQL=SQL)
            subprocess.run(['vp', 'exec', '--filter', '@transit/board-web', 'playwright', 'test', 'relational.spec.ts'], env=env, check=True, timeout=180)
            assert saved()['state'] == 'closed'
            assert all(p['released'] for p in pin_status(interrupted))
        stop()
        del config['relational']
        child = start()
        assert request({'describe': {}}, 404)['err'] == 'QueryDisabled'
    except BaseException:
        log.flush()
        log.seek(0)
        print(log.read()[-10000:])
        raise
    finally:
        stop()
        catalog.close()
        log.close()
