"""Loopback port discovery and bounded HTTP process readiness."""
import socket
import time
import urllib.error
from contextlib import ExitStack


def free_port():
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        return listener.getsockname()[1]


def free_ports(count):
    """Discover distinct loopback ports together; these are not reservations."""
    if count < 1:
        raise ValueError("At least one port is required")
    with ExitStack() as stack:
        listeners = []
        for _ in range(count):
            listener = stack.enter_context(socket.socket())
            listener.bind(("127.0.0.1", 0))
            listeners.append(listener)
        return [listener.getsockname()[1] for listener in listeners]


def wait_ready(http, process, url):
    deadline = time.monotonic() + 30
    while True:
        if process.poll() is not None:
            raise RuntimeError("Service exited before readiness")
        try:
            with http.open(url, timeout=0.5) as response:
                if response.status == 200:
                    return
        except (urllib.error.URLError, TimeoutError, ConnectionError):
            pass
        if time.monotonic() > deadline:
            raise TimeoutError("Service readiness deadline")
        time.sleep(0.05)
