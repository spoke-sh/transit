"""Persistent human console workload, nested in the console-latency owner."""
from collections import defaultdict
import json
import re

from performance.mutations.mutation_latency import Console, distribution


def verify_table(text, expected):
    """Independent oracle for this fixed two-integer-column workload."""
    assert text.count('┌') == text.count('└') == 1, text
    assert text.endswith(f'{len(expected)} rows; complete coverage\n'), text
    cells = [[cell.strip() for cell in line.split('│')[1:-1]]
             for line in text.splitlines() if line.startswith('│')]
    assert cells[0] == ['id', 'value'], cells
    assert cells[1] == ['int64', 'int64'], cells
    actual = sorted(tuple(map(int, row)) for row in cells[2:])
    assert actual == expected, (actual, expected)


def phases(timing):
    match = re.fullmatch(r'Time: (\d+) ms \(((?:\w+ \d+ ms, )*\w+ \d+ ms)\)', timing)
    assert match, timing
    result = {key: int(value) for key, value in re.findall(r'(\w+) (\d+) ms', match[2])}
    assert sum(result.values()) == int(match[1]), timing
    return int(match[1]), result


def run(fixture, repeat, probes, *, config=None):
    shell = Console(fixture, mode='table', config=config)
    samples = defaultdict(list)
    expected = []
    try:
        def call(case, sql):
            before = {name: probe.snapshot() for name, probe in probes.items()}
            starts = {name: probe.trace()['completed'] for name, probe in probes.items()}
            try:
                value, measurement = shell.call(sql)
            finally:
                # Preserve bounded operation/work diagnostics even when the
                # statement fails. No native payloads or credentials are kept.
                for name, probe in probes.items():
                    trace = probe.trace()
                    events = [event for event in trace['retained'] if event['ordinal'] > starts[name]]
                    print(json.dumps(dict(phase='statement_trace', case=case, probe=name,
                                          completed=trace['completed'] - starts[name],
                                          omitted=max(0, trace['completed'] - starts[name] - len(events)),
                                          events=events)), flush=True)
            total, measured_phases = phases(measurement['timing'])
            attempts = {name: dict(probe.snapshot() - before[name]) for name, probe in probes.items()}
            for counts in attempts.values():
                # These database statements must not dispatch Station turns.
                for operation in ('send', 'open_view', 'turn', 'turn_with_versions'):
                    assert counts.get('update:' + operation, 0) == 0, counts
                if case == 'select_warm':
                    assert counts.get('table:pin', 0) == 0, counts
            samples[case].append(total * 1_000_000)
            print(json.dumps(dict(phase='statement', case=case, sql=sql,
                                  **measurement, timer_ms=total, phases=measured_phases,
                                  attempts=attempts, stdout=value)), flush=True)
            return value

        def typed_readback(case):
            shell.process.stdin.write(b'.mode json\n')
            shell.process.stdin.flush()
            shell.mode = 'json'
            value = call(case, 'SELECT * FROM items;')
            actual = sorted(tuple(int(cell['value']['atom']['signed']) for cell in row)
                            for row in value['rows'])
            assert actual == expected, (actual, expected)
            assert int(value['complete']['rows']) == len(expected), value
            assert [field['name'] for field in value['schema']['type']['structure']] == ['id', 'value']
            assert all(field['type'] == {'int64': {}} for field in value['schema']['type']['structure'])
            shell.process.stdin.write(b'.mode table\n')
            shell.process.stdin.flush()
            shell.mode = 'table'

        verify_table(call('select_cold', 'SELECT * FROM items;'), expected)
        verify_table(call('select_warm', 'SELECT * FROM items;'), expected)
        for index in range(1, repeat + 1):
            output = call('insert', f'INSERT INTO items (id, value) VALUES ({index}, {index * 10});')
            assert output == 'Statement completed. Matched 1; changed 1.\n', output
            expected.append((index, index * 10))
            verify_table(call('select_after_write', 'SELECT * FROM items;'), expected)
            verify_table(call('select_warm', 'SELECT * FROM items;'), expected)
        typed_readback('select_json_after_insert')
        # Exercise changed/no-op/zero-match outcomes and read-after-write for
        # the other executable DML kinds. TRUNCATE has no execution contract.
        for index in range(1, repeat + 1):
            output = call('update', f'UPDATE items SET value = {index * 100} WHERE id = {index};')
            assert output == 'Statement completed. Matched 1; changed 1.\n', output
            expected[index - 1] = (index, index * 100)
            verify_table(call('select_after_update', 'SELECT * FROM items;'), expected)
            output = call('update_noop', f'UPDATE items SET value = {index * 100} WHERE id = {index};')
            assert output == 'Statement completed. Matched 1; changed 0.\n', output
        output = call('update_empty', 'UPDATE items SET value = 0 WHERE id = -1;')
        assert output == 'Statement completed. Matched 0; changed 0.\n', output
        typed_readback('select_json_after_update')
        for index in range(1, repeat + 1):
            output = call('delete', f'DELETE FROM items WHERE id = {index};')
            assert output == 'Statement completed. Matched 1; changed 1.\n', output
            expected.remove((index, index * 100))
            verify_table(call('select_after_delete', 'SELECT * FROM items;'), expected)
        output = call('delete_empty', 'DELETE FROM items WHERE id = -1;')
        assert output == 'Statement completed. Matched 0; changed 0.\n', output
        typed_readback('select_json_after_delete')
        print(json.dumps(dict(phase='statement_summary', distributions={
            case: distribution(values) for case, values in samples.items()})), flush=True)
    finally:
        shell.close()


def tls(root, port, console, repeat, *, probes=None):
    """Same workload over the SQL wire fixture; optional upstream diagnostics."""
    from types import SimpleNamespace
    config = root / 'latency.yaml'
    password = root / 'latency.password'
    password.write_text('proof-password')
    password.chmod(0o600)
    config.write_text(f'version: 1\nendpoint: https://localhost:{port}\naccount: proof\ndatabase: data\nauthentication: scram\nca_file: {root / "certificate.pem"}\npassword_file: {password}\nformat: table\n')
    fixture = SimpleNamespace(root=root, cli=console)
    shell = Console(fixture, config=config, mode='table')
    try:
        value, timing = shell.call('CREATE TABLE items (id INT64, value INT64);')
        assert value.startswith('Statement completed.'), value
        print(json.dumps(dict(phase='setup', timing=timing)), flush=True)
    finally:
        shell.close()
    run(fixture, repeat, probes or {}, config=config)
