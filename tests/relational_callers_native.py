"""Explicit retained relational callers against the direct local Table owner."""
import copy
import json
from pathlib import Path
import time

from catalog_abi import CONTRACT, Native as Catalog
from unified_abi import Failure, Native, Port

SQL = 'SELECT l.k, COUNT(*) AS rows, COUNT(r.v) AS present, SUM(r.v) AS total FROM rel_left l LEFT JOIN rel_right r ON l.k = r.k GROUP BY l.k'
EXPECTED = [[None, 1, 0, None], [7, 4, 4, 16], [9, 1, 0, None]]
SELF_SQL = SQL.replace('rel_right r', 'rel_left r')
SELF_EXPECTED = [[None, 1, 0, None], [7, 4, 4, 60], [9, 1, 1, 30]]


class Fixture:
    def __init__(self, library, root, authority, service, profile):
        self.root = root
        c = profile['catalog']
        self.connection = dict(scope=dict(c['scope'], catalog=str(c['scope']['catalog'])),
                               branch='1', audience=c['audience'], principal=101, role=None)
        self.catalog = Catalog(library, authority, self.connection, seed_byte=29, service_url=service)
        self.configuration = dict(definition=CONTRACT['definition'], catalogs=[self.connection, self.connection], service_url=service,
            spill_directory=str(root), options=dict(consistency='independent_table_snapshots', resident_bytes='16777216',
            spill_bytes='16777216', result_bytes='8388608', output_rows='1000', work_steps='100000',
            source_pins=2, requests='100000', spill_work='100000'))
        self.operation = 100000
        self.pins = []
        seed = root / 'caller.seed'
        seed.write_text('1d' * 32)
        seed.chmod(0o600)
        for sql, operation, target in (
            ('CREATE TABLE rel_left (k BIGINT, v BIGINT)', 1001, '1001'),
            ('CREATE TABLE rel_right (k BIGINT, v BIGINT)', 1002, '1002'),
            ('CREATE TABLE rel_overflow (v BIGINT)', 1003, '1003'),
            ('INSERT INTO rel_left VALUES (7,10),(7,20),(9,30),(NULL,40)', 1004, None),
            ('INSERT INTO rel_right VALUES (7,7),(7,1),(NULL,4)', 1005, None),
            ('INSERT INTO rel_overflow VALUES (9223372036854775807),(1)', 1006, None),
        ):
            compiled = self.catalog.call(dict(compile=dict(namespace=1, operation=str(operation), create_object=target,
                sql=sql, dialect='transit', ingestion='bulk')))['compiled']
            reference = self.catalog.call(dict(stage=compiled['summary']['id']))['staged']
            self.catalog.call(dict(admit=reference))
            self.execute(reference, operation)

    def execute(self, reference, operation):
        """Reconcile setup through its saved intent, never recompile after loss."""
        deadline = time.monotonic() + 60
        command = 'execute'
        uncertain = 0
        while time.monotonic() < deadline:
            try:
                observed = self.catalog.call(dict(operation=dict(reference=reference, command=command, steps=32)))['observation']
            except Failure as failure:
                detail = failure.detail or {}
                if command == 'execute':
                    diagnostic = detail.get('diagnostic') or {}
                    if (failure.status != CONTRACT['statuses']['uncertain']
                            or diagnostic.get('code') != 'catalog.direct_outcome_unknown'
                            or diagnostic.get('outcome') != 'unknown'
                            or diagnostic.get('evidence') != 'saved_intent'
                            or diagnostic.get('identity', {}).get('id') != str(operation)):
                        raise
                    command = 'inspect'
                    uncertain += 1
                elif detail.get('err') not in ('AuthorityTimeout', 'AuthorityUnavailable'):
                    raise
                time.sleep(.05)
                continue
            state = next(iter(observed.values()))
            if 'committed' in state:
                if uncertain:
                    print(f'Relational setup: original operation {operation} recovered after {uncertain} uncertain execution replies.', flush=True)
                return
            # Inspection can establish that the original bounded execution did
            # not finish. Advance only that same staged identity, under current
            # authorization; a terminal rejection remains a failed setup.
            assert command == 'inspect' and 'admitted' in state, observed
            command = 'execute'
        raise AssertionError(('Original relational setup did not complete', operation))

    def retain(self, sources):
        """Persist each original acquisition before dispatch; aliases share one pin."""
        snapshots, unique = [], {}
        for source in sources:
            binding = source['binding']
            target = binding['interpretation']['interpretation']['object']
            key = json.dumps(target, sort_keys=True)
            if key not in unique:
                self.operation += 1
                owner = dict(definition=CONTRACT['definition'], connection=self.connection, object=target, operation=str(self.operation))
                acquisition = dict(owner=owner, expected=source['position'])
                path = self.root / f'relational-acquisition-{self.operation}.json'
                path.write_text(json.dumps(acquisition))
                snapshot = self.catalog.call(dict(retention=dict(acquire=acquisition)))['retention']['acquired']
                assert self.catalog.call(dict(retention=dict(status=owner)))['retention']['status']['snapshot'] == snapshot
                metadata = self.catalog.call(dict(retention=dict(metadata=snapshot)))['retention']['metadata']
                assert metadata['accepted'] == source['position'] and metadata['interpretation'] == binding['interpretation']
                unique[key] = snapshot
                self.pins.append(snapshot)
            snapshots.append(unique[key])
        return snapshots

    def release(self, snapshots):
        unique = {json.dumps(snapshot, sort_keys=True): snapshot for snapshot in snapshots}
        for snapshot in unique.values():
            self.catalog.call(dict(retention=dict(release=snapshot)))
            status = self.catalog.call(dict(retention=dict(status=snapshot['owner'])))['retention']['status']
            assert status['released'] and status['snapshot'] == snapshot
            self.pins.remove(snapshot)

    def close(self):
        self.catalog.close()


