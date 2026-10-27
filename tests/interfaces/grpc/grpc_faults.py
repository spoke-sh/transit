"""Deterministic public-boundary pauses for the actual finite RPC worker."""
import threading


class Boundary:
    def __init__(self):
        self.phase = None
        self.reached = threading.Event()
        self.release = threading.Event()
        self.peer_blocked = threading.Event()
        self.peer_release = threading.Event()

    def arm(self, phase):
        self.release.clear()
        self.reached.clear()
        self.phase = phase

    def hit(self, phase):
        if self.phase == phase and not self.reached.is_set():
            self.reached.set()
            assert self.release.wait(timeout=120), f'unreleased {phase} boundary'

    def before(self, command):
        if 'dispatch' in command: self.hit('before_dispatch')

    def after(self, command, values):
        if 'dispatch' in command: self.hit('dispatch')
        if 'observe' in command: self.hit('observe')
        if any(value.startswith(b'{"version":1,"endpoint_revision":') for value in values):
            self.hit('preparation')
        # EXD1 encodes its one-byte capture phase immediately after magic.
        if any(value.startswith(b'EXD1\x03') for value in values): self.hit('complete')

    def peer(self, operation):
        if operation == 'blocked-control':
            self.peer_blocked.set()
            assert self.peer_release.wait(timeout=120), 'unreleased peer'

    def close(self):
        self.release.set()
        self.peer_release.set()
