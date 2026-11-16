"""Installed SQL and settings use the native immutable tier through MinIO TLS."""
import json
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import sys
import time
import urllib.error

from interfaces.installation.server import Fixture
from interfaces.installation.server_direct_tables import storage
from interfaces.installation.server_application_faults import ExistingKey, native, post
from interfaces.cli.table_console import records
from storage.providers.cold_storage import ColdStore


class ComposeFixture(Fixture):
    """One Linux host-network server, with only its owned installation mounted."""
    def __init__(self, cli):
        super().__init__(cli)
        self.use_private_runtime()
        assert 'INTERP' not in subprocess.check_output(['readelf', '-l', self.cli], text=True), 'Compose runtime requires a host loader'
        assert '(NEEDED)' not in subprocess.check_output(['readelf', '-d', self.cli], text=True), 'Compose runtime requires host libraries'
        self.project = 'transit-tier-' + secrets.token_hex(6)
        self.image = self.project + ':proof'
        self.compose = self.root / 'compose.json'
        self.config.pop('executables')  # Exercise the installed executable's embedded roles.
        context = self.root / 'image'
        context.mkdir()
        shutil.copy2(self.cli, context / 'transit')
        (context / 'Dockerfile').write_text('FROM scratch\nCOPY transit /bin/transit\nENTRYPOINT ["/bin/transit"]\n')
        subprocess.run(['docker', 'build', '--quiet', '--tag', self.image, str(context)],
                       check=True, timeout=300)
        mounts = [{'type': 'bind', 'source': str(self.root), 'target': str(self.root)}]
        for path in (self.path, self.root / 'object-credentials_file', self.root / 'object-ca_file'):
            mounts.append({'type': 'bind', 'source': str(path), 'target': str(path),
                           'read_only': True, 'bind': {'create_host_path': False}})
        self.compose.write_text(json.dumps({'services': {'server': {
            'image': self.image, 'user': f'{os.getuid()}:{os.getgid()}',
            'read_only': True, 'cap_drop': ['ALL'],
            'security_opt': ['no-new-privileges:true'], 'network_mode': 'host',
            'environment': self.environment,
            'command': ['server', '--no-ui', '--config', str(self.path)],
            'volumes': mounts,
            'logging': {'driver': 'json-file', 'options': {'max-size': '5m', 'max-file': '2'}},
        }}}))

    def command(self, *args):
        return ['docker', 'compose', '--project-name', self.project, '--file', str(self.compose), *args]

    def start(self):
        assert self.process is None
        log = (self.root / f'compose-{len(self.logs)}.log').open('wb')
        self.logs.append(log)
        self.process = subprocess.Popen(self.command('up', '--no-color', '--no-log-prefix', '--abort-on-container-exit'),
            stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT)

    def ready(self, timeout=180):
        deadline = time.monotonic() + timeout
        report = None
        # A gateway can answer while this startup is still activating SQL, and
        # retained status files can describe the previous process. First require
        # this invocation's ready record, as the ordinary Local fixture does.
        with Path(self.logs[-1].name).open() as output:
            while True:
                assert self.process.poll() is None, Path(self.logs[-1].name).read_text()[-4000:]
                while report is None:
                    position = output.tell()
                    line = output.readline()
                    if not line.endswith('\n'):
                        output.seek(position)
                        break
                    try:
                        value = json.loads(line)
                    except ValueError:
                        continue
                    if isinstance(value, dict) and value.get('ready') is True:
                        assert value['profile'] == 'local_applications_v1'
                        assert value['installation'] == str(self.installation)
                        assert value['gateway_url'] == self.url and value['ui'] == 'disabled'
                        report = value
                if report is not None:
                    self.ready_sql(deadline)
                    try:
                        with self.http.open(self.url + '/health', timeout=1) as response:
                            if response.status == 200:
                                return report
                    except (urllib.error.URLError, TimeoutError, ConnectionError):
                        pass
                assert time.monotonic() < deadline, 'Compose installation did not become ready'
                time.sleep(.1)

    def stop(self, kill=False):
        if self.process is None:
            return
        running = self.process.poll() is None
        action = ['kill', '--signal', 'SIGKILL'] if kill else ['stop', '--timeout', '10']
        subprocess.run(self.command(*action), check=True, timeout=30, capture_output=True)
        self.process.wait(timeout=20)
        subprocess.run(self.command('down', '--timeout', '10'), check=True, timeout=30, capture_output=True)
        if running and not kill:
            assert self.process.returncode == 0, Path(self.logs[-1].name).read_text()[-4000:]
        self.process = None

    def cleanup(self):
        super().cleanup()
        subprocess.run(['docker', 'image', 'rm', self.image], check=True, timeout=30, capture_output=True)


