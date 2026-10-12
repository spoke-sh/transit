"""Independent per-basis relational and delta checks over the real disk owner."""
import json
import time
from relational import evaluate


def run(call, execute, applied, secondary, root, sql, restart, arm, hold, release, measurements):
    started = time.monotonic()
    initial_turns = measurements['turns']
    source_rows = [dict(), dict()]
    left = [[1, 7, 10], [2, 7, 20], [3, 9, 30], [4, None, 40]]
    right = [[1, 7, 90]]

    def root_key(head):
        return json.dumps(head['index'], sort_keys=True)

    def remember(side, rows):
        name = 'rel_left' if side == 0 else 'rel_right'
        inspected = call('inspect', name, directory=secondary if side else None)
        source_rows[side][root_key(inspected['head'])] = [list(row) for row in rows]
        return inspected['head']

    remember(0, left)
    remember(1, right)
    call('maintained-plan', sql, secondary)
    call('maintained-enqueue')
    for _ in range(1000):
        call('maintained-pump', 1)
        status = call('maintained-status')
        if status['state'] == 'running':
            break
    else:
        raise AssertionError('Maintained backfill did not start')
    assert status['revision'] == 0
    # More than one source transaction arrives while B0 is incomplete. Each
    # immutable Table root maps to independently specified input rows; private
    # reservation/no-op heads retain the same root and the same finite answer.
    applied(execute(910001, 'INSERT INTO rel_right VALUES (7,2)', directory=secondary))
    right.append([2, 7, 2])
    remember(1, right)
    applied(execute(910002, 'UPDATE rel_right SET v = 5', directory=secondary))
    right = [[1, 7, 5], [2, 7, 5]]
    remember(1, right)
    applied(execute(910003, 'DELETE FROM rel_right', directory=secondary))
    right = []
    remember(1, right)
    applied(execute(910004, 'INSERT INTO rel_right VALUES (7,3)', directory=secondary))
    right = [[3, 7, 3]]
    latest = remember(1, right)
    arm()
    call('maintained-pump', 1, fail=True, expected_error='InvalidAuthorityResponse')
    assert (root / 'relational-worker.json').exists()
    restart()
    call('maintained-rotate')

    feed = None

    def finish(allow_failure=False):
        for _ in range(500):
            call('maintained-pump', 10 if feed else 100)
            status = call('maintained-status')
            if feed and status['state'] in ('admitted', 'running'):
                feed()
            if status['state'] == 'idle':
                return status
            if allow_failure and status['state'] == 'failed':
                return status
            assert status['state'] in ('admitted', 'running'), status
        raise AssertionError('Maintained revision did not finish within proof work bound')

    def cells(row):
        return [None if 'null' in item['cell'] else int(next(iter(item['cell']['value']['atom'].values())))
                for item in row['values']]

    def key(row):
        # This schedule groups by one nullable int64 key. Stable identity and
        # values are checked separately so duplicate values cannot hide a loss.
        group = row['identity']['group']
        return tuple(group['values'][:group['len']])

    def expected(manifest):
        inputs = [source_rows[i][root_key(entry['record']['head'])] for i, entry in enumerate(manifest['vector'])]
        case = dict(join='left', left=inputs[0], right=inputs[1], group_by=['l.key'], outputs=[
            ['k', 'column', 'l.key'], ['rows', 'count_all'], ['present', 'count', 'r.value'], ['total', 'sum', 'r.value']])
        result = evaluate(case)
        assert result['error'] is None, result
        return {tuple(row['identity']): row['values'] for row in result['rows']}

    finish()
    snapshot = call('maintained-result', 1)
    assert snapshot['complete'] and snapshot['manifest']['revision'] == 1
    exact = {key(row): cells(row) for row in snapshot['events']}
    assert exact == expected(snapshot['manifest']), (snapshot, exact)
    assert exact[(7,)] == [7, 2, 2, 180], exact
    previous = snapshot['manifest']
    position_path = root / 'maintained-position.json'
    initial_position = position_path.read_text()
    noops, changes, revisions = 0, 0, 1
    accepted = {}
    publications = []

    def next_revision(allow_failure=False):
        nonlocal previous, exact, noops, changes, revisions
        call('maintained-wake')
        status = finish(allow_failure)
        if status['state'] == 'failed':
            assert status['revision'] == previous['revision']
            assert status['manifest'] == previous['reference']['record']
            return False
        if status['revision'] == previous['revision']:
            return False
        assert status['revision'] == previous['revision'] + 1, (status, previous)
        saved = position_path.read_text()
        delta = call('maintained-next')
        position = position_path.read_text()
        position_path.write_text(saved)
        assert call('maintained-next') == delta, 'A repeated exact delta changed its bytes or coverage'
        assert position_path.read_text() == position
        manifest = delta['manifest']
        assert manifest['previous'] == previous['reference']
        moved = []
        for index, (old, new) in enumerate(zip(previous['vector'], manifest['vector'])):
            if new['record']['head']['revision'] != old['record']['head']['revision']:
                assert new['record']['head']['revision'] == old['record']['head']['revision'] + 1
                assert new['position'] > old['position']
                moved.append(index)
        assert len(moved) == 1, (previous, manifest)
        proposed = dict(exact)
        seen = set()
        for change in delta['events']:
            before, after = change['before'], change['after']
            identity = key(before or after)
            assert identity not in seen
            seen.add(identity)
            if before is not None:
                assert proposed.pop(identity) == cells(before), (change, exact)
            else:
                assert identity not in proposed
            if after is not None:
                assert identity == key(after)
                proposed[identity] = cells(after)
        assert proposed == expected(manifest), (manifest, proposed, expected(manifest))
        snapshot = call('maintained-result', manifest['revision'])
        assert {key(row): cells(row) for row in snapshot['events']} == proposed
        assert snapshot['manifest'] == manifest
        assert position_path.read_text() == position
        exact, previous = proposed, manifest
        source_revision = manifest['vector'][1]['record']['head']['revision']
        if source_revision in accepted:
            publications.append(dict(source_revision=source_revision, relation_revision=manifest['revision'],
                lag_seconds=round(time.monotonic() - accepted.pop(source_revision), 3)))
        noops += not delta['events']
        changes += bool(delta['events'])
        revisions += 1
        print(json.dumps(dict(profile='maintained-basis', revision=manifest['revision'],
            deltas=manifest['deltas'], outputs=manifest['outputs'], state_bytes=manifest['state_bytes'])), flush=True)
        return True

    for _ in range(100):
        if not next_revision():
            break
    else:
        raise AssertionError('Maintained catch-up exceeded transaction bound')
    assert previous['vector'][1]['record']['head']['revision'] == latest['revision']
    assert noops > 0 and changes == 4, (noops, changes)
    assert exact[(7,)] == [7, 2, 2, 6]
    # Both sides change over the schedule. Empty output changes on reservation
    # heads are still published before the complete left-side insertion.
    applied(execute(910005, 'INSERT INTO rel_left VALUES (7,50)'))
    left.append([5, 7, 50])
    latest_left = remember(0, left)
    for _ in range(20):
        if not next_revision():
            break
    assert previous['vector'][0]['record']['head']['revision'] == latest_left['revision']
    assert exact[(7,)] == [7, 3, 3, 9]
    # Pace new complete source transactions between bounded maintenance quanta.
    # Root-signed requests remain serialized; no host threads share a sequence.
    # Every reservation/no-op basis still goes through the independent oracle.
    ongoing_started = time.monotonic()
    ongoing_state_before = previous['state_bytes']
    arrivals = []
    backlog_highwater = 0

    def offer():
        nonlocal right, latest, backlog_highwater, feed
        value = 4 + len(arrivals)
        begin, turns = time.monotonic(), measurements['turns']
        applied(execute(910006 + len(arrivals), f'UPDATE rel_right SET v = {value}', directory=secondary))
        accepted_at = time.monotonic()
        right = [[3, 7, value]]
        latest = remember(1, right)
        accepted[latest['revision']] = accepted_at
        backlog = latest['revision'] - previous['vector'][1]['record']['head']['revision']
        backlog_highwater = max(backlog_highwater, backlog)
        arrivals.append(dict(source_revision=latest['revision'], value=value,
            accepted_seconds=round(accepted_at - ongoing_started, 3),
            mutation_seconds=round(accepted_at - begin, 3), mutation_turns=measurements['turns'] - turns,
            backlog_head_revisions=backlog))
        if len(arrivals) == 3:
            feed = None

    offer()
    feed = offer
    for _ in range(30):
        if not next_revision():
            break
    else:
        raise AssertionError('Ongoing input did not drain within its transaction bound')
    assert len(arrivals) == 3 and not accepted and len(publications) == 3
    assert previous['vector'][1]['record']['head']['revision'] == latest['revision']
    assert exact[(7,)] == [7, 3, 3, 18]
    ongoing = dict(arrivals=arrivals, publications=publications,
        backlog_highwater_head_revisions=backlog_highwater, final_backlog=0,
        seconds=round(time.monotonic() - ongoing_started, 3),
        catch_up_after_last_input_seconds=round(time.monotonic() - ongoing_started - arrivals[-1]['accepted_seconds'], 3),
        retained_state_before=ongoing_state_before, retained_state_after=previous['state_bytes'])
    print(json.dumps(dict(profile='maintained-ongoing-input', **ongoing)), flush=True)
    # Saving no definition is not a way to silently upgrade an old cursor.
    saved = position_path.read_text()
    for field in ('version', 'definition'):
        malformed = json.loads(saved)
        del malformed[field]
        position_path.write_text(json.dumps(malformed))
        call('maintained-next', fail=True, expected_error='MissingField')
    position_path.write_text(saved)
    call('maintained-next', fail=True, expected_error='MaintainedRevisionPending')
    call('maintained-delta', fail=True, expected_error='MaintainedResetRequired')
    # Current read denial covers a frozen result, including a noncontributing
    # source. It does not overwrite the last complete publication.
    held = hold(str(previous['revision']), 'maintained-result-held')
    call('policy', 'deny', directory=secondary)
    call('pump', directory=secondary)
    release(held, 'CatalogDenied')
    call('maintained-result', fail=True, expected_error='CatalogDenied')
    call('policy', 'allow', directory=secondary)
    call('pump', directory=secondary)
    position_path.write_text(initial_position)
    replay = call('maintained-next')
    assert replay['manifest']['revision'] == 2
    # A newly committed schema cannot be interpreted as the old query schema.
    # Retained complete output remains bound to the original schema and basis.
    before_schema = revisions
    position_path.write_text(saved)
    applied(execute(910009, 'ALTER TABLE rel_right ADD COLUMN extra BIGINT', directory=secondary))
    for _ in range(10):
        if not next_revision(allow_failure=True):
            break
    failed = call('maintained-status')
    assert failed['state'] == 'failed' and failed['manifest'] == previous['reference']['record'], failed
    failure = call('maintained-failure')
    assert failure['cause'] == 'TableSchemaChanged' and failure['last_revision'] == previous['revision'], failure
    retained = call('maintained-result', previous['revision'])
    assert retained['manifest'] == previous
    assert {key(row): cells(row) for row in retained['events']} == exact
    call('maintained-retire')
    call('maintained-clean')
    call('maintained-plan', sql, secondary)
    call('maintained-enqueue')
    finish()
    rebuilt = call('maintained-result', 1)
    assert {key(row): cells(row) for row in rebuilt['events']} == exact
    applied(execute(910010, 'DROP TABLE rel_right', directory=secondary))
    for _ in range(10):
        call('maintained-wake')
        dropped = finish(allow_failure=True)
        if dropped['state'] == 'failed':
            assert dropped['manifest'] == rebuilt['manifest']['reference']['record']
            break
        successor = call('maintained-result', dropped['revision'])
        assert successor['manifest']['revision'] == rebuilt['manifest']['revision'] + 1
        assert successor['manifest']['previous'] == rebuilt['manifest']['reference']
        assert {key(row): cells(row) for row in successor['events']} == exact
        rebuilt = successor
    drop_failure = call('maintained-failure')
    assert drop_failure['cause'] == 'TableRetired' and drop_failure['last_revision'] == rebuilt['manifest']['revision'], drop_failure
    assert call('maintained-result', rebuilt['manifest']['revision'])['manifest'] == rebuilt['manifest']
    # Reusing the SQL name assigns a different object. Saved work still names
    # the retired object and cannot switch to the replacement's empty relation.
    applied(execute(910011, 'CREATE TABLE rel_right (k BIGINT, v BIGINT)', object_id=2, directory=secondary))
    call('maintained-wake')
    call('maintained-pump')
    assert call('maintained-failure') == drop_failure
    assert call('maintained-result', rebuilt['manifest']['revision'])['manifest'] == rebuilt['manifest']
    call('maintained-worker-deny')
    call('maintained-retire')
    call('maintained-clean')
    assert call('maintained-status')['released']
    call('maintained-result', fail=True, expected_error='MaintainedResetRequired')
    result = dict(profile='maintained-relational-native', revisions=revisions, changing_revisions=changes,
                  no_op_revisions=noops, seconds=round(time.monotonic() - started, 3),
                  turns=measurements['turns'] - initial_turns, retained_state_bytes=previous['state_bytes'],
                  exact_delta_retry=True, delayed_backfill=True, disk_restart=True, current_denial=True,
                  ongoing_input=ongoing, schema_successor_rejected=True, schema_failure=failure,
                  schema_no_op_revisions=revisions - before_schema,
                  drop_successor_rejected=True, drop_name_reuse_preserves_failure=True, drop_failure=drop_failure)
    print(json.dumps(result))
    return result
