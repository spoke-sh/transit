"""Fresh/reopened installed startup, nested in the console-latency owner."""
import json
from pathlib import Path
import time

from interfaces.cli.table_console import records


def timings(path):
    """Export only bounded timing labels; reject incomplete diagnostic evidence."""
    phases, attempts = [], []
    losses = dict(dropped=0, suppressed=0)
    with Path(path).open('rb') as source:
        while line := source.readline(2049):
            if len(line) > 2048:
                raise ValueError('startup log record exceeds telemetry bound')
            record = json.loads(line)
            if record.get('name') == 'telemetry.loss':
                for key in losses:
                    losses[key] = max(losses[key], record.get('measurement', {}).get(key, 0))
            event = record.get('event', {})
            name = event.get('name')
            if name not in ('server.startup.phase', 'server.startup.complete'):
                continue
            if len(phases) + len(attempts) == 256:
                raise ValueError('startup timing record bound exceeded')
            duration = record.get('duration_ns')
            if type(duration) is not int or duration < 0:
                raise ValueError('missing or invalid startup duration')
            item = dict(duration_ns=duration, outcome=event['outcome'])
            if name == 'server.startup.complete':
                item['span_id'] = record['span_id']
                attempts.append(item)
            else:
                operation = event['operation']
                if not isinstance(operation, str) or len(operation) > 64 or not operation.replace('_', '').isascii() or not operation.replace('_', '').isalnum():
                    raise ValueError('invalid startup phase')
                item.update(operation=operation, parent_span_id=record['parent_span_id'])
                phases.append(item)
    if (any(losses.values()) or not attempts or attempts[-1]['outcome'] != 'ok' or
            sum(a['outcome'] == 'ok' for a in attempts) != 1):
        raise ValueError('incomplete startup timing evidence')
    for attempt in attempts:
        children = [p for p in phases if p['parent_span_id'] == attempt['span_id']]
        if not children or sum(p['duration_ns'] for p in children) > attempt['duration_ns']:
            raise ValueError('missing or overlapping startup phases')
        attempt['unattributed_ns'] = attempt['duration_ns'] - sum(p['duration_ns'] for p in children)
        if attempt['outcome'] == 'ok' and (children[-1]['operation'] != 'sql_readiness' or
                                         any(p['outcome'] != 'ok' for p in children)):
            raise ValueError('startup timing does not reach SQL readiness')
    if any(p['parent_span_id'] not in {a['span_id'] for a in attempts} for p in phases):
        raise ValueError('startup phase has no terminal attempt')
    return dict(attempts=attempts, phases=phases, losses=losses)


def run(fixture, restarts):
    retained = None
    for index in range(restarts + 1):
        started = time.perf_counter_ns()
        fixture.start()
        fixture.ready()
        ready_ns = time.perf_counter_ns() - started
        # Readiness is separately checked by an actual complete console result.
        # Timed startup excludes this read and the first-run write fixture.
        verified = time.perf_counter_ns()
        result, = fixture.console('SELECT * FROM items;')
        expected = [] if index == 0 else [(1, 73)]
        actual = records(result)
        assert all(set(row) == {'id', 'value'} for row in actual), actual
        assert [(int(row['id']), int(row['value'])) for row in actual] == expected, result
        verify_ns = time.perf_counter_ns() - verified
        if index == 0:
            result, = fixture.console('INSERT INTO items (id, value) VALUES (1, 73);')
            assert int(result['completion']['counts']['changed']) == 1, result
        identity = {key: fixture.record()[key] for key in
                    ('installation', 'root_public', 'provision', 'authorization_steps')}
        if retained is not None:
            assert identity == retained, 'restart replaced retained installation identity'
        retained = identity
        fixture.stop()  # Join and flush the bounded diagnostic sink before reading.
        trace = timings(fixture.logs[-1].name)
        print(json.dumps(dict(phase='startup', profile='fresh' if index == 0 else 'restart',
            index=index, ready_ns=ready_ns, verification_ns=verify_ns,
            verified_rows=len(expected), **trace)), flush=True)