def exercise(cli, compose):
    with ColdStore(tls=True) as cold:
        fixture = ComposeFixture(cli) if compose else Fixture(cli)
        try:
            options = cold.native_config()
            if compose:
                # Compose receives file references through the server's private
                # mount. No provider credentials enter an image or command line.
                for field in ('credentials_file', 'ca_file'):
                    destination = fixture.root / ('object-' + field)
                    shutil.copy2(options[field], destination)
                    destination.chmod(0o600)
                    options[field] = str(destination)
            fixture.config['storage'] = dict(object_storage=options,
                maintenance=dict(flush=dict(enabled=True, rows=1, work_rows=2)))
            fixture.path.write_text(json.dumps(fixture.config))
            fixture.start()
            fixture.ready()
            record = fixture.record()
            identity = {name: record[name] for name in ('installation', 'root_public', 'identity', 'default_table', 'provision')}
            key = ExistingKey(fixture.root, fixture.installation / 'root.seed')

            def tier():
                return post(fixture.config['ports']['node'], '/v1/query',
                    native(key, record['realm'], 0, dict(storage={})))['body']['storage']['object_tier']

            def drained():
                until = time.monotonic() + 300
                while True:
                    observed = tier()
                    table = storage(fixture, record)
                    assert observed is not None and not observed['recovery_required'], observed
                    if observed['pending_objects'] == 0 and table['pending']['complete'] and table['pending']['rows'] == 0:
                        assert observed['pending_upload_bytes'] == 0
                        return observed
                    assert time.monotonic() < until, (observed, table['pending'])
                    time.sleep(.1)

            fixture.console('INSERT INTO items VALUES (1, 11), (2, 22);\n')
            expected = [dict(id='1', value='11'), dict(id='2', value='22')]
            assert sorted(records(fixture.console('SELECT id, value FROM items;\n')[-1]), key=lambda r: r['id']) == expected
            first = drained()
            assert first['uploads_completed'] > 0 and cold.native_data_objects() > 0
            # Reload records the mutable cache budget as pending; the active
            # owner keeps its old limit until restart.
            fixture.config['storage']['object_storage']['cache_bytes'] = 64 * 1024 * 1024
            fixture.path.write_text(json.dumps(fixture.config))
            fixture.console('SELECT transit_reload_conf();\n')
            assert tier()['cache_limit_bytes'] == 32 * 1024 * 1024
            fixture.stop(kill=True)
            fixture.start()
            fixture.ready()
            assert {name: fixture.record()[name] for name in identity} == identity
            assert tier()['cache_limit_bytes'] == 64 * 1024 * 1024
            assert sorted(records(fixture.console('SELECT id, value FROM items;\n')[-1]), key=lambda r: r['id']) == expected
            assert tier()['cache_misses'] > 0, 'Cold restart did not fetch original provider objects'
            fixture.console('UPDATE items SET value = 33 WHERE id = 2;\n')
            expected[1]['value'] = '33'
            drained()
            fixture.stop(kill=True)
            fixture.start()
            fixture.ready()
            assert sorted(records(fixture.console('SELECT id, value FROM items;\n')[-1]), key=lambda r: r['id']) == expected
            encoded = json.dumps(tier())
            assert cold.url not in encoded and cold.secret not in encoded and 'credentials_file' not in encoded
        except BaseException:
            fixture.stop(kill=True)
            print(f'Failed installed tier state retained privately at {fixture.root}', file=sys.stderr)
            raise
        else:
            fixture.cleanup()
    placement = 'Compose host-network' if compose else 'Local'
    print(f'Installed native MinIO ({placement}): SQL writes/flush, verified remote coverage, mutable cache settings, original installation identity and cold restart reads passed.', flush=True)


def run(cli):
    exercise(cli, False)
    exercise(cli, True)


if __name__ == '__main__':
    run(*sys.argv[1:])
