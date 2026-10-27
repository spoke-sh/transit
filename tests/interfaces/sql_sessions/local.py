"""Private peer-session client for lifecycle proofs that inspect native controls."""
from http.client import HTTPConnection
import socket
from interfaces.sql_sessions.native import Client as NativeClient
from interfaces.sql_sessions.result_frame import Decoder


class Client(NativeClient):
    def __init__(self, config, definition):
        self.config, self.definition = config, definition
        self.instance = self.session = self.account = None
        self.last = 0
        self.results = {}
        self.decoder = Decoder()
        self.transport()

    def transport(self):
        path = self.config['endpoint'].removeprefix('unix:')
        class Peer(HTTPConnection):
            def connect(self):
                self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                self.sock.settimeout(40)
                self.sock.connect(path)
        self.http = Peer('localhost')

    def open(self):
        self.call('hello')
        opened = self.call(dict(open=dict(account=self.config['account'], database=self.config['database'], authentication='peer')))['opened']
        self.session, self.account = opened['session'], opened['account']
        return self
