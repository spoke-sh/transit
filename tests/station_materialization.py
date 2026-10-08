"""Shared Station Tables recover current rows from a checkpoint and its tail."""
import json
import os
from pathlib import Path
import time

from inspection import System
from cold_storage import ColdStore
from station import frame
from storage import wait_ready


def run(node, cli, libraries):
    with ColdStore() as cold:
        _run(node, cli, libraries, cold)


def _run(node, cli, libraries, cold):
    from station_growing_abi import Native
    from abi_support import Client
    with System(node, cli, clock_error_ms=10000, allow_history_trim=True, storage_config=cold.config()) as s:
        pid = s.command({"create": {"required": [b"data".hex(), None, None, None]}})
        resource = s.command({"create_resource": {"writer": pid, "history_ms": 0}})
        seed, public = s.key("materializer")
        s.command({"grant": {"subject": 1, "public_key": public, "permissions": 88, "pid": pid}})
        for subject in (0, 1):
            s.command({"grant_resource": {"resource": resource, "subject": subject, "permissions": 7}})
        s.command({"associate": {"pid": pid, "name": b"data".hex(), "resource": resource}})
        s.command({"initialize": {"pid": pid, "expected_generation": 1}})
        s.command({"own": {"pid": pid, "worker": 1, "expected_generation": 2}})
        config = {"profile": "native_v1", "realm": 72, "principal": 1, "pid": pid, "generation": 3, "failure_policy": "stop"}

        callbacks = 0

        def turn(actions):
            nonlocal callbacks
            command = {"send": {"pid": pid, "value": frame(b"change")}}
            position = s.command(command)
            assert s.post("/v1/command", s.signed(command, s.sequence))["position"] == position
            # Every turn uses a fresh host and reconstructs the Table snapshot.
            server = Native(libraries, s.url, seed, config)
            try:
                for _ in range(12):
                    event = server.prepare()
                    if event['event'] == 'ready': break
                    if event['event'] == 'pending': server.dispatch()
                else: raise AssertionError('No scoped Table turn')
                assert event['input']['position'] == position
                callbacks += 1
                definition = server.api.call('station_growing_capabilities')['definition']
                results = [server.apply(event['scope'], {'table': action})['table']
                           for action in actions(position, definition)]
                server.finish(event['scope'])
                frozen = server.pending().decode()
                assert server.dispatch()['event'] == 'committed'
            finally:
                server.close()
            with Client(libraries, s.url) as client:
                # Retry after all Station handles are gone, never repeat effects.
                receipt = client.call(frozen)
                # Back-to-back calls must reuse the bounded native pool without
                # treating its retiring workers as a failed/uncertain request.
                for _ in range(16):
                    assert client.call(frozen) == receipt
            return position, results

        signed = lambda value: {'value': {'atom': {'signed': str(value)}}}
        schema = None

        def create(_, definition):
            nonlocal schema
            schema = dict(definition=definition, object='1', revision='1', next_column='4',
                columns=[dict(id=str(i), name=name, type={kind: {}}, nullable=False,
                    default={'value': {'atom': {'utf8': 'materialized'}}} if i == 3 else None,
                    max_characters=None)
                    for i, name, kind in ((1, 'id', 'int64'), (2, 'amount', 'int64'), (3, 'label', 'utf8'))],
                primary_key=['1'])
            return [{'create': dict(realm=72, resource=resource, schema=schema,
                limits=dict(record_bytes=65536, staging_bytes='8388608', staging_records=1024))}]

        def complete(actions, result_name):
            for _ in range(512):
                _, results = turn(actions)
                result = results[0][result_name]
                if result['state'] != 'building':
                    assert result['state'] == 'applied', result
                    return result
            raise AssertionError('Materialization continuation budget exhausted')

        def mutate(action, key=None):
            original = None
            def actions(position, _):
                nonlocal original
                if original is None: original = position
                predicate = None if key is None else [
                    {'atom': {'compare': dict(column='1', op='eq', value={'signed': str(key)})}}]
                return [{'mutate': dict(realm=72, resource=resource, principal=0,
                    operation=str(original), schema=schema,
                    mutation=dict(action=action, predicate=predicate))}]
            result = complete(actions, 'mutation')
            assert result['admitted_input'] == original
            return result

        def insert(*pairs):
            rows = [[dict(column=str(i + 1), value={'cell': signed(value)})
                     for i, value in enumerate(pair)] for pair in pairs]
            return mutate({'insert': rows})

        def update(key, value):
            return mutate({'update': [dict(column='2', value={'cell': signed(value)})]}, key)

        def read():
            _, results = turn(lambda *_: [{'get_key': dict(source={'object': '1'}, key=[signed(key)])}
                                         for key in (1, 2)])
            assert all(result['row']['definition']['schema'] == schema for result in results)
            return [result['row']['row'] for result in results]

        complete(create, 'created')
        assert insert((1, 7), (2, 5))['counts'] == {'matched': '2', 'changed': '2'}
        initial = read()
        assert update(1, 9)['counts'] == {'matched': '1', 'changed': '1'}
        assert mutate({'delete': {}}, 2)['counts'] == {'matched': '1', 'changed': '1'}
        before = read()
        assert before[0]['identity'] == initial[0]['identity'] and before[1] is None
        maintenance_seed, maintenance_key = s.key("maintenance")
        s.command({"grant": {"subject": 2, "public_key": maintenance_key, "permissions": 161}})
        maintenance_config = s.root / "maintenance.json"
        maintenance_config.write_text(json.dumps({**json.loads(s.config.read_text()), "maintenance": {
            "principal": 2, "seed_file": str(maintenance_seed), "interval_ms": 25, "checkpoint_every_records": 4}}))
        maintenance = s.start(node, maintenance_config, "--maintain", env=os.environ | {"LOG_LEVEL": "info", "LOG_FORMAT": "json"})
        until = time.monotonic() + 15
        while True:
            assert maintenance.poll() is None and time.monotonic() < until
            try:
                if s.inspect("history", pid)["history"] == "prefix_reclaimed": break
            except AssertionError as error:
                # A concurrent checkpoint invalidates the read cut; retry the
                # read, without changing any signed mutation identity.
                assert error.args[0] in ((409, {'err': 'Conflict'}, 200),
                                         (409, {'err': 'QueryExpired'}, 200)), error
            time.sleep(.1)
        # Let the checkpoint's physical publication/trim finish. The log records
        # that storage operation, not just the logical retained boundary.
        until = time.monotonic() + 15
        while '"operation":"trimmed"' not in Path(s.logs[-1].name).read_text():
            assert maintenance.poll() is None and time.monotonic() < until
            time.sleep(.05)
        maintenance.terminate(); maintenance.wait(timeout=10)
        # This update/reinsertion is in the tail after the published checkpoint.
        assert update(1, 4)['counts'] == {'matched': '1', 'changed': '1'}
        assert insert((2, 3))['counts'] == {'matched': '1', 'changed': '1'}
        s.authority.kill(); s.authority.wait(timeout=10)
        s.store.stop(); s.store.start()
        s.authority = s.start(node, s.config)
        wait_ready(s.store.http, s.authority, s.url + "/health")
        rows = read()
        for key, value, row in ((1, 4, rows[0]), (2, 3, rows[1])):
            assert row['cells'] == [signed(key), signed(value), {'value': {'atom': {'utf8': 'materialized'}}}], row
        assert rows[0]['identity'] == initial[0]['identity']
        assert rows[1]['identity'] != initial[1]['identity'], 'Reinsert reused a retired row identity'
        assert cold.data_objects() > 0
        print(f'General Table materialization: {callbacks} fresh-host callbacks, {cold.data_objects()} cold objects.')

    print("Station materialization: duplicate admission/commit, update/delete/reinsert, checkpoint/tail recovery and current-row recovery passed")
