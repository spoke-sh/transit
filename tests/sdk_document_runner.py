"""Shared installed Document SDK schedule; Zig owns all merge/publication work."""
import argparse
import importlib
import json
from pathlib import Path
import select
import shutil
import subprocess
import tempfile
import time

from client_abi import Native
from client_abi_growing import GrowingSystem
from document_contract import encode
from station import frame


def run(node, cli, library, install, label):
    started = time.monotonic()
    fixture = GrowingSystem(node, cli)
    fixture.resident_pages = 64
    with tempfile.TemporaryDirectory(prefix='transit-document-sdk-') as temporary, fixture as system:
        target = Path(temporary)
        consumer = install(target)
        fixtures = target / 'document-fixtures.json'
        shutil.copyfile(Path(__file__).resolve().parents[1] / 'packages/zig/transit-station-document/src/fixtures/changes.json', fixtures)
        native = Native(library)
        admin = native.client(system.url, timeout_ms=15000)
        private = bytes.fromhex(system.seed.read_text().strip())
        sequence, children = 0, []
        def command(body):
            nonlocal sequence
            sequence += 1
            operation = native.prepare(6, private, {'realm': 72, 'principal': 0, 'sequence': sequence, 'command': body})
            try: return native.call(admin, operation)['position']
            finally: native.lib.transit_operation_destroy(operation)
        pid = command({'spawn': {}})
        resource = command({'create_resource': {'writer': pid}})
        seed, public = system.key('document-writer')
        observer, observer_public = system.key('document-reader')
        command({'grant': {'subject': 65536, 'public_key': public, 'permissions': 88, 'pid': pid}})
        command({'grant': {'subject': 65537, 'public_key': observer_public, 'permissions': 16, 'pid': pid}})
        for subject, permissions in ((0, 7), (65536, 7), (65537, 3)):
            command({'grant_resource': {'resource': resource, 'subject': subject, 'permissions': permissions}})
        command({'associate': {'pid': pid, 'name': b'data'.hex(), 'resource': resource}})
        command({'own': {'pid': pid, 'worker': 65536, 'expected_generation': 1}})
        document, replica = str(2**64-1), str(2**64-1)
        object_id = {'counter': '2', 'replica': replica}
        common = {'document': document, 'epoch': '1', 'type_revision': 1, 'previous': '0'}
        changes = [
            {**common, 'replica': replica, 'first': '1', 'operations': [
                {'assign': {'field': 'value', 'value': {'signed': str(-(2**63))}}},
                {'assign': {'field': 'body', 'value': {'text': {}}}},
                {'insert': {'object': object_id, 'value': {'character': '🙂'}}}]},
            {**common, 'replica': '7', 'first': '4', 'operations': [
                {'assign': {'field': 'value', 'value': {'null_value': {}}}},
                {'insert': {'object': object_id, 'after': {'counter': '3', 'replica': replica}, 'value': {'character': '́'}}}]}]
        cfg = {'url': system.url, 'realm': 72, 'principal': 65536, 'pid': pid, 'generation': 2,
               'seed_file': str(seed), 'profile': 'growing_v3', 'resource': resource, 'document': document,
               'document_fixtures': str(fixtures), 'changes': [encode(change).hex() for change in changes]}
        count = 0
        def config_file(config):
            path = target / f"config-{config['principal']}.json"
            path.write_text(json.dumps(config))
            return path
        def start(config):
            child = subprocess.Popen(consumer.command('document-worker', config_file(config)), cwd=target,
                env=consumer.environment, stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
            children.append(child)
            return child
        def action(child, value):
            child.stdin.write(value+'\n'); child.stdin.flush()
            assert select.select([child.stdout], [], [], 90)[0], 'Document SDK timed out'
            line = child.stdout.readline()
            assert line, f'Document SDK exited {child.poll()}'
            return json.loads(line)
        def close(child):
            assert action(child, 'close') == {'closed': True}
            child.stdin.close(); assert child.wait(timeout=15) == 0; child.stdout.close(); children.remove(child)
        def step(child, value):
            nonlocal count
            command({'send': {'pid': pid, 'value': frame(value.encode())}})
            result = action(child, 'one')
            assert result['event'] == 'committed', result
            count += 1
            return result.get('phase')
        try:
            subprocess.run(consumer.command('document-codecs', config_file(cfg)), cwd=target, env=consumer.environment, check=True, timeout=90)
            owner = start(cfg)
            step(owner, 'initialize')
            assert step(owner, 'checkpoint') == 'progress'
            assert step(owner, 'checkpoint') == 'checkpoint_complete'
            assert step(owner, '0') == 'progress'
            assert step(owner, '0') == 'progress'
            owner.kill(); owner.wait(timeout=10); owner.stdin.close(); owner.stdout.close(); children.remove(owner)
            command({'own': {'pid': pid, 'worker': 65536, 'expected_generation': 2}})
            cfg['generation'] = 3
            owner = start(cfg)
            for _ in range(300):
                if step(owner, '0') == 'accepted': break
            else: raise AssertionError('Document SDK did not accept bootstrap')
            assert step(owner, '0') == 'duplicate'
            reader = start({**cfg, 'principal': 65537, 'seed_file': str(observer)})
            assert action(reader, 'read') == {'revision': '2', 'items': 1, 'status': 'scalar'}
            command({'grant_resource': {'resource': resource, 'subject': 65537, 'permissions': 0}})
            assert action(reader, 'denied') == {'denied': True}
            command({'grant_resource': {'resource': resource, 'subject': 65537, 'permissions': 3}})
            for _ in range(220):
                if step(owner, '1') == 'accepted': break
            else: raise AssertionError('Document SDK did not accept disconnected peer')
            assert action(reader, 'old') == {'retained': True}
            assert action(reader, 'read') == {'revision': '3', 'items': 2, 'status': 'conflict'}
            assert action(reader, 'resynchronize') == {'previous': '3', 'clock': '5'}
            step(owner, 'window')
            step(owner, 'retire')
            assert action(reader, 'retired') == {'retired': True}
            assert action(reader, 'async-close') == {'joined': True}
            close(reader); close(owner)
            print(f'Document {label}: installed codec/Unicode/reference fixtures, {count} scoped turns, '
                  f'host loss, independent reads, conflicts, revocation and retirement passed in {time.monotonic()-started:.2f}s', flush=True)
        finally:
            for child in children:
                if child.poll() is None: child.kill()
                child.wait(timeout=10)
                child.stdin.close(); child.stdout.close()
            native.lib.transit_client_destroy(admin)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('node'); parser.add_argument('cli'); parser.add_argument('library'); parser.add_argument('artifacts')
    parser.add_argument('--language', choices=('python', 'node', 'rust', 'ruby', 'c', 'java', 'dotnet', 'beam'), action='append')
    args = parser.parse_args()
    for language in args.language or ('python',):
        module = importlib.import_module(language + '_station_sdk')
        artifacts = Path(args.artifacts) / ('wheels' if language == 'python' else language)
        module.run(args.node, args.cli, args.library, artifacts, execute=run)


if __name__ == '__main__': main()
