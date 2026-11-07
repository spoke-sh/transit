"""Persistent human console workload, nested in the console-latency owner."""
from collections import defaultdict
import json
import re
import time

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


def run(fixture, repeat, probes, *, config=None, resource_observer=None, cpu_observer=None, cycles=1, warm_reads=1):
    shell = Console(fixture, mode='table', config=config)
    samples = defaultdict(list)
    expected = []
    try:
        def call(case, sql):
            before = {name: probe.snapshot() for name, probe in probes.items()}
            starts = {name: probe.trace()['completed'] for name, probe in probes.items() if hasattr(probe, 'trace')}
            before_cpu = cpu_observer() if cpu_observer is not None else None
            started_unix_ns = time.time_ns()
            try:
                value, measurement = shell.call(sql)
            except Exception:
                print(json.dumps(dict(phase='statement_failure', case=case, cycle=cycle,
                                      **shell.last_measurement)), flush=True)
                raise
            finally:
                finished_unix_ns = time.time_ns()
                node_cpu_seconds = cpu_observer() - before_cpu if before_cpu is not None else None
                # Preserve bounded operation/work diagnostics even when the
                # statement fails. No native payloads or credentials are kept.
                for name, probe in probes.items():
                    if name not in starts:
                        continue
                    trace = probe.trace()
                    events = [event for event in trace['retained'] if event['ordinal'] > starts[name]]
                    print(json.dumps(dict(phase='statement_trace', case=case, cycle=cycle, probe=name,
                                          completed=trace['completed'] - starts[name],
                                          omitted=max(0, trace['completed'] - starts[name] - len(events)),
                                          events=events)), flush=True)
            total, measured_phases = phases(measurement['timing'])
            attempts = {name: dict(probe.snapshot() - before[name]) for name, probe in probes.items()}
            for name, counts in attempts.items():
                if name == 'local':
                    continue  # Aggregate typed attempts do not classify operations.
                # These database statements must not dispatch Station turns.
                for operation in ('send', 'open_view', 'turn', 'turn_with_versions'):
                    assert counts.get('update:' + operation, 0) == 0, counts
                if case in ('select_warm', 'select_empty_warm', 'select_one_warm'):
                    assert counts.get('table:pin', 0) == 0, counts
            samples[case].append(total * 1_000_000)
            print(json.dumps(dict(phase='statement', case=case, cycle=cycle, sql=sql,
                                  **measurement, timer_ms=total, phases=measured_phases,
                                  attempts=attempts, node_cpu_seconds=node_cpu_seconds,
                                  started_unix_ns=started_unix_ns, finished_unix_ns=finished_unix_ns,
                                  stdout=value)), flush=True)
            if resource_observer is not None:
                print(json.dumps(dict(phase='client_resources', case=case, cycle=cycle,
                                      **resource_observer(shell.process.pid))), flush=True)
            return value

        def set_mode(mode):
            if shell.mode == mode:
                return
            shell.process.stdin.write(f'.mode {mode}\n'.encode())
            shell.process.stdin.flush()
            shell.mode = mode

        def typed_readback(case):
            set_mode('json')
            value = call(case, 'SELECT * FROM items;')
            actual = sorted(tuple(int(cell['value']['atom']['signed']) for cell in row)
                            for row in value['rows'])
            assert actual == expected, (actual, expected)
            assert int(value['complete']['rows']) == len(expected), value
            assert [field['name'] for field in value['schema']['type']['structure']] == ['id', 'value']
            assert all(field['type'] == {'int64': {}} for field in value['schema']['type']['structure'])
            set_mode('table')

        def claim_row(case, sql, expected_pair):
            set_mode('json')
            value = call(case, sql)
            assert int(value['complete']['rows']) == 1 and len(value['rows']) == 1, value
            row = value['rows'][0]
            actual_pair = (int(row[0]['value']['atom']['signed']), int(row[1]['value']['atom']['signed']))
            assert actual_pair == expected_pair, (actual_pair, expected_pair)
            receipt_hex = row[2]['value']['atom']['binary']
            assert len(receipt_hex) == 336 and bytes.fromhex(receipt_hex)[:4] == b'QLH1', receipt_hex
            set_mode('table')
            return receipt_hex

        for setup_sql in (
            'CREATE STREAM events (id INT64, value INT64);',
            "CREATE QUEUE tasks (id INT64, value INT64) WITH (max_lease_duration='5m', max_attempts=1);",
        ):
            setup_value, setup_measurement = shell.call(setup_sql)
            assert setup_value == 'Statement completed. Matched 0; changed 0.\n', setup_value
            print(json.dumps(dict(phase='workload_setup', sql=setup_sql, **setup_measurement)), flush=True)

        stream_next_offset = 0
        # Each cycle returns to the verified empty table and settled queue in the same session.
        # With repeat=1 this keeps every steady-state case at zero or one row.
        for cycle in range(cycles):
            verify_table(call('select_cold' if cycle == 0 else 'select_empty', 'SELECT * FROM items;'), expected)
            for _ in range(warm_reads):
                verify_table(call('select_empty_warm' if cycles > 1 or warm_reads > 1 else 'select_warm', 'SELECT * FROM items;'), expected)
            for index in range(1, repeat + 1):
                output = call('insert', f'INSERT INTO items (id, value) VALUES ({index}, {index * 10});')
                assert output == 'Statement completed. Matched 1; changed 1.\n', output
                expected.append((index, index * 10))
                verify_table(call('select_after_write', 'SELECT * FROM items;'), expected)
                for _ in range(warm_reads):
                    verify_table(call('select_one_warm' if cycles > 1 or warm_reads > 1 else 'select_warm', 'SELECT * FROM items;'), expected)
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

            cycle_stream_start = stream_next_offset
            for index in range(1, repeat + 1):
                verify_table(
                    call('stream_consume_empty', f'CONSUME id, value FROM events WHERE _offset >= {stream_next_offset} LIMIT 1;'),
                    [],
                )
                output = call('stream_produce', f'PRODUCE INTO events (id, value) VALUES ({index}, {index * 10});')
                assert output == 'Statement completed. Matched 1; changed 1.\n', output
                offset = stream_next_offset
                stream_next_offset += 1
                verify_table(
                    call('stream_consume_after_produce', f'CONSUME id, value FROM events WHERE _offset >= {offset} LIMIT 1;'),
                    [(index, index * 10)],
                )
                for _ in range(warm_reads):
                    verify_table(
                        call('stream_consume_warm', f'CONSUME id, value FROM events WHERE _offset >= {offset} LIMIT 1;'),
                        [(index, index * 10)],
                    )
            set_mode('json')
            stream_json = call('stream_consume_json', f'CONSUME id, value FROM events WHERE _offset >= {cycle_stream_start} LIMIT {repeat};')
            actual_stream = [tuple(int(cell['value']['atom']['signed']) for cell in row) for row in stream_json['rows']]
            expected_stream = [(index, index * 10) for index in range(1, repeat + 1)]
            assert actual_stream == expected_stream, (actual_stream, expected_stream)
            assert int(stream_json['complete']['rows']) == repeat, stream_json
            set_mode('table')

            for index in range(1, repeat + 1):
                verify_table(call('queue_claim_empty', "CLAIM id, value FROM tasks LIMIT 1 WITH LEASE '30s';"), [])
                output = call('queue_enqueue', f'ENQUEUE INTO tasks (id, value) VALUES ({index}, {index * 10});')
                assert output == 'Statement completed. Matched 1; changed 1.\n', output
                receipt_hex = claim_row(
                    'queue_claim',
                    "CLAIM id, value, _receipt_handle FROM tasks LIMIT 1 WITH LEASE '30s';",
                    (index, index * 10),
                )
                set_mode('json')
                renewed = call('queue_extend_lease', f"EXTEND LEASE ON QUEUE tasks RECEIPT X'{receipt_hex}' BY '30s';")
                assert int(renewed['complete']['rows']) == 1 and len(renewed['rows']) == 1, renewed
                renewed_hex = renewed['rows'][0][0]['value']['atom']['binary']
                assert len(renewed_hex) == 336 and renewed_hex[:320] == receipt_hex[:320] and renewed_hex != receipt_hex, (receipt_hex, renewed_hex)
                set_mode('table')
                output = call('queue_ack', f"ACK ON QUEUE tasks RECEIPT X'{renewed_hex}';")
                assert output == 'Statement completed.\n', output
                output = call('queue_enqueue_nack', f'ENQUEUE INTO tasks (id, value) VALUES ({-index}, {-index * 10});')
                assert output == 'Statement completed. Matched 1; changed 1.\n', output
                nack_hex = claim_row(
                    'queue_claim_nack',
                    "CLAIM id, value, _receipt_handle FROM tasks LIMIT 1 WITH LEASE '30s';",
                    (-index, -index * 10),
                )
                output = call('queue_nack', f"NACK ON QUEUE tasks RECEIPT X'{nack_hex}';")
                assert output == 'Statement completed.\n', output
                verify_table(call('queue_claim_after_ack', "CLAIM id, value FROM tasks LIMIT 1 WITH LEASE '30s';"), [])
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
