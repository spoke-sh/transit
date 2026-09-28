"""Console's actual configured native TLS client; separate from browser trust."""
import json
import subprocess
from urllib.parse import urlparse
from serving_tls import TLSProxy


def check(binary, root, config, kind):
    with TLSProxy(root/'console-tls', urlparse(config['url']).port) as tls:
        secure = dict(config, transport='tls_ca', ca_file=str(tls.root/'certificate.pem'),
                      url=f'https://127.0.0.1:{tls.port}', recovery_file=None, format='json')
        path = root/'console-tls.json'
        path.write_text(json.dumps(secure))
        result = subprocess.run([binary, 'console', '--config', str(path)], input=b'/schema\n/quit\n', capture_output=True, timeout=30)
        assert result.returncode == 0 and not result.stderr, result
        assert json.loads(result.stdout)['description']['source']['capabilities'][kind]
        # The system trust store does not contain this disposable private CA.
        path.write_text(json.dumps(dict(secure, transport='tls_system', ca_file=None)))
        result = subprocess.run([binary, 'console', '--config', str(path)], input=b'/schema\n/quit\n', capture_output=True, timeout=30)
        assert result.returncode == 1 and json.loads(result.stdout)['err'] == 'TlsInitializationFailed', result
        # Same trusted certificate at a name it does not cover must fail as well.
        path.write_text(json.dumps(dict(secure, url=f'https://localhost:{tls.port}')))
        result = subprocess.run([binary, 'console', '--config', str(path)], input=b'/schema\n/quit\n', capture_output=True, timeout=30)
        assert result.returncode == 1 and json.loads(result.stdout)['err'] == 'TlsInitializationFailed', result
        print(f'Transit console {kind}: explicit private CA native schema read passed; system-trust and hostname mismatches rejected.', flush=True)
