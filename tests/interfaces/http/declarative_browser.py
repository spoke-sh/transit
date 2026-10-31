"""Real installed listener, native catalog and independent OAuth/OIDC peers."""
import base64
from concurrent.futures import ThreadPoolExecutor
import hashlib
import hmac
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import secrets
import select
import shutil
import socket
import struct
import subprocess
import sys
import tempfile
import threading
import time
from urllib.parse import parse_qs, urlsplit, urlencode

from harness import processes
from harness.services import free_port
from runner.paths import ROOT
from interfaces.reactive.reactive import WebSocket
from interfaces.installation.server_application_faults import ExistingKey, native, post

DEFINITION = 'transit.browser.v1.2026-10-30'


def b64(value):
    return base64.urlsafe_b64encode(value).rstrip(b'=').decode()


def compact(value):
    return json.dumps(value, separators=(',', ':')).encode()


class Peers:
    def __init__(self, root):
        self.root = root
        self.codes = {}
        self.calls = []
        self.jwks_calls = 0
        self.kid = "peer-key"
        self.dispatched = threading.Event()
        self.release_exchange = threading.Event()
        self.lock = threading.Lock()
        self.key = root / 'test-oidc.pem'
        subprocess.run(['openssl', 'genpkey', '-algorithm', 'RSA', '-pkeyopt', 'rsa_keygen_bits:2048', '-out', str(self.key)], check=True, capture_output=True)
        modulus = subprocess.check_output(['openssl', 'rsa', '-in', str(self.key), '-noout', '-modulus']).decode().strip().split('=')[1]
        self.jwks = {'keys': [dict(kty='RSA', kid='peer-key', alg='RS256', use='sig', n=b64(bytes.fromhex(modulus)), e='AQAB')]}
        parent = self

        class Handler(BaseHTTPRequestHandler):
            protocol_version = "HTTP/1.1"
            def log_message(self, *_):
                pass

            def reply(self, value, status=200):
                data = compact(value)
                self.send_response(status)
                self.send_header('content-type', 'application/json')
                self.send_header('content-length', str(len(data)))
                self.end_headers()
                try:
                    self.wfile.write(data)
                except BrokenPipeError:
                    pass  # Expected when the real client is killed after dispatch.

            def do_POST(self):
                fields = parse_qs(self.rfile.read(int(self.headers.get('Content-Length', 0))).decode(), strict_parsing=True)
                code = fields['code'][0]
                with parent.lock:
                    parent.calls.append(code)
                    grant = parent.codes[code]
                assert fields['client_secret'] == ['peer-secret']
                assert fields['client_id'] == ['peer-client']
                assert fields['redirect_uri'] == [grant['redirect_uri'][0]]
                mode = self.path.split('/')[1]
                if mode != 'facebook':
                    assert b64(hashlib.sha256(fields['code_verifier'][0].encode()).digest()) == grant['code_challenge'][0]
                else:
                    assert 'code_verifier' not in fields
                if code.startswith('uncertain'):
                    self.close_connection = True
                    self.connection.shutdown(socket.SHUT_RDWR)
                    return
                if code.startswith('crash'):
                    parent.dispatched.set()
                    assert parent.release_exchange.wait(15)
                if code.startswith('slow'):
                    time.sleep(1)
                token = dict(access_token=code, token_type='Bearer')
                if mode == 'google':
                    now = int(time.time())
                    claims = dict(iss=parent.origin, aud='peer-client', sub=grant.get('subject', code), exp=now + 300, iat=now, nonce=grant['nonce'][0])
                    if code.startswith('bad-nonce'):
                        claims['nonce'] = 'wrong-nonce'
                    if code.startswith('bad-aud'):
                        claims['aud'] = 'wrong-client'
                    if code.startswith('bad-issuer'):
                        claims['iss'] = 'https://wrong.example'
                    unsigned = b64(compact(dict(alg='RS256', kid=parent.kid, typ='JWT'))) + '.' + b64(compact(claims))
                    message = root / ('jwt-' + hashlib.sha256(code.encode()).hexdigest())
                    message.write_bytes(unsigned.encode())
                    signature = subprocess.check_output(['openssl', 'dgst', '-sha256', '-sign', str(parent.key), str(message)])
                    token['id_token'] = unsigned + '.' + b64(signature)
                self.reply(token)

            def do_GET(self):
                target = urlsplit(self.path)
                if target.path == '/jwks':
                    parent.jwks_calls += 1
                    return self.reply(parent.jwks)
                if target.path == '/facebook/debug':
                    fields = parse_qs(target.query)
                    assert fields['access_token'] == ['peer-client|peer-secret']
                    code = fields['input_token'][0]
                    return self.reply(dict(data=dict(is_valid=True, app_id='peer-client', user_id=parent.codes[code].get('subject', code))))
                code = self.headers['Authorization'].removeprefix('Bearer ')
                if target.path == '/facebook/user':
                    assert parse_qs(target.query)['appsecret_proof'] == [hmac.new(b'peer-secret', code.encode(), hashlib.sha256).hexdigest()]
                return self.reply(dict(id=parent.codes[code].get('subject', code)))

        self.server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        self.origin = f'http://127.0.0.1:{self.server.server_port}'
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def close(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()


class Fixture:
    def __init__(self, binary, admin):
        self.binary, self.admin = Path(binary).resolve(), Path(admin).resolve()
        self.root = Path(tempfile.mkdtemp(prefix='transit-browser-', dir='/var/tmp'))
        self.ports = {name: free_port() for name in ('node', 'gateway', 'application', 'board', 'sql', 'browser')}
        self.origin = f'http://127.0.0.1:{self.ports["browser"]}'
        self.env = dict(os.environ, HOME=str(self.root), TRANSIT_LOGGING__LEVEL="debug", TRANSIT_PORTS__NODE=str(self.ports['node']), TRANSIT_PORTS__GATEWAY=str(self.ports['gateway']), TRANSIT_APPLICATIONS__PORT=str(self.ports['application']), TRANSIT_BOARD__PORT=str(self.ports['board']), TRANSIT_SQL__HEALTH_PORT=str(self.ports['sql']))
        self.process = None
        self.counter = 0
        self.peers = Peers(self.root)

    def command(self, *args):
        result = subprocess.run([str(self.binary), *args], cwd=self.root, env=self.env, capture_output=True, text=True, timeout=120)
        assert result.returncode == 0, (args, result.stdout, result.stderr)
        return result.stdout

    def start(self):
        self.log = (self.root / 'server.stderr').open('ab')
        self.process = subprocess.Popen([str(self.binary), 'server', '--no-ui'], cwd=self.root, env=self.env, stdout=subprocess.PIPE, stderr=self.log)
        deadline = time.monotonic() + 120
        while time.monotonic() < deadline:
            assert self.process.poll() is None, (self.root / 'server.stderr').read_text()[-8000:]
            if select.select([self.process.stdout], [], [], .1)[0]:
                line = self.process.stdout.readline()
                if line and json.loads(line).get('ready'):
                    return
        raise AssertionError('server did not become ready')

    def stop(self):
        if self.process:
            children = processes.children(self.process.pid)
            self.process.terminate()
            try:
                self.process.wait(timeout=15)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait(timeout=5)
            processes.joined(children)
            self.process.stdout.close()
            self.process = None
            self.log.close()

    def provision(self):
        self.start()
        self.command('migrate', 'plan', '--dir', str(ROOT / 'examples/declarative-browser/migrations'), '--out', str(self.root / 'plan.json'), '--format', 'json')
        self.command('migrate', 'apply', '--plan', str(self.root / 'plan.json'), '--format', 'json')
        gateway = json.loads((self.root / '.transit/sql/gateway.json').read_text())
        account = gateway['accounts'][0]
        binding = account['execution']['bindings'][0]
        self.connection = dict(scope=dict(realm=account['execution']['realm'], resource=binding['resource'], catalog=binding['catalog']), branch=1, audience=binding['owner'], principal=account['execution']['table_principal'], role=binding['role'])
        self.namespace = binding['namespace']
        self.seed = Path(account['keys']['table'])
        assert self.connection['principal'] != 1 and self.connection['role'] != 0
        self.stop()
        secret_dir = self.root / 'private-secrets'
        secret_dir.mkdir(mode=0o700)
        (secret_dir / 'oauth').write_text('peer-secret')
        shutil.copyfile(self.seed, secret_dir / 'reader')
        (secret_dir / 'reader').chmod(0o600)
        cookie_seed = self.root / 'cookie.seed'
        cookie_seed.write_text(secrets.token_hex(32))
        cookie_seed.chmod(0o600)
        browser = dict(port=self.ports['browser'], public_origin=self.origin, development_loopback=True, connection=self.connection, namespace=self.namespace, catalog_seed_file=str(self.seed), cookie_seed_file=str(cookie_seed), secret_directory=str(secret_dir), session_ttl_ms=3600000)
        (self.root / 'transit.yaml').write_text(json.dumps(dict(browser=browser)))
        self.start()
        # Listener readiness is independently observed, not inferred from SQL.
        deadline = time.monotonic() + 10
        while True:
            try:
                status, _, body = self.http('GET', '/auth/providers')
                assert status == 200, body
                break
            except ConnectionRefusedError:
                assert time.monotonic() < deadline, (self.root / 'server.stderr').read_text()[-8000:]
                time.sleep(.05)
        self.change('secret', dict(name='oauth', enabled=True, file='oauth'))
        self.change('secret', dict(name='reader', enabled=True, file='reader'))
        for name, mode in [('google', 'oidc_rs256_id_token'), ('github', 'oauth2_user_profile_json'), ('facebook', 'oauth2_appsecret_proof_debug')]:
            profile = dict(provider_name=name, issuer_profile=dict(issuer_id={'google':1,'github':2,'facebook':3}[name], realm_id=self.connection['scope']['realm'], issuer_uri=self.peers.origin, expected_audiences=['peer-client']), verification_mode=mode, client_id='peer-client', client_secret_id=1, authorize_endpoint=self.peers.origin+'/'+name+'/authorize', token_endpoint=self.peers.origin+'/'+name+'/token', userinfo_endpoint=self.peers.origin+'/'+name+'/user', scopes_space_separated='openid' if name == 'google' else 'profile')
            if name == 'facebook':
                profile['debug_token_endpoint'] = self.peers.origin + '/facebook/debug'
            self.change('provider', dict(enabled=True, profile=profile, secret='oauth', pkce='confidential_client' if name == 'facebook' else 's256', jwks_endpoint=self.peers.origin+'/jwks' if name == 'google' else None))
        spec = dict(mutation=list(secrets.token_bytes(16)), expected=None, name='catalog', title='Public catalog', meaning='Published public catalog items', source_name='catalog_items', sql="SELECT id, category, slug, title, description, href, visibility, status FROM catalog_items WHERE visibility = 'public'", resource_object=2001, definition_id=1, revision=1, audience='public', publisher=dict(principal=self.connection['principal'], role=self.connection['role'], secret='reader'))
        proposed = self.manage(dict(prepare_publication=spec))['proposed']
        self.manage(dict(change=proposed))

    def manage(self, action):
        self.counter += 1
        path = self.root / f'admin-{self.counter}.json'
        path.write_text(json.dumps(dict(definition=DEFINITION, connection=self.connection, namespace=self.namespace, development=True, action=action)))
        result = subprocess.run([str(self.admin), 'browser', str(self.seed), str(path), f'http://127.0.0.1:{self.ports["node"]}'], capture_output=True, text=True, timeout=15)
        assert result.returncode == 0, (result.stdout, result.stderr)
        return json.loads(result.stdout)

    def inspect(self, kind, name):
        key = bytes.fromhex(name) if kind == 'binding' else hashlib.sha256(name.encode()).digest()
        return self.manage(dict(inspect=dict(kind=kind, key=list(key))))['inspected']

    def change(self, kind, value, expected=None):
        return self.manage(dict(change=dict(definition=DEFINITION, namespace=self.namespace, mutation=list(secrets.token_bytes(16)), expected=expected, declaration={kind: value})))

    def http(self, method, path, cookie=None, headers=None):
        actual = dict(Origin=self.origin)
        if cookie:
            actual['Cookie'] = cookie
        if headers:
            for key, value in headers.items():
                if value is None:
                    actual.pop(key, None)
                else:
                    actual[key] = value
        connection = HTTPConnection('127.0.0.1', self.ports['browser'], timeout=10)
        try:
            connection.request(method, path, headers=actual)
            response = connection.getresponse()
            return response.status, response.getheaders(), response.read().decode()
        finally:
            connection.close()

    def login(self, provider, code=None, subject=None):
        status, headers, body = self.http('POST', '/auth/'+provider+'/login')
        assert status == 303, (status, body)
        location = dict(headers)['location']
        grant = parse_qs(urlsplit(location).query)
        code = code or secrets.token_hex(12)
        if subject:
            grant['subject'] = subject
        self.peers.codes[code] = grant
        cookie = next(value.split(';')[0] for key, value in headers if key == 'set-cookie')
        path = '/auth/'+provider+'/callback?' + urlencode(dict(state=grant['state'][0], code=code))
        return cookie, path

    def finish(self, login):
        return self.http('GET', login[1], login[0], headers={'Origin': None, 'Sec-Fetch-Site':'cross-site'})

    def session_cookie(self, response):
        assert response[0] == 303, response
        return next(value.split(';')[0] for key, value in response[1] if key == 'set-cookie' and value.startswith('transit_session='))

    def socket(self, name='catalog', cookie=None):
        headers = {'Origin': self.origin}
        if cookie:
            headers['Cookie'] = cookie
        return WebSocket(self.ports['browser'], self.origin.removeprefix('http://'), {}, headers=headers, path='/published/'+name+'/watch', subprotocol='transit.published.v1')

    def root_query(self, kind):
        key = ExistingKey(self.root, self.root / '.transit/root.seed')
        return post(self.ports['node'], '/v1/query', native(key, self.connection['scope']['realm'], 0, kind))

    def root_command(self, command):
        sequence = self.root_query(dict(identity={}))['principal_sequence'] + 1
        key = ExistingKey(self.root, self.root / '.transit/root.seed')
        return post(self.ports['node'], '/v1/command', native(key, self.connection['scope']['realm'], 0, command, sequence))['position']

    def authorize(self, action):
        def query(kind):
            return self.root_query(dict(authorization=dict(role=None, kind=kind)))['body']['authorization']
        revision = query(dict(identity={}))['revision']
        change = self.root_command(dict(authorization=dict(begin=dict(expected_revision=revision, role=None, action=action))))
        for _ in range(100):
            outcome = query(dict(change=change))['body']['change']
            if outcome['status'] == 'published':
                return outcome['created_id']
            self.root_command(dict(authorization={'publish' if outcome['status'] == 'ready' else 'advance': change}))
        raise AssertionError('native policy did not settle')

    def direct(self, action):
        key = ExistingKey(self.root, self.seed)
        realm, principal = self.connection['scope']['realm'], self.connection['principal']
        identity = post(self.ports['node'], '/v1/query', native(key, realm, principal, dict(authorization=dict(role=self.connection['role'], kind=dict(identity={})))) )
        body = dict(definition=identity['definition'], connection=self.connection, nonce=list(secrets.token_bytes(16)), action=action, delegation=None, closure=None, borrow=None, lease=None, transaction=None)
        claim = dict(definition=identity['definition'], realm=realm, principal=principal, credential_epoch=identity['body']['authorization']['body']['identity']['credential_epoch'], role=self.connection['role'], audience=self.connection['audience'], context=list(hashlib.sha256(b'transit.table.direct.request.v1\0'+compact(body)).digest()))
        proof = dict(claim=claim, signature=key.sign(hashlib.sha256(b'transit.authorization.subject.v1\0'+compact(claim)).digest()))
        return post(self.ports['node'], '/table/v1', dict(body, proof=proof))['result']

    def crash(self):
        children = processes.children(self.process.pid)
        self.process.kill()
        self.process.wait(timeout=5)
        processes.joined(children)
        self.process.stdout.close()
        self.log.close()
        self.process = None

    def configure(self, **settings):
        self.stop()
        path = self.root / 'transit.yaml'
        config = json.loads(path.read_text())
        config['browser'].update(settings)
        path.write_text(json.dumps(config))
        self.start()

    def close(self):
        self.stop()
        self.peers.close()


def run(binary, admin, fault_node=None):
    f = Fixture(binary, admin)
    if fault_node:
        boundary = f.root / 'browser-boundary'
        boundary.mkdir()
        # Keep native refusal diagnostics private and available after the
        # supervisor joins its child. Its bounded in-memory log is otherwise
        # intentionally not forwarded into the CLI's machine output.
        real_node = str(Path(fault_node).resolve())
        wrapper = f.root / 'browser-node'
        wrapper.write_text(f'#!{sys.executable}\nimport os, sys\n'
                           f'fd = os.open({str(f.root / "node.stderr")!r}, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)\n'
                           'os.dup2(fd, 2)\nos.close(fd)\n'
                           f'os.execv({real_node!r}, [{real_node!r}, *sys.argv[1:]])\n')
        wrapper.chmod(0o700)
        f.env['TRANSIT_EXECUTABLES__NODE'] = str(wrapper)
    print('Browser listener qualification:', f.root, flush=True)
    success = False
    try:
        f.provision()
        assert f.http('GET', '/health', headers={'Origin': None})[0] == 200
        status, _, body = f.http('GET', '/published/catalog/snapshot')
        assert status == 200, (status, body)
        value = json.loads(body)
        assert len(value['rows']) == 1 and value['rows'][0][0] == '9007199254740993', value
        assert value['attribution']['complete'] is True
        for provider in ('google', 'github', 'facebook'):
            cookie = f.session_cookie(f.finish(f.login(provider)))
            status, _, body = f.http('GET', '/auth/session', cookie)
            assert status == 200 and json.loads(body)['authenticated'] and not json.loads(body)['bound'], (status, body)
        print('Real listener: public source and three provider modes passed', flush=True)
        if fault_node:
            before = f.login('github', 'claim-before-fence')
            (boundary / 'conflict-before').write_text('refuse one unpublished candidate')
            f.session_cookie(f.finish(before))
            assert f.peers.calls.count('claim-before-fence') == 1
            after = f.login('github', 'claim-after-acceptance')
            (boundary / 'conflict-after').write_text('lose one accepted claim acknowledgement')
            assert f.finish(after)[0] == 409
            assert f.finish(after)[0] == 409
            assert 'claim-after-acceptance' not in f.peers.calls
            print('Original claim recovery: fenced candidate and lost acceptance acknowledgement passed', flush=True)
        for method, path in (('POST', '/auth/login'), ('POST', '/auth//login'), ('GET', '/auth/callback'), ('GET', '/published/watch'), ('GET', '/published//snapshot')):
            assert f.http(method, path)[0] == 404, (method, path)
        # Header/credential ambiguity cannot create an anonymous fallback.
        for headers in ({'Origin':None}, {'Origin':'https://wrong.example'}, {'Host':'wrong.example'}, {'X-Forwarded-Proto':'https'}, {'Forwarded':'proto=https'}, {'Authorization':'Bearer ambient'}, {'Cookie':'transit_session=a; transit_session=b'}):
            assert f.http('GET', '/auth/providers', headers=headers)[0] == 403, headers
        for headers in ({'Origin':'https://wrong.example'}, {'Origin':f.origin,'Host':'wrong.example'}, {'Origin':f.origin,'X-Forwarded-Proto':'https'}, {'Origin':f.origin,'Cookie':'transit_session=a; transit_session=b'}):
            denied_ws = WebSocket(f.ports['browser'], f.origin.removeprefix('http://'), {}, headers=headers, expected=403, path='/published/catalog/watch', subprotocol='transit.published.v1')
            denied_ws.close()
        pending = f.login('github', 'cross-browser')
        calls = len(f.peers.calls)
        wrong = ('transit_login='+'x'*43, pending[1])
        assert f.finish(wrong)[0] == 403
        assert len(f.peers.calls) == calls
        concurrent = f.login('github', 'slow-concurrent')
        with ThreadPoolExecutor(2) as pool:
            replies = list(pool.map(lambda _: f.finish(concurrent), range(2)))
        assert sorted(reply[0] for reply in replies)[-1] in (403, 409), replies
        assert sum(reply[0] == 303 for reply in replies) == 1, replies
        assert f.peers.calls.count('slow-concurrent') == 1
        assert f.finish(concurrent)[0] in (403, 409)
        for failure in ('bad-nonce', 'bad-aud', 'bad-issuer'):
            response = f.finish(f.login('google', failure))
            assert response[0] == 403, response
        uncertain = f.login('github', 'uncertain-drop')
        assert f.finish(uncertain)[0] != 303
        assert f.peers.calls.count('uncertain-drop') == 1
        saved_cookie = f.session_cookie(f.finish(f.login('github', 'durable-session')))
        before_restart = f.login('github', 'before-restart')
        f.stop()
        f.start()
        assert f.finish(uncertain)[0] in (403, 409)
        assert f.peers.calls.count('uncertain-drop') == 1
        assert f.http('GET', '/auth/session', saved_cookie)[0] == 200
        f.session_cookie(f.finish(before_restart))
        print('Callbacks: binding, concurrency, signed-token denials, uncertainty and restart passed', flush=True)
        # Mounted secret rotation invalidates an already issued challenge before
        # any provider effect, even when the declaration itself was unchanged.
        old_secret = f.login('github', 'secret-rotated')
        secret_file = f.root / 'private-secrets/oauth'
        secret_file.write_text('replacement-secret')
        assert f.finish(old_secret)[0] == 403
        assert 'secret-rotated' not in f.peers.calls
        secret_file.write_text('peer-secret')
        # Unknown kid refresh uses actual JWKS acquisition; explicit retirement
        # rejects it despite a still-valid signature and a cached public key.
        time.sleep(1.05)
        calls = f.peers.jwks_calls
        f.peers.kid = 'rotated-key'
        f.peers.jwks['keys'][0]['kid'] = f.peers.kid
        f.session_cookie(f.finish(f.login('google', 'rotated-jwks')))
        assert f.peers.jwks_calls > calls
        provider = f.inspect('provider', 'google')
        provider_value = json.loads(provider['record']['payload'])['provider']
        provider_value['retired_kids'] = ['rotated-key']
        f.change('provider', provider_value, provider['revision'])
        assert f.finish(f.login('google', 'retired-key'))[0] == 403
        # SIGKILL after remote dispatch cannot release the durable one-use claim.
        pending_crash = f.login('github', 'crash-after-dispatch')
        with ThreadPoolExecutor(1) as pool:
            reply = pool.submit(f.finish, pending_crash)
            assert f.peers.dispatched.wait(10)
            f.crash()
            f.peers.release_exchange.set()
            try:
                reply.result(timeout=10)
            except (OSError, ConnectionError):
                pass
        f.start()
        assert f.finish(pending_crash)[0] in (403, 409)
        assert f.peers.calls.count('crash-after-dispatch') == 1
        print('Secret rotation, JWKS refresh/retirement and process-death claim recovery passed', flush=True)

        # A genuinely separate native reader proves credentials do not borrow
        # the service's data grants. Native policy alone owns those privileges.
        restricted_key = f.root / 'private-secrets/restricted'
        restricted_key.write_text(secrets.token_hex(32))
        restricted_key.chmod(0o600)
        reader_key = ExistingKey(f.root, restricted_key)
        role = f.authorize(dict(create_role=dict(name=b'browser_reader'.hex(), login=True, create_role=False)))
        principal = 700001
        f.authorize(dict(bind_credential=dict(principal=principal, role=role, public_key=reader_key.public, pid=None)))
        f.change('secret', dict(name='restricted', enabled=True, file='restricted'))
        live_cookie = f.session_cookie(f.finish(f.login('github', 'native-reader')))
        identity = json.loads(f.http('GET', '/auth/session', live_cookie)[2])['identity']
        f.change('binding', dict(identity=list(bytes.fromhex(identity)), enabled=True, restricted=False, reader=dict(principal=principal, role=role, secret='restricted')))
        public = f.inspect('publication', 'catalog')
        declaration = json.loads(public['record']['payload'])['publication']
        protected = json.loads(json.dumps(declaration))
        protected['audience'] = 'bound_identity'
        protected['descriptor'].update(canonical_name='protected', resource_object=2002)
        protected['descriptor']['result_schema']['object'] = 2002
        f.change('publication', protected)
        assert f.http('GET', '/published/protected/snapshot')[0] == 403
        unbound = f.http('GET', '/published/protected/snapshot', cookie)
        assert unbound[0] == 403, (unbound[0], unbound[2])
        assert f.http('GET', '/published/protected/snapshot', live_cookie)[0] == 403
        authority = f.direct(dict(read_authority=declaration['source']['object']))['read_authority']
        for name in ('database', 'schema', 'table'):
            f.authorize(dict(grant=dict(object=dict(kind='domain', id=authority[name]), grantee=role, privileges=1, grant_options=0)))
        assert f.http('GET', '/published/protected/snapshot', live_cookie)[0] == 200
        ws = f.socket('protected', live_cookie)
        try:
            initial_frame = ws.receive()
            assert initial_frame[0] == 1, initial_frame
            f.authorize(dict(revoke_privileges=dict(object=dict(kind='domain', id=authority['table']), grantee=role, privileges=1, grant_option_only=False, behavior='cascade')))
            closed = ws.receive()
            assert closed[0] == 8 and struct.unpack('>H', closed[1][:2])[0] == 1008, closed
        finally:
            ws.close()
        assert f.http('GET', '/published/protected/snapshot', live_cookie)[0] == 403
        print('Native authorization: unbound/denied access, explicit binding, grant and watch revocation passed', flush=True)
        ws = f.socket(cookie=saved_cookie)
        try:
            initial = ws.receive()
            assert initial[0] == 1
            ws.socket.settimeout(1.2)
            try:
                ws.receive()
                raise AssertionError('unchanged watermark emitted a new snapshot')
            except socket.timeout:
                pass
            ws.socket.settimeout(5)
            f.command('console', '--no-rc', '-c', "UPDATE catalog_items SET title = 'Changed' WHERE id = 9007199254740993;")
            changed = ws.receive()
            assert changed[0] == 1 and changed[1]['rows'][0][3] == 'Changed', changed
            assert int(changed[1]['attribution']['watermark_lsn']) > int(initial[1]['attribution']['watermark_lsn'])
            assert f.http('POST', '/auth/logout', saved_cookie)[0] == 200
            closed = ws.receive()
            assert closed[0] == 8 and struct.unpack('>H', closed[1][:2])[0] == 1008, closed
        finally:
            ws.close()
        f.stop()
        f.start()
        assert f.http('GET', '/auth/session', saved_cookie)[0] == 403
        ws = f.socket()
        try:
            initial_frame = ws.receive()
            assert initial_frame[0] == 1, initial_frame
            public = f.inspect('publication', 'catalog')
            declaration = json.loads(public['record']['payload'])['publication']
            declaration['descriptor']['state'] = 'withdrawn'
            f.change('publication', declaration, public['revision'])
            closed = ws.receive()
            assert closed[0] == 8 and struct.unpack('>H', closed[1][:2])[0] == 1008, closed
        finally:
            ws.close()
        assert f.http('GET', '/published/catalog/snapshot')[0] == 403
        print('Watches: source refresh, idle watermark, durable logout and withdrawal passed', flush=True)
        # Retained population exceeds every 64-entry model collection.
        for index in range(70):
            if index % 10 == 0:
                print('Identity population:', index, flush=True)
            f.session_cookie(f.finish(f.login('github', f'population-{index}')))
        page = f.manage(dict(list=dict(kind='identity', after=None)))['page']
        count = len(page['entries'])
        while page['next'] is not None:
            page = f.manage(dict(list=dict(kind='identity', after=page['next'])))['page']
            assert len(page['entries']) <= 8
            count += len(page['entries'])
        assert count > 64, count
        print('Durable identity population and bounded catalog pagination passed:', count, flush=True)
        # Restriction is durable, applies to otherwise public reads with a
        # presented identity, and closes an already-open socket.
        public = f.inspect('publication', 'catalog')
        declaration = json.loads(public['record']['payload'])['publication']
        declaration['descriptor']['state'] = 'published'
        f.change('publication', declaration, public['revision'])
        ws = f.socket(cookie=live_cookie)
        try:
            initial_frame = ws.receive()
            assert initial_frame[0] == 1, initial_frame
            binding = f.inspect('binding', identity)
            bound = json.loads(binding['record']['payload'])['binding']
            bound['restricted'] = True
            f.change('binding', bound, binding['revision'])
            closed = ws.receive()
            assert closed[0] == 8 and struct.unpack('>H', closed[1][:2])[0] == 1008, closed
        finally:
            ws.close()
        f.stop()
        f.start()
        assert f.http('GET', '/auth/session', live_cookie)[0] == 403
        binding = f.inspect('binding', identity)
        bound['restricted'] = False
        f.change('binding', bound, binding['revision'])
        # An actual short-lived session expires during an open watch and stays
        # expired after replacement. This uses the public placement TTL.
        f.configure(session_ttl_ms=1000)
        expiring = f.session_cookie(f.finish(f.login('github', 'expires')))
        ws = f.socket(cookie=expiring)
        try:
            initial_frame = ws.receive()
            assert initial_frame[0] == 1, initial_frame
            closed = ws.receive()
            assert closed[0] == 8 and struct.unpack('>H', closed[1][:2])[0] == 1008, closed
        finally:
            ws.close()
        f.configure(session_ttl_ms=3600000)
        assert f.http('GET', '/auth/session', expiring)[0] == 403
        print('Durable restriction and expiry during active watches passed', flush=True)
        if fault_node:
            f.stop()
            boundary = f.root / 'browser-boundary'
            boundary.mkdir(exist_ok=True)
            f.start()
            for index in range(10):
                f.command('console', '--no-rc', '-c', "INSERT INTO catalog_items (id, category, slug, title, description, href, visibility, status) VALUES ("+str(200+index)+", 'example', 'page-"+str(index)+"', 'Page', 'Description', '/page', 'public', 'active');")
            paged = json.loads(f.http('GET','/published/catalog/snapshot')[2])
            assert len(paged['rows']) == 11 and paged['attribution']['row_count'] == '11', paged
            ws = f.socket()
            try:
                initial_frame = ws.receive()
                assert initial_frame[0] == 1, initial_frame
                scans = int((boundary / 'reads').read_text())
                time.sleep(1.2)
                assert int((boundary / 'reads').read_text()) == scans
            finally:
                ws.close()
            grant = dict(object=dict(kind='domain', id=authority['table']), grantee=role, privileges=1, grant_options=0)
            f.authorize(dict(grant=grant))
            for action in ('revoke', 'withdraw', 'source-change'):
                (boundary / 'buffered').unlink(missing_ok=True)
                (boundary / 'hold').write_text('hold after actual native row read')
                with ThreadPoolExecutor(1) as pool:
                    response = pool.submit(f.http, 'GET', '/published/protected/snapshot', live_cookie)
                    deadline = time.monotonic() + 10
                    while not (boundary / 'buffered').exists():
                        assert time.monotonic() < deadline, action
                        time.sleep(.01)
                    if action == 'revoke':
                        f.authorize(dict(revoke_privileges=dict(object=grant['object'], grantee=role, privileges=1, grant_option_only=False, behavior='cascade')))
                    elif action == 'withdraw':
                        record = f.inspect('publication', 'protected')
                        value = json.loads(record['record']['payload'])['publication']
                        value['descriptor']['state'] = 'withdrawn'
                        f.change('publication', value, record['revision'])
                    else:
                        f.command('console', '--no-rc', '-c', "UPDATE catalog_items SET title = 'During read' WHERE id = 9007199254740993;")
                    (boundary / 'hold').unlink()
                    denied = response.result(timeout=10)
                    assert denied[0] == 403 and 'rows' not in json.loads(denied[2]), (action, denied)
                if action == 'revoke':
                    f.authorize(dict(grant=grant))
                if action == 'withdraw':
                    record = f.inspect('publication', 'protected')
                    value['descriptor']['state'] = 'published'
                    f.change('publication', value, record['revision'])
            print('Native read counters and buffered revocation/withdrawal/source-change schedules passed', flush=True)
            ws = f.socket()
            try:
                assert ws.receive()[0] == 1
                f.command('console', '--no-rc', '-c', 'ALTER TABLE catalog_items ADD COLUMN tag TEXT;')
                closed = ws.receive()
                assert closed[0] == 8 and struct.unpack('>H',closed[1][:2])[0] == 1012, closed
            finally:
                ws.close()
            assert f.http('GET','/published/catalog/snapshot')[0] != 200
            print('Multi-page ownership and source-definition replacement passed', flush=True)


        # Production forwarding is accepted only from the configured socket
        # peer subnet and still requires the exact public Host and Origin.
        f.configure(public_origin='https://app.example.test', development_loopback=False, trusted_proxy_cidr='127.0.0.1/32')
        assert json.loads(f.http('GET', '/health', headers={'Origin': None})[2]) == {'ready': True}
        headers = {'Host':'app.example.test','Origin':'https://app.example.test','X-Forwarded-Proto':'https'}
        assert f.http('GET','/auth/providers',headers=headers)[0] == 200
        for overrides in ({'X-Forwarded-Proto':None},{'X-Forwarded-Proto':'http'},{'Host':'wrong.example'},{'Origin':None},{'X-Forwarded-Host':'app.example.test'}):
            assert f.http('GET','/auth/providers',headers=dict(headers,**overrides))[0] == 403, overrides
        f.configure(trusted_proxy_cidr='10.0.0.0/8')
        for route in ('/auth/providers', '/health'):
            try:
                f.http('GET', route, headers=headers)
            except (OSError, ConnectionError):
                pass
            else:
                raise AssertionError('untrusted socket peer reached browser HTTP')
        print('Production exact origin and actual proxy-peer subnet checks passed', flush=True)
        success = True
    finally:
        f.close()
        if success:
            shutil.rmtree(f.root)
        else:
            print('Private failure state retained:', f.root, flush=True)


if __name__ == '__main__':
    run(*sys.argv[1:])
