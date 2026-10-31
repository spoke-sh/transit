#!/usr/bin/env python3
"""Independent OAuth peers, durable Transit state, HTTP/WS browser boundary."""
import base64
from concurrent.futures import ThreadPoolExecutor
import hashlib
import hmac
import http.client
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import socket
import struct
import subprocess
import sys
import threading
import time
from urllib.parse import parse_qs, urlencode, urlsplit

from runner.paths import ROOT
from interfaces.installation.server import Fixture


def b64(value):
    return base64.urlsafe_b64encode(value).rstrip(b'=').decode()


class Providers:
    def __init__(self, root):
        self.key = root / 'provider.key'
        subprocess.run(['openssl', 'genpkey', '-algorithm', 'RSA', '-pkeyopt', 'rsa_keygen_bits:2048', '-out', str(self.key)], check=True, capture_output=True)
        modulus = subprocess.check_output(['openssl', 'rsa', '-in', str(self.key), '-noout', '-modulus'], stderr=subprocess.DEVNULL).decode().strip().split('=')[1]
        self.jwks = dict(keys=[dict(kty='RSA', kid='fixture', alg='RS256', use='sig', n=b64(bytes.fromhex(modulus)), e='AQAB')])
        self.codes, self.tokens, self.calls = {}, {}, 0
        owner = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def do_GET(self):
                self.reply()

            def do_POST(self):
                self.reply()

            def reply(self):
                try:
                    path = urlsplit(self.path)
                    fields = parse_qs(self.rfile.read(int(self.headers.get('Content-Length', '0'))).decode()) if self.command == 'POST' else parse_qs(path.query)
                    provider, action = path.path.strip('/').split('/')
                    if action == 'token':
                        owner.calls += 1
                        item = owner.codes.pop(fields['code'][0])
                        assert fields['client_id'] == ['fixture-client'] and fields['client_secret'] == ['fixture-secret']
                        assert fields['redirect_uri'] == item['redirect_uri']
                        if provider != 'facebook':
                            assert b64(hashlib.sha256(fields['code_verifier'][0].encode()).digest()) == item['code_challenge'][0]
                        access = os.urandom(16).hex()
                        owner.tokens[access] = item
                        value = dict(access_token=access, token_type='Bearer')
                        if provider == 'google':
                            now = int(time.time())
                            claims = dict(iss='https://accounts.google.com', sub='123', aud='fixture-client', nonce=item['nonce'][0], iat=now, exp=now + 300)
                            if item.get('invalid'): claims['aud'] = 'other-client'
                            message = (b64(json.dumps(dict(alg='RS256', kid='fixture')).encode()) + '.' + b64(json.dumps(claims).encode())).encode()
                            signature = subprocess.check_output(['openssl', 'dgst', '-sha256', '-sign', str(owner.key)], input=message)
                            value['id_token'] = message.decode() + '.' + b64(signature)
                    elif action == 'jwks':
                        value = owner.jwks
                    elif action == 'debug':
                        assert self.headers['Authorization'] == 'Bearer fixture-client|fixture-secret'
                        item = owner.tokens[fields['input_token'][0]]
                        value = dict(data=dict(is_valid=True, app_id='wrong' if item.get('invalid') else 'fixture-client', user_id='123'))
                    elif action == 'user':
                        access = self.headers['Authorization'].removeprefix('Bearer ')
                        assert access in owner.tokens
                        if provider == 'facebook':
                            assert fields['appsecret_proof'] == [hmac.new(b'fixture-secret', access.encode(), hashlib.sha256).hexdigest()]
                        value = dict(id=123 if provider == 'github' else '123')
                    else:
                        raise AssertionError(action)
                    body = json.dumps(value).encode()
                    self.send_response(200)
                except Exception:
                    body = b'{"error":"fixture_rejected"}'
                    self.send_response(400)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Content-Length', str(len(body)))
                self.end_headers()
                self.wfile.write(body)

        self.server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def code(self, location, invalid=False):
        fields = parse_qs(urlsplit(location).query)
        code = os.urandom(16).hex()
        self.codes[code] = dict(fields, invalid=invalid)
        return fields['redirect_uri'][0] + '?' + urlencode(dict(state=fields['state'][0], code=code))

    def close(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()


class Browser:
    def __init__(self, port):
        self.port = port
        self.origin = f'http://127.0.0.1:{port}'
        self.cookies = {}

    def request(self, method, path, expected=200, headers=None, callback=False):
        fields = dict(Origin=self.origin, **{'Sec-Fetch-Site': 'same-origin'})
        if callback:
            fields = {'Sec-Fetch-Site': 'cross-site'}
        fields['Cookie'] = '; '.join(f'{k}={v}' for k, v in self.cookies.items())
        fields.update(headers or {})
        fields = {k: v for k, v in fields.items() if v is not None and v != ''}
        conn = http.client.HTTPConnection('127.0.0.1', self.port, timeout=25)
        conn.request(method, path, headers=fields)
        response = conn.getresponse()
        body = response.read()
        pairs = response.getheaders()
        assert response.status == expected, (method, path.split('?')[0], response.status, body)
        for name, value in pairs:
            if name.lower() == 'set-cookie':
                key, token = value.split(';')[0].split('=', 1)
                if token: self.cookies[key] = token
                else: self.cookies.pop(key, None)
                assert 'HttpOnly' in value and 'SameSite=Lax' in value
        conn.close()
        return dict((k.lower(), v) for k, v in pairs), json.loads(body) if body else None

    def login(self, provider, peers, invalid=False):
        headers, _ = self.request('POST', '/auth/login/' + provider, 303)
        callback = peers.code(headers['location'], invalid)
        path = callback.removeprefix(self.origin)
        login_cookie = self.cookies['transit-login']
        self.request('GET', path, 503 if invalid else 303, callback=True)
        return path, login_cookie


class Socket:
    def __init__(self, browser, expected=101, origin=True, path='/api/watch/public'):
        self.socket = socket.create_connection(('127.0.0.1', browser.port), timeout=20)
        key = base64.b64encode(os.urandom(16)).decode()
        fields = dict(Host=f'127.0.0.1:{browser.port}', Upgrade='websocket', Connection='Upgrade', **{'Sec-WebSocket-Key': key, 'Sec-WebSocket-Version': '13', 'Sec-WebSocket-Protocol': 'transit.browser.v1'})
        if origin: fields['Origin'] = browser.origin if origin is True else origin
        if browser.cookies: fields['Cookie'] = '; '.join(f'{k}={v}' for k, v in browser.cookies.items())
        self.socket.sendall(('GET ' + path + ' HTTP/1.1\r\n' + ''.join(f'{k}: {v}\r\n' for k, v in fields.items()) + '\r\n').encode())
        head = bytearray()
        while not head.endswith(b'\r\n\r\n'):
            part = self.socket.recv(1)
            assert part, 'interrupted upgrade'
            head += part
        assert int(head.split()[1]) == expected, head
        if expected == 101:
            accept = base64.b64encode(hashlib.sha1((key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').encode()).digest())
            assert accept in head and b'transit.browser.v1' in head
        else: self.close()

    def exact(self, size):
        data = bytearray()
        while len(data) < size:
            part = self.socket.recv(size - len(data))
            assert part, 'interrupted frame'
            data += part
        return bytes(data)

    def receive(self):
        h0, h1 = self.exact(2)
        assert h0 & 0xf0 == 128 and h1 & 128 == 0
        size = h1 & 127
        if size == 126: size = struct.unpack('>H', self.exact(2))[0]
        elif size == 127: size = struct.unpack('>Q', self.exact(8))[0]
        assert size <= 8192
        data = self.exact(size)
        return h0 & 15, json.loads(data) if h0 & 15 == 1 else data

    def close(self):
        self.socket.close()


def main():
    fixture = Fixture(sys.argv[1], sys.argv[1], sys.argv[1])
    peers = Providers(fixture.root)
    fixture.config['executables'] = {}
    fixture.config['applications'] = dict(port=fixture.reserve_port())
    port = fixture.reserve_port()
    browser = Browser(port)
    secret = fixture.root / 'browser.secret'
    secret.write_text(os.urandom(32).hex())
    provider_secret = fixture.root / 'provider.secret'
    provider_secret.write_text('fixture-secret')
    digest = hashlib.sha256(str(fixture.installation).encode()).hexdigest()[:32]
    connection = dict(endpoint=f'unix:/tmp/transit-{os.geteuid()}/{digest}.sock')
    config = dict(public_origin=browser.origin, port=port, development=True, secret_file=str(secret), state=connection, public_reader=connection,
        providers=[dict(provider=name, client_id='fixture-client', client_secret_file=str(provider_secret), test_endpoint=f'http://127.0.0.1:{peers.server.server_port}') for name in ('google', 'github', 'facebook')],
        views=[dict(name='public', sql='SELECT id, label FROM browser_catalog WHERE visible = 1 LIMIT 128', access='public'), dict(name='private', sql='SELECT id FROM browser_catalog'), dict(name='mutation', sql="DELETE FROM browser_catalog WHERE id = 1", access='public')])
    path = fixture.root / 'browser.json'
    path.write_text(json.dumps(config))
    fixture.config['browser_file'] = str(path)
    fixture.path.write_text(json.dumps(fixture.config))
    try:
        fixture.start()
        fixture.ready()
        fixture.console((ROOT / 'packages/zig/transit-browser/schema.sql').read_text())
        fixture.console("CREATE TABLE browser_catalog (id INT64 PRIMARY KEY, label VARCHAR, visible INT64); INSERT INTO browser_catalog (id, label, visible) VALUES (1, 'public', 1), (2, 'secret', 0);")
        for origin in ('null', 'https://evil.test', browser.origin + '.evil.test'):
            browser.request('GET', '/api/views/public', 403, {'Origin': origin})
            Socket(browser, 403, origin=origin)
        browser.request('GET', '/api/views/public', 403, {'Origin': None, 'Sec-Fetch-Site': None})
        browser.request('GET', '/api/views/public', 403, {'Host': 'evil.test'})
        browser.request('POST', '/auth/login/google', 403, {'Origin': None})
        Socket(browser, 403, origin=False)
        browser.request('GET', '/api/views/private', 401)
        browser.request('GET', '/api/views/mutation', 503)
        assert browser.request('GET', '/api/views/public')[1] == dict(rows=[dict(id='1', label='public')])
        assert browser.request('GET', '/api/views/public', headers={'Origin': None})[1]['rows']
        identities = set()
        for provider in ('google', 'github', 'facebook'):
            callback, login_cookie = browser.login(provider, peers)
            identity = browser.request('GET', '/auth/session')[1]['identity']
            assert identity['provider'] == provider and identity['bound'] is False
            identities.add(identity['id'])
            browser.request('GET', '/api/views/private', 401)
            calls = peers.calls
            browser.cookies['transit-login'] = login_cookie
            browser.request('GET', callback, 403, callback=True)
            assert peers.calls == calls
            browser.cookies.pop('transit-login')
        assert len(identities) == 3
        browser.login('google', peers, invalid=True)
        browser.login('facebook', peers, invalid=True)
        # Cross-browser state is rejected before any provider effect.
        headers, _ = browser.request('POST', '/auth/login/github', 303)
        callback = peers.code(headers['location']).removeprefix(browser.origin)
        other = Browser(port)
        other.cookies['transit-login'] = 'a' * 64
        calls = peers.calls
        other.request('GET', callback, 403, callback=True)
        assert peers.calls == calls
        browser.request('GET', callback, 303, callback=True)
        # An expired challenge fails before provider exchange.
        headers, _ = browser.request('POST', '/auth/login/github', 303)
        expired = peers.code(headers['location']).removeprefix(browser.origin)
        state = parse_qs(urlsplit(expired).query)['state'][0]
        digest = hashlib.sha256(state.encode()).hexdigest()
        fixture.console(f"UPDATE transit_browser_challenges SET expires_at = 0 WHERE state_hash = '{digest}';")
        calls = peers.calls
        browser.request('GET', expired, 403, callback=True)
        assert peers.calls == calls
        # Parallel callbacks share the same browser state, but exchange once.
        headers, _ = browser.request('POST', '/auth/login/github', 303)
        parallel = peers.code(headers['location']).removeprefix(browser.origin)
        calls = peers.calls
        def finish(_):
            client = Browser(port)
            client.cookies = dict(browser.cookies)
            conn = http.client.HTTPConnection('127.0.0.1', port, timeout=40)
            conn.request('GET', parallel, headers={'Cookie': 'transit-login=' + client.cookies['transit-login']})
            response = conn.getresponse()
            response.read()
            status = response.status
            conn.close()
            return status
        with ThreadPoolExecutor(max_workers=2) as pool:
            statuses = list(pool.map(finish, range(2)))
        assert statuses.count(303) == 1 and all(s in (303, 403, 503) for s in statuses), statuses
        assert peers.calls == calls + 1
        socket_peer = Socket(browser)
        assert socket_peer.receive() == (1, dict(rows=[dict(id='1', label='public')]))
        fixture.console("UPDATE browser_catalog SET label = 'updated' WHERE id = 1;")
        for _ in range(10):
            opcode, value = socket_peer.receive()
            assert opcode == 1
            if value['rows'][0]['label'] == 'updated': break
        else: raise AssertionError('changed snapshot absent')
        retained = dict(browser.cookies)
        browser.request('POST', '/auth/logout', 303)
        while True:
            opcode, value = socket_peer.receive()
            if opcode == 8:
                assert struct.unpack('>H', value[:2])[0] == 1008
                break
        socket_peer.close()
        browser.cookies = retained
        browser.request('GET', '/auth/session', 401)
        callback, login_cookie = browser.login('github', peers)
        identity = browser.request('GET', '/auth/session')[1]['identity']
        fixture.stop()
        fixture.start()
        fixture.ready()
        assert browser.request('GET', '/auth/session')[1]['identity'] == identity
        browser.cookies['transit-login'] = login_cookie
        calls = peers.calls
        browser.request('GET', callback, 403, callback=True)
        assert peers.calls == calls
        fixture.console(f"UPDATE transit_browser_identities SET disabled = 1 WHERE subject_hash = '{identity['id']}';")
        browser.request('GET', '/auth/session', 401)
        print('browser auth: three providers, durable sessions/replay, HTTP/WS origin, read-only snapshots and revocation passed')
    except BaseException:
        print('private fixture retained:', fixture.root, file=sys.stderr)
        raise
    finally:
        peers.close()
        fixture.cleanup()


if __name__ == '__main__':
    main()
