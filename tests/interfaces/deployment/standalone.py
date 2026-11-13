"""Real standalone Helm lifecycle in a new, exclusively owned Kind cluster."""
from runner.paths import ROOT
from harness.services import free_port
from interfaces.cli.table_console import records, results
import json
from pathlib import Path
import secrets
import shutil
import subprocess
import sys
import tempfile
import time


def run(prefix):
    binary = (Path(prefix) / 'bin/transit').resolve()
    assert binary.is_file()
    assert 'INTERP' not in subprocess.check_output(['readelf', '-l', binary], text=True), 'Use the static release build'
    pins = json.loads((ROOT / 'deploy/reference/versions.json').read_text())
    root = Path(tempfile.mkdtemp(prefix='transit-standalone-'))
    name = 'transit-standalone-' + secrets.token_hex(4)
    registry = name + '-registry'
    kubeconfig = root / 'kubeconfig'
    port = free_port()
    host = f'localhost:{port}'
    forward = None
    passed = False

    def call(argv, **kwargs):
        try:
            return subprocess.run(list(map(str, argv)), check=True, text=True, capture_output=True, timeout=300, **kwargs).stdout
        except subprocess.CalledProcessError as error:
            print(error.stderr[-4000:], file=sys.stderr)
            raise

    def kube(*args):
        return call(['kubectl', '--kubeconfig', kubeconfig, '--context', 'kind-' + name, *args])

    def helm(*args):
        return call(['helm', '--kubeconfig', kubeconfig, '--kube-context', 'kind-' + name, *args])

    def rollout():
        kube('rollout', 'status', 'deployment/transit-server', '--timeout=240s')

    def console(sql, config=None, success=True):
        output = subprocess.run([str(binary), 'console', '--no-rc', '--config', str(config or root / 'console.json'),
            '--format', 'json', '-c', sql], capture_output=True, text=True, timeout=30)
        if success:
            assert output.returncode == 0, output.stderr
            return [json.loads(line) for line in output.stdout.splitlines()]
        assert output.returncode != 0, 'Invalid credentials were admitted'

    def connect():
        nonlocal forward
        if forward:
            forward.terminate()
            forward.wait(timeout=10)
        forward = subprocess.Popen(['kubectl', '--kubeconfig', str(kubeconfig), '--context', 'kind-' + name,
            'port-forward', 'service/transit-server', f'{sql_port}:19109'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(1)
        assert forward.poll() is None

    try:
        print('Standalone Helm proof:', name, flush=True)
        (root / 'kind.yaml').write_text('''kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
containerdConfigPatches:
- |-
  [plugins."io.containerd.cri.v1.images".registry]
    config_path = "/etc/containerd/certs.d"
''')
        call(['docker', 'run', '-d', '--name', registry, '-p', f'127.0.0.1:{port}:5000', pins['registry']])
        call(['kind', 'create', 'cluster', '--name', name, '--config', root / 'kind.yaml', '--image', pins['kind_node'],
            '--wait', '120s', '--kubeconfig', kubeconfig])
        call(['docker', 'network', 'connect', 'kind', registry])
        node = name + '-control-plane'
        hosts = root / 'hosts.toml'
        hosts.write_text(f'[host."http://{registry}:5000"]\n  capabilities = ["pull", "resolve"]\n')
        call(['docker', 'exec', node, 'mkdir', '-p', '/etc/containerd/certs.d/' + host])
        call(['docker', 'cp', hosts, node + ':/etc/containerd/certs.d/' + host + '/hosts.toml'])
        context = root / 'image'
        context.mkdir()
        shutil.copyfile(binary, context / 'transit')
        (context / 'transit').chmod(0o755)
        (context / 'data').mkdir()
        (context / 'Dockerfile').write_text('FROM scratch\nCOPY transit /bin/transit\nCOPY --chown=65532:65532 data /data\nUSER 65532:65532\nWORKDIR /data\nENTRYPOINT ["/bin/transit"]\n')
        image = host + '/transit:proof'
        call(['docker', 'build', '--network=none', '-t', image, context])
        call(['docker', 'push', image])
        digest = json.loads(call(['docker', 'inspect', image]))[0]['RepoDigests'][0]
        call(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-keyout', root / 'tls.key', '-out', root / 'tls.crt',
            '-days', '1', '-subj', '/CN=localhost', '-addext', 'subjectAltName=DNS:localhost,IP:127.0.0.1'])
        (root / 'password').write_text(secrets.token_hex(24))
        (root / 'password').chmod(0o600)
        kube('create', 'secret', 'generic', 'sql', '--from-file=tls.key=' + str(root / 'tls.key'),
            '--from-file=tls.crt=' + str(root / 'tls.crt'), '--from-file=password=' + str(root / 'password'))
        values = root / 'values.json'
        values.write_text(json.dumps(dict(image=digest, existingSecret='sql')))
        helm('install', 'transit', ROOT / 'charts/transit', '-f', values, '--wait', '--timeout', '5m')
        rollout()
        sql_port = free_port()
        connection = dict(version=1, endpoint=f'https://localhost:{sql_port}', account='owner', database='transit',
            authentication='scram', password_file=str(root / 'password'), ca_file=str(root / 'tls.crt'))
        (root / 'console.json').write_text(json.dumps(connection))
        connect()
        console('CREATE TABLE chart_probe (id BIGINT PRIMARY KEY)')
        console('INSERT INTO chart_probe VALUES (31)')
        assert records(results(console('SELECT id FROM chart_probe'))[0]) == [{'id': '31'}]
        (root / 'wrong-password').write_text('incorrect')
        (root / 'denied.json').write_text(json.dumps(connection | dict(password_file=str(root / 'wrong-password'))))
        console('SELECT id FROM chart_probe', root / 'denied.json', success=False)
        claim = json.loads(kube('get', 'pvc', 'transit-server', '-o', 'json'))
        volume = json.loads(kube('get', 'pv', claim['spec']['volumeName'], '-o', 'json'))
        data = volume['spec']['hostPath']['path']
        assert data.startswith('/var/local-path-provisioner/')

        def record():
            return json.loads(call(['docker', 'exec', node, 'cat', data + '/.transit/installation.json']))
        original = record()['installation']
        # An ordinary upgrade tightens missing-state policy and gracefully replaces
        # the PID-1 supervisor. No native provisioning utility participates.
        helm('upgrade', 'transit', ROOT / 'charts/transit', '-f', values, '--wait', '--timeout', '5m')
        rollout()
        connect()
        assert record()['installation'] == original
        assert records(results(console('SELECT id FROM chart_probe'))[0]) == [{'id': '31'}]
        # Kill the actual namespace init; Kubernetes replaces the same pod's
        # container. Namespace children must disappear before restart can bind.
        pod = json.loads(kube('get', 'pods', '-l', 'app.kubernetes.io/instance=transit', '-o', 'json'))['items'][0]
        old_restarts = pod['status']['containerStatuses'][0]['restartCount']
        container_id = pod['status']['containerStatuses'][0]['containerID'].split('://', 1)[1]
        call(['docker', 'exec', node, 'ctr', '--namespace', 'k8s.io', 'tasks', 'kill', '--signal', 'SIGKILL', container_id])
        deadline = time.monotonic() + 180
        while True:
            current = json.loads(kube('get', 'pod', pod['metadata']['name'], '-o', 'json'))
            status = current['status'].get('containerStatuses', [{}])[0]
            if status.get('restartCount', 0) > old_restarts and status.get('ready'):
                break
            assert time.monotonic() < deadline, 'PID-1 recovery did not become ready'
            time.sleep(2)
        connect()
        assert record()['installation'] == original
        assert records(results(console('SELECT id FROM chart_probe'))[0]) == [{'id': '31'}]
        # Stop before manipulating only this proof's retained volume. Missing
        # installation under the upgraded policy must never mint a new identity.
        helm('upgrade', 'transit', ROOT / 'charts/transit', '-f', values, '--set', 'running=false', '--wait')
        for remaining in json.loads(kube('get', 'pods', '-l', 'app.kubernetes.io/instance=transit', '-o', 'json'))['items']:
            kube('wait', '--for=delete', 'pod/' + remaining['metadata']['name'], '--timeout=90s')
        call(['docker', 'exec', node, 'mv', data + '/.transit', data + '/saved-installation'])
        helm('upgrade', 'transit', ROOT / 'charts/transit', '-f', values)
        deadline = time.monotonic() + 60
        while True:
            pods = json.loads(kube('get', 'pods', '-l', 'app.kubernetes.io/instance=transit', '-o', 'json'))['items']
            if not pods:
                assert time.monotonic() < deadline
                time.sleep(1)
                continue
            pod = pods[0]
            statuses = pod.get('status', {}).get('containerStatuses', [])
            if statuses and statuses[0].get('restartCount', 0) > 0:
                assert not statuses[0].get('ready')
                break
            assert time.monotonic() < deadline, 'Missing installation did not fail'
            time.sleep(1)
        failure = kube('logs', pod['metadata']['name'], '--previous')
        assert 'startup requires an existing installation' in failure, failure
        assert 'saved-installation' in call(['docker', 'exec', node, 'ls', '-a', data])
        assert '.transit' not in call(['docker', 'exec', node, 'ls', '-a', data]).splitlines()
        passed = True
        print('Standalone Helm: TLS/password SQL, retained row/identity, graceful upgrade, PID-1 recovery and missing-state refusal passed.', flush=True)
    finally:
        if forward:
            forward.terminate()
            forward.wait(timeout=10)
        if passed:
            call(['kind', 'delete', 'cluster', '--name', name])
            call(['docker', 'rm', '-f', registry])
            call(['docker', 'image', 'rm', image])
            shutil.rmtree(root)
        else:
            print(f'Private failure state retained: {root}; owned cluster {name}; registry {registry}', file=sys.stderr)


if __name__ == '__main__':
    run(sys.argv[1])
