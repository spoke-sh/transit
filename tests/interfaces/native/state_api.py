"""Public native state operations against disk storage; no raw state access."""
import json
from pathlib import Path
import sys
import time
from interfaces.inspection.inspection import System
from harness.services import wait_ready


def run(node, cli, counter):
    with System(node, cli, clock_error_ms=10000) as s:
        def query(kind, **options):
            response = s.native_query(kind, **options)
            return response['body'][next(iter(kind))] if options.get('status', 200) == 200 else response

        def entries(resource, revision=None, **options):
            if revision is None:
                revision = query({'resource': resource})['revision']
            return query({'entries': {'resource': resource, 'revision': revision,
                                     **{k: options.pop(k) for k in ('key', 'after') if k in options}}}, **options)

        capabilities = query({'capabilities': {}})
        assert capabilities['mutation_budget'] == 4 and capabilities['page_entries'] == 8
        pid = s.command({'spawn': {}})
        resource = s.command({'create_resource': {'writer': pid, 'history_ms': 0}})
        seed, public = s.key('observer')
        s.command({'grant': {'subject': 1, 'public_key': public, 'permissions': 16, 'pid': pid}})
        s.command({'grant_resource': {'resource': resource, 'subject': 0, 'permissions': 7}})
        association = s.command({'associate': {'pid': pid, 'name': b'data'.hex(), 'resource': resource}})
        assert all(v is None for v in query({'resources': {}}, principal=1, seed=seed)['entries'])
        assert all(v is None for v in query({'associations': {'pid': pid}}, principal=1, seed=seed)['entries'])
        entries(resource, principal=1, seed=seed, status=403)
        s.command({'grant_resource': {'resource': resource, 'subject': 1, 'permissions': 1}})
        assert query({'association': {'pid': pid, 'name': b'data'.hex()}}, principal=1, seed=seed)['revision'] == association
        entries(resource, principal=1, seed=seed, status=403)
        s.command({'own': {'pid': pid, 'worker': 0, 'expected_generation': 1}})
        for index in range(10):
            message = s.command({'send': {'pid': pid, 'value': b'work'.hex()}})
            process = query({'process': pid})['process']
            revision = query({'resource': resource})['revision']
            view = s.command({'open_view': {'pid': pid, 'generation': 2, 'input': message,
                'expected_revision': process['revision'], 'resource': resource, 'revision': revision,
                'deadline_ms': int(time.time() * 1000) + 30000}})
            assert query({'view': view})['revision'] == revision
            assert query({'entries': {'view': view}})['view']['revision'] == revision
            command = {'turn': {'pid': pid, 'generation': 2, 'input': message,
                'expected_revision': process['revision'], 'views': [view, None, None, None], 'write_view': view,
                'mutations': [{'key': str(index).encode().hex(), 'value': b'opaque'.hex()}, None, None, None]}}
            position = s.command(command)
            assert s.post('/v1/command', s.signed(command, s.sequence))['position'] == position
            assert query({'view': view})['closed_at'] == position
            query({'entries': {'view': view}}, status=422)
        first = entries(resource)
        second = entries(resource, first['resource']['revision'], after=first['page']['next'])
        assert len([v for v in first['page']['entries'] + second['page']['entries'] if v]) == 10
        assert second['page']['next'] is None
        s.command({'grant_resource': {'resource': resource, 'subject': 1, 'permissions': 3}})
        read = entries(resource, principal=1, seed=seed)
        discovery = s.native_query({'resources': {}})
        s.command({'grant_resource': {'resource': resource, 'subject': 1, 'permissions': 0}})
        entries(resource, read['resource']['revision'], principal=1, seed=seed, status=403)
        # Catalog cuts expire on policy change; an unchanged resource revision
        # still supports current-authorized value reads at that revision.
        s.native_query({'resources': {'position': discovery['position']}}, status=409)
        before = entries(resource, first['resource']['revision'])
        s.authority.kill()
        s.authority.wait(timeout=10)
        s.store.stop()
        s.store.start()
        s.authority = s.start(s.node, s.config)
        wait_ready(s.store.http, s.authority, s.url + '/health')
        assert entries(resource) == before
        assert query({'process': pid})['process']['consumed'] == 10
        worker, public = s.key('caller')
        config = s.root / 'counter.json'
        for generation, value in ((3, 7), (4, 5)):
            s.command({'grant': {'subject': 2, 'public_key': public, 'permissions': 24, 'pid': pid}})
            s.command({'grant_resource': {'resource': resource, 'subject': 2, 'permissions': 7}})
            s.command({'own': {'pid': pid, 'worker': 2, 'expected_generation': generation - 1}})
            s.command({'send': {'pid': pid, 'value': str(value).encode().hex()}})
            config.write_text(json.dumps({'url': s.url, 'realm': 72, 'principal': 2, 'pid': pid,
                'generation': generation, 'seed_file': str(worker), 'state_association': 'data'}))
            child = s.start(counter, '--once', config)
            assert child.wait(timeout=15) == 0
        assert entries(resource, key=b'value'.hex())['page']['entries'][0]['value'] == b'12'.hex()
        entries(resource, first['resource']['revision'], status=422)
        metadata = query({'resource': resource})
        assert metadata['last_turn'] == metadata['revision'] == query({'process': pid})['process']['revision']
    # Unlimited lifetimes and zero-age reclamation do not require a clock.
    with System(node, cli) as s:
        pid = s.command({'spawn': {}})
        resource = s.command({'create_resource': {'writer': pid, 'history_ms': 0}})
        s.command({'grant_resource': {'resource': resource, 'subject': 0, 'permissions': 3}})
        s.command({'terminate': pid})
        config = json.loads(s.config.read_text())
        config['maintenance'] = {'principal': 0, 'seed_file': str(s.seed), 'interval_ms': 50}
        s.config.write_text(json.dumps(config))
        for _ in range(2):
            maintenance = s.start(node, s.config, '--maintain')
            until = time.monotonic() + 10
            while True:
                status, response = s.native_query({'resource': resource}, status=None)
                if status == 200:
                    if response['body']['resource']['phase'] == 'reclaimed':
                        break
                else:
                    # Maintenance can advance the authority tail during this
                    # current metadata read. Discard the conflicted observation
                    # and poll a fresh cut within the original deadline. Never
                    # apply this rule to commands or fixed-cut continuations.
                    assert ((status == 409 and response == {'err': 'Conflict'}) or
                            (status == 503 and response.get('err') in
                             ('AuthorityUnavailable', 'AuthorityTimeout', 'HttpCapacity'))), (status, response)
                assert time.monotonic() < until and maintenance.poll() is None
                time.sleep(.05)
            maintenance.kill()
            maintenance.wait(timeout=10)
    print('State API: signed reads, separate grants, frozen views, atomic turns, exact retries, pagination and disk recovery passed.')


if __name__ == '__main__':
    run(*[Path(p).resolve() for p in sys.argv[1:]])