def exercise(library, host, root, authority, service, profile, restart, policy, language=None):
    fixture = Fixture(library, root, authority, service, profile)
    results = []
    try:
        for family in ('native', 'port'):
            query = None
            calls = 0
            def start():
                if family == 'native':
                    return Native(library, authority, relational=fixture.configuration, seed_byte=29)
                return Port(host, root, authority, relational=fixture.configuration)
            def call(action, expected=None):
                nonlocal calls
                calls += 1
                try:
                    value = query.call(dict(relational=action))['relational']
                except Failure as failure:
                    if expected is None: raise
                    assert failure.detail['err'] == expected, failure.detail
                    return failure.detail
                assert expected is None, (expected, value)
                return value
            def prepare(number, sql=SQL, routes=(0, 1)):
                statement = dict(namespace=1, sql=sql, routes=list(routes))
                explanation = call(dict(explain=statement))['explained']
                snapshots = fixture.retain(explanation['sources'])
                action = dict(id=f'{number:032x}', statement=statement,
                    bindings=[source['binding'] for source in explanation['sources']], snapshots=snapshots)
                opened = call(dict(open=action))['opened']
                assert call(dict(open=action))['opened'] == opened
                assert opened['description'] == explanation and not opened['complete_coverage']
                return action, opened
            def page(reference, ordinal, error=None):
                return call(dict(page=dict(reference=reference, ordinal=str(ordinal))), error)
            def finish(action, reference):
                assert call(dict(close=reference)) == {'closed': {}}
                assert call(dict(close=reference)) == {'closed': {}}
                # Local cursor cleanup never releases the caller's durable pins.
                for snapshot in action['snapshots']:
                    assert not fixture.catalog.call(dict(retention=dict(status=snapshot['owner'])))['retention']['status']['released']
                fixture.release(action['snapshots'])
            def values(rows):
                return [[None if 'null' in cell else int(next(iter(cell['value']['atom'].values()))) for cell in row['cells']] for row in rows]
            try:
                query = start()
                capabilities = call({'capabilities': {}})['capabilities']
                assert capabilities['interactive'] and not capabilities['captured'] and not capabilities['maintained']
                call(dict(explain=dict(namespace=1, sql='SELECT k FROM rel_left l JOIN rel_right r ON l.k = r.k', routes=[0, 1])), 'AmbiguousRelationalColumn')
                for number, sql, routes, expected in ((1, SQL, (0, 0), EXPECTED), (2, SQL, (0, 1), EXPECTED), (3, SELF_SQL, (0, 0), SELF_EXPECTED)):
                    action, opened = prepare(number, sql, routes)
                    reference = opened['reference']
                    assert (opened['cuts'][0] == opened['cuts'][1]) == (sql == SELF_SQL)
                    for changed in ({**reference, 'plan': 'ab'*32}, {**reference, 'basis': 'ab'*32}):
                        page(changed, 0, 'QueryIdentityMismatch')
                    changed = copy.deepcopy(action)
                    changed['bindings'][0]['interpretation']['interpretation']['digest'] = 'ab'*32
                    call(dict(open=changed), 'InvalidQueryRequest')
                    changed = copy.deepcopy(action)
                    changed['statement']['sql'] = 'SELECT COUNT(*) FROM rel_left'
                    changed['statement']['routes'] = [0]
                    changed['bindings'] = changed['bindings'][:1]
                    changed['snapshots'] = changed['snapshots'][:1]
                    call(dict(open=changed), 'QueryIdentityMismatch')
                    page(reference, 1, 'InvalidQueryCursor')
                    page(reference, '01', 'InvalidQueryCursor')
                    rows = []
                    for ordinal in range(4):
                        result = page(reference, ordinal)['page']
                        assert page(reference, ordinal)['page'] == result
                        if ordinal: page(reference, ordinal-1, 'InvalidQueryCursor')
                        if result['complete_coverage']:
                            assert ordinal == 3 and result['row'] is None
                            page(reference, ordinal+1, 'InvalidQueryCursor')
                        else: rows.append(result['row'])
                    assert values(rows) == expected, rows
                    assert len({json.dumps(row['identity'], sort_keys=True) for row in rows}) == 3
                    finish(action, reference)
                    page(reference, 0, 'InvalidQueryCursor')
                    call(dict(open=action), 'QueryIdentityMismatch')
                action, opened = prepare(4)
                reference = opened['reference']
                first = page(reference, 0)['page']
                policy(False)
                try:
                    assert page(reference, 0, 'AccessDenied')['diagnostic']['category'] == 'access'
                finally: policy(True)
                assert page(reference, 0)['page'] == first
                restart()
                # A killed node can invalidate the caller's pooled socket. Its
                # unavailable read authorizes only an exact retry of this page.
                for attempt in range(4):
                    try:
                        assert page(reference, 0)['page'] == first
                        break
                    except Failure as failure:
                        assert failure.status == 7 and any(action and action['kind'] == 'retry_read' for action in failure.detail['diagnostic']['actions']), failure.detail
                        if attempt == 3: raise
                # Abrupt port loss expires only the local query; original pins survive.
                if family == 'port':
                    query.child.kill(); query.child.wait(timeout=15)
                query.close()
                query = start()
                page(reference, 0, 'InvalidQueryCursor')
                assert call(dict(open=action))['opened'] == opened
                finish(action, reference)
                query.close()
                fixture.configuration['options']['output_rows'] = '1'
                query = start()
                action, opened = prepare(5)
                reference = opened['reference']
                assert not page(reference, 0)['page']['complete_coverage']
                failed = page(reference, 1, 'RelationalResultBudget')
                assert page(reference, 1, 'RelationalResultBudget') == failed
                finish(action, reference)
                query.close()
                fixture.configuration['options']['output_rows'] = '1000'
                query = start()
                action, opened = prepare(6, 'SELECT SUM(v) AS total FROM rel_overflow', (0,))
                reference = opened['reference']
                failed = page(reference, 0, 'Overflow')
                assert page(reference, 0, 'Overflow') == failed
                facts = {fact['field']: fact for fact in failed['diagnostic']['facts'] if fact}
                assert facts['completion']['value'] == {'boolean': False} and facts['column']['value'] == {'text': 'total'}, facts
                assert facts['source_key']['value']['text'][-8:] == '00000001', facts
                finish(action, reference)
                results.append(dict(caller=family, calls=calls, join_layouts=3, current_denial=True, node_replacement=True, original_retention=True, ordered_overflow=True, budget_preserves_failure=True))
            finally:
                if query is not None: query.close()
        if language:
            from sdk.sdk_relational import exercise as installed
            results += installed((language,), authority, service, root, fixture, policy)
        assert not fixture.pins, 'The proof left durable retention open'
        print(json.dumps(dict(profile='direct-relational-callers', results=results)), flush=True)
    finally:
        fixture.close()
