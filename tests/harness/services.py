"""Loopback port discovery and bounded HTTP process readiness."""
import socket
import time
import urllib.error


def free_port():
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        return listener.getsockname()[1]


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

