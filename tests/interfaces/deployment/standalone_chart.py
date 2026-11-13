"""Standalone chart placement, retained-state policy and legacy-value rejection."""
from runner.paths import ROOT
import json
from pathlib import Path
import subprocess
import tempfile
import yaml


def run():
    chart = ROOT / 'charts/transit'
    values = dict(image='example.invalid/transit@sha256:' + 'a' * 64, existingSecret='sql-credentials')
    with tempfile.TemporaryDirectory(prefix='transit-standalone-chart-') as directory:
        path = Path(directory) / 'values.json'

        def render(extra=None, upgrade=False, rejected=False):
            path.write_text(json.dumps(values | (extra or {})))
            result = subprocess.run(['helm', 'template', 'standalone', str(chart), '-f', str(path),
                *(['--is-upgrade'] if upgrade else [])], capture_output=True, text=True)
            if rejected:
                assert result.returncode != 0, result.stdout
                return
            assert result.returncode == 0, result.stderr
            return {doc['kind']: doc for doc in yaml.safe_load_all(result.stdout) if doc}

        manifests = render()
        assert set(manifests) == {'Deployment', 'ConfigMap', 'Service', 'PersistentVolumeClaim'}
        deployment = manifests['Deployment']['spec']
        assert deployment['replicas'] == 1 and deployment['strategy'] == {'type': 'Recreate'}
        pod = deployment['template']['spec']
        assert pod['automountServiceAccountToken'] is False
        assert pod['enableServiceLinks'] is False
        assert len(pod['containers']) == 1 and not pod.get('initContainers')
        container = pod['containers'][0]
        assert container['command'] == ['/bin/transit']
        assert container['args'] == ['server', '--config', '/config/transit.yaml', '--no-ui']
        assert container['workingDir'] == '/data'
        assert container['securityContext']['readOnlyRootFilesystem'] is True
        assert container['securityContext']['capabilities']['drop'] == ['ALL']
        assert pod['securityContext']['runAsNonRoot'] is True
        for probe in ('startupProbe', 'readinessProbe'):
            assert container[probe]['exec']['command'] == ['/bin/transit', 'console', '--no-rc', '-c', 'SHOW TABLES']
        assert 'livenessProbe' not in container
        volumes = {v['name']: v for v in pod['volumes']}
        assert volumes['installation']['persistentVolumeClaim']['claimName'] == 'standalone-server'
        assert volumes['credentials']['secret'] == {'secretName': 'sql-credentials', 'defaultMode': 0o440}
        assert manifests['PersistentVolumeClaim']['metadata']['annotations']['helm.sh/resource-policy'] == 'keep'
        assert manifests['Service']['spec']['ports'] == [dict(name='sql', port=19109, targetPort='sql')]

        def config(manifests):
            return yaml.safe_load(manifests['ConfigMap']['data']['transit.yaml'])
        settings = config(manifests)
        assert settings['installation'] == '/data/.transit' and settings['board'] is None
        assert settings['startup']['require_existing'] is False
        assert settings['sql']['native']['http'] == dict(address='0.0.0.0', port=19109, tls=True,
            certificate_file='/secrets/tls.crt', key_file='/secrets/tls.key')
        assert settings['sql']['accounts'] == [dict(name='owner', role='local_owner', authentication='password',
            password_file='/secrets/password', bootstrap_owner=True)]
        assert config(render(upgrade=True))['startup']['require_existing'] is True
        existing = render({'persistence': {'existingClaim': 'retained'}})
        assert 'PersistentVolumeClaim' not in existing
        assert config(existing)['startup']['require_existing'] is True
        assert config(render({'requireExisting': True}))['startup']['require_existing'] is True
        assert render({'running': False})['Deployment']['spec']['replicas'] == 0
        for extra in ({'node': {'config': {}}}, {'initialize': {'enabled': True}}, {'replicas': 2},
                {'image': 'example.invalid/transit:nightly'}, {'existingSecret': ''}, {'account': 'local'}):
            render(extra, rejected=True)
        render()
        subprocess.run(['helm', 'lint', '--strict', str(chart), '-f', str(path)], check=True)
    print('Standalone chart: single server, TLS-only exposure, retained installation and legacy-value rejection passed.')
