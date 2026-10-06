"""Same independent protocol peers against actual private physical placements."""
import hashlib
import struct
import time
from serving_table import watch as table_watch

import serving
from serving import frame, native_command, post
from reactive import WebSocket, SSE, reactive, signed_read


class PhysicalReactive:
    def __init__(self, environment):
        self.env = environment
        self.scope = None
        self.attachment = 0
        self.cursor = None
        self.peer = self.stream = None
        self.key = environment['keys'][65536]

    def endpoints(self):
        proxies = self.env['proxies']
        self.tls = {proxy.port: proxy for proxy in proxies}
        serving.TLS = self.tls
        self.port, self.alternate = [proxy.port for proxy in proxies]
        self.host = 'serving.example.test'

    def command(self, payload, principal=65536):
        position = self.env['send']({'send': dict(pid=self.env['ingress'], value=frame(payload))}, principal)
        self.env['drained'](self.env['ingress'])
        return position

    def open(self, session):
        now = int(time.time() * 1000)
        self.command(reactive(1, struct.pack('<Q', now)), 34)
        generation = self.command(reactive(2, struct.pack('<QQQ', session, 1, now + 28000)))
        subscription = self.command(reactive(4, struct.pack('<QQQQQ', session, generation, 0, 3, 1)))
        self.scope = dict(realm=49, principal=65536, service=1, ingress=self.env['ingress'], session=session, generation=generation, subscription=3, subscription_generation=subscription)
        self.attachment = 0

    def bootstrap(self, nonce, cursor):
        payload = reactive(3, struct.pack('<QQQ', self.scope['session'], self.scope['generation'], self.attachment) + bytes(nonce))
        self.attachment += 1
        sequence = self.env['sequences'][65536] + 1
        signed = native_command(self.key, 65536, sequence, {'send': dict(pid=self.env['ingress'], value=frame(payload))})
        self.env['sequences'][65536] = sequence
        return dict(version=1, attach=signed, read=signed_read(self.key, self.scope, 'events', self.attachment, nonce, cursor))

    def begin(self):
        self.endpoints()
        source = table_watch(self.env['counter_definition'], self.env['application'])
        self.command(reactive(0, source), 33)
        self.open(7)
        self.peer = WebSocket(self.port, self.host, self.tls)
        challenge = self.peer.until('challenge')
        self.peer.send({'attach': self.bootstrap(challenge['nonce'], None)})
        self.peer.until('attached')
        self.cursor = self.peer.until('event')['cursor']

    def submit(self, frozen):
        # Drop the socket-side receipt; the existing physical HTTP recovery
        # schedule must recover this exact command rather than create another.
        self.peer.send({'command': frozen})

    def before_loss(self):
        challenge = post(self.alternate, '/reactive/v1/challenge', signed_read(self.key, self.scope), self.host)['challenge']
        self.previous = self.bootstrap(challenge['nonce'], self.cursor)
        self.stream = SSE(self.alternate, self.host, self.tls, self.previous)
        self.stream.until('attached')
        self.stream.until('heartbeat')
        assert self.peer.until('terminal')['reason'] == 'fenced'
        self.peer.close()
        self.peer = None

    def restore(self):
        self.stream.close()
        self.stream = None
        self.endpoints()
        old = post(self.port, '/reactive/v1/read', signed_read(self.key, self.scope), self.host)['session']
        assert old['generation'] == self.scope['generation'] and old['attachment'] == self.attachment
        expired = old['lease_before_ms'] <= int(time.time() * 1000) + 1000
        if expired:
            post(self.port, '/reactive/v1/read', self.previous['read'], self.host, 410)
            # No timer observer was delivered while the stack was absent. The
            # gateway refuses disclosure anyway; explicit close frees quota.
            self.command(reactive(7, struct.pack('<QQ', self.scope['session'], self.scope['generation'])))
            self.open(8)
            cursor = None
        else:
            cursor = self.cursor
        challenge = post(self.port, '/reactive/v1/challenge', signed_read(self.key, self.scope), self.host)['challenge']
        replacement = self.bootstrap(challenge['nonce'], cursor)
        self.stream = SSE(self.port, self.host, self.tls, replacement)
        self.stream.until('attached')
        event = self.stream.until('event')
        assert event['event']['source_changed'] and event['event']['outcome']['operation'] == 1
        assert event['cursor']['position']['data_revision'] > self.cursor['position']['data_revision']
        snapshot = post(self.alternate, '/reactive/v1/read', signed_read(self.key, self.scope, 'snapshot', self.attachment, challenge['nonce']), self.host)
        assert snapshot['snapshot']['rows'][0]['value'] == '1'
        print(f'Reactive {self.env["profile"]}: TLS WebSocket/SSE, replacement fencing, exact HTTP command recovery and retained session/source meaning passed; lease elapsed during physical recovery={expired}', flush=True)

    def retired(self):
        assert self.stream.until('terminal')['reason'] == 'reset_required'
        self.stream.close()
        self.stream = None
