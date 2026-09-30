"""Document scoped publication and owned reads through both native transports."""
import json
from pathlib import Path
import sys
import time

from client_abi_growing import GrowingSystem
from station import frame
from abi_support import rejects
from station_growing_abi import Native, Port
from abi_support import Client, _json


class DocumentSystem(GrowingSystem):
    resident_pages = 64


def run(node, cli, library, raw_library, host):
    started = time.monotonic()
    with DocumentSystem(node, cli) as system:
        libraries = system.root / 'libraries'
        libraries.mkdir()
        for name, source in (('station', library), ('client', raw_library)):
            (libraries / f'libtransit_{name}.so').symlink_to(Path(source).resolve())
        root = Client(libraries, system.url)
        sequence = 0

        def command(body):
            nonlocal sequence
            sequence += 1
            return root.call(root.prepare(6, system.seed, {
                'version': 1, 'realm': 72, 'principal': 0, 'sequence': sequence,
                'command': body}))['position']

        pid = command({'spawn': {}})
        resource = command({'create_resource': {'writer': pid}})
        seed, public = system.key('document-owner')
        reader_seed, reader_public = system.key('document-reader')
        command({'grant': {'subject': 65536, 'public_key': public, 'permissions': 88, 'pid': pid}})
        command({'grant': {'subject': 65537, 'public_key': reader_public, 'permissions': 16, 'pid': pid}})
        for subject, permissions in ((0, 7), (65536, 7), (65537, 3)):
            command({'grant_resource': {'resource': resource, 'subject': subject, 'permissions': permissions}})
        command({'associate': {'pid': pid, 'name': b'data'.hex(), 'resource': resource}})
        command({'own': {'pid': pid, 'worker': 65536, 'expected_generation': 1}})
        config = {'profile': 'native_v1', 'realm': 72, 'principal': 65536,
                  'pid': pid, 'generation': 2, 'failure_policy': 'stop', 'timeout_ms': 15000}
        native = Native(libraries, system.url, seed, config)
        reader = Native(libraries, system.url, reader_seed, {**config, 'principal': 65537})
        port = None
        owner = native
        turns = 0
        document = str(2**64-1)

        def codec(action):
            data = _json(action)
            return reader.api.call('station_document_codec', data, len(data))

        def read(action):
            data = _json(action)
            return reader.api.call('station_growing_document_read', reader.pointer, data, len(data))

        def call(name, *args):
            if owner is native:
                return getattr(native, name)(*args)
            actions = {'prepare': lambda: time.time_ns() // 1_000_000 + 30000,
                       'dispatch': lambda: {}, 'apply': lambda: {'scope': args[0], 'action': args[1]},
                       'finish': lambda: {'scope': args[0], 'failed': False}}
            return owner.call({'growing_' + name: actions[name]()})

        def ready():
            for _ in range(12):
                event = call('prepare')
                if event['event'] == 'ready': return event['scope']
                assert event['event'] in ('pending', 'progress'), event
                if event['event'] == 'pending': call('dispatch')
            raise AssertionError('Document owner did not produce a turn')

        def operation(action, check=None):
            nonlocal turns
            command({'send': {'pid': pid, 'value': frame(b'document-step')}})
            scope = ready()
            if check: check(scope)
            result = call('apply', scope, {'document': action})['document']
            call('finish', scope)
            assert call('dispatch')['event'] == 'committed'
            turns += 1
            return result

        def expect_error(action, name):
            command({'send': {'pid': pid, 'value': frame(b'refused-document-step')}})
            scope = ready()
            before = call('apply', scope, {'budgets': {}})
            assert rejects(1, call, 'apply', scope, {'document': action})['err'] == name
            assert call('apply', scope, {'budgets': {}}) == before
            call('finish', scope)
            call('dispatch')

        try:
            caps = native.api.call('station_growing_capabilities')
            assert caps['document_owner'] and caps['document_reads'] and caps['document_codecs']
            operation({'create': {'document': document, 'type_revision': 1, 'record_bytes': 4096,
                                  'staging_bytes': '8192', 'staging_records': 2}})
            identity = {'resource': resource, 'document': document}
            initial = read({'describe': identity})['description']
            assert initial['floor'] == initial['merge_window'] == '0'
            assert codec({'inspect_reference': initial['reference']})['inspected_reference']['revision'] == '0'
            def prepare(replica, first, operations, previous='0'):
                return codec({'prepare': {'document': document, 'epoch': '1', 'replica': replica,
                    'first': first, 'previous': previous, 'operations': operations}})['prepared']['bytes']
            body = {'counter': '2', 'replica': '18446744073709551615'}
            bootstrap = prepare(body['replica'], '1', [
                {'assign': {'field': 'value', 'value': {'signed': '-9223372036854775808'}}},
                {'assign': {'field': 'body', 'value': {'text': {}}}},
                {'insert': {'object': body, 'value': {'character': '🙂'}}}])
            stage = {'stage': {'document': document, 'job': '1', 'change': bootstrap, 'node_limit': 256}}
            assert operation(stage)['progress']['phase'] == 'progress'
            assert operation(stage)['progress']['phase'] == 'progress'
            assert read({'describe': identity})['description']['reference'] == initial['reference']
            native.close()
            command({'own': {'pid': pid, 'worker': 65536, 'expected_generation': 2}})
            config['generation'] = 3
            path = system.root / 'document-port.json'
            path.write_text(json.dumps({'url': system.url, 'seed_file': str(seed), 'growing_server': config}))
            port = Port(host, path)
            owner = port
            # Frozen content must survive host replacement; malformed or changed
            # changes must not consume private mutation budget.
            changed = prepare(body['replica'], '1', [{'assign': {'field': 'other', 'value': {'boolean': True}}}])
            expect_error({'stage': {**stage['stage'], 'change': changed}}, 'DocumentIdentityConflict')
            for _ in range(300):
                result = operation(stage)['progress']
                if result['phase'] == 'accepted': break
            else: raise AssertionError('Document staging exceeded its finite fixture budget')
            assert result['revision'] == '1'
            assert operation(stage)['progress'] == {'phase': 'duplicate', 'revision': '1'}
            snapshot = read({'describe': identity})['description']['reference']
            assert read({'path': {'reference': initial['reference'], 'names': ['value']}})['field']['value']['status'] == 'missing'
            field = read({'path': {'reference': snapshot, 'names': ['value']}})['field']
            assert field['value']['assignments'][0]['value'] == {'signed': '-9223372036854775808'}
            page = read({'sequence': {'reference': snapshot, 'object': body}})['page']
            assert page['items'][0]['values']['assignments'][0]['value'] == {'character': '🙂'}
            assert page['next'] is None
            assert port.call({'growing_document_read': {'sequence': {'reference': snapshot, 'object': body}}})['page'] == page
            assert codec({'prepare': read({'accepted_change': snapshot})['change']})['prepared']['bytes'] == bootstrap
            sync = read({'resynchronize': {'identity': identity, 'replica': body['replica']}})['resynchronization']
            assert sync['previous_counter'] == sync['clock'] == '3'
            assert sync['reference'] == snapshot
            command({'grant_resource': {'resource': resource, 'subject': 65537, 'permissions': 0}})
            rejects(4, read, {'sequence': {'reference': snapshot, 'object': body}})
            command({'grant_resource': {'resource': resource, 'subject': 65537, 'permissions': 3}})
            # Only initialized payload fields are copied. Empty, null, conflicts,
            # Unicode and full-width counters pass through the native schemas.
            for job, replica in (('2', '7'), ('3', '8')):
                change = prepare(replica, '4', [{'assign': {'field': 'value', 'value': {'null_value': {}}}}])
                stage_peer = {'stage': {'document': document, 'job': job, 'change': change, 'node_limit': 128}}
                for _ in range(180):
                    if operation(stage_peer)['progress']['phase'] == 'accepted': break
                else: raise AssertionError('Concurrent field change did not finish')
            current = read({'describe': identity})['description']['reference']
            conflict = read({'path': {'reference': current, 'names': ['value']}})['field']['value']
            assert conflict['status'] == 'conflict' and len(conflict['assignments']) == 3
            retained = read({'path': {'reference': snapshot, 'names': ['value']}})['field']
            assert retained['value'] == field['value'] and retained['reference'] == field['reference']
            assert retained['source_revision'] > field['source_revision']
            operation({'retire': document})
            assert read({'describe': identity})['description']['retired']
            assert rejects(7, read, {'path': {'reference': current, 'names': ['value']}})['err'] == 'DocumentRetired'
            expect_error(stage, 'DocumentRetired')
            print(f'Document native/port: {turns} bounded turns, read-only principal, host replacement, '
                  f'exact identity, retained reads, conflicts and revocation passed in {time.monotonic()-started:.2f}s', flush=True)
        finally:
            if port is not None: port.close()
            if native.pointer.value: native.close()
            reader.close()
            root.close()


if __name__ == '__main__':
    run(*sys.argv[1:])
