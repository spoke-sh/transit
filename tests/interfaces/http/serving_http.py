"""Independent sockets exercise the real neutral HTTP listener, not Transit admission."""
import concurrent.futures
import http.client
import json
import socket
import subprocess
import sys
import time

with socket.socket() as port_socket:
    port_socket.bind(('127.0.0.1', 0))
    port = port_socket.getsockname()[1]
process = subprocess.Popen([sys.argv[1], str(port), '10000'], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
opened = []


def request(path='/health', body=None):
    connection = http.client.HTTPConnection('127.0.0.1', port, timeout=2)
    try:
        connection.request('GET' if body is None else 'POST', path, body=body)
        result = connection.getresponse()
        return result.status, result.read()
    finally:
        connection.close()


def raw(data):
    with socket.create_connection(('127.0.0.1', port), timeout=2) as peer:
        peer.sendall(data)
        result = bytearray()
        while True:
            try:
                part = peer.recv(4096)
            except ConnectionResetError:
                break
            if not part:
                break
            result.extend(part)
        return bytes(result)


try:
    until = time.monotonic()+20
    while True:
        try:
            assert request()[0] == 200
            break
        except OSError:
            assert process.poll() is None and time.monotonic() < until
            time.sleep(.02)
    # Bounded reuse keeps one socket; the final response advertises closure.
    persistent = http.client.HTTPConnection('127.0.0.1', port, timeout=2)
    first_socket = None
    for index in range(3):
        persistent.request('GET', '/keep')
        if first_socket is None:
            first_socket = persistent.sock
        assert persistent.sock is first_socket
        response = persistent.getresponse()
        assert response.status == 200 and response.read() == b'{}'
        assert (response.getheader('Connection') == 'close') == (index == 2)
        assert request()[0] == 200, 'an idle reusable socket blocked health'
    persistent.close()
    assert request('/echo', b'Unicode: \xe2\x98\x83')[1] == b'Unicode: \xe2\x98\x83'
    chunked = raw(b'POST /echo HTTP/1.1\r\nHost: test\r\nTransfer-Encoding: chunked\r\n\r\n3\r\nabc\r\n0\r\n\r\n')
    assert b'200 OK' in chunked and chunked.endswith(b'abc'), chunked
    for headers in (
        b'Host: a\r\nHost: b\r\n',
        b'Host: a\r\nContent-Length: 1\r\nContent-Length: 2\r\n',
        b'Host: a\r\nContent-Length: 0\r\nTransfer-Encoding: chunked\r\n',
        b'Host: a\r\nContent-Encoding: gzip\r\n',
        b'Host: a\r\nAuthorization: a\r\nauthorization: b\r\n',
        b'',
    ):
        result = raw(b'POST /echo HTTP/1.1\r\n'+headers+b'\r\n')
        assert b'200 OK' not in result, result
    # Occupy both data slots with incomplete bodies; reserved health still runs.
    for _ in range(2):
        peer = socket.create_connection(('127.0.0.1', port), timeout=2)
        peer.sendall(b'POST /echo HTTP/1.1\r\nHost: test\r\nContent-Length: 10\r\n\r\nx')
        opened.append(peer)
    time.sleep(.08)
    started = time.monotonic()
    assert request()[0] == 200
    assert time.monotonic()-started < .5
    assert request('/echo', b'x')[0] == 503
    time.sleep(.8)
    assert request('/echo', b'after-deadline') == (200, b'after-deadline')
    assert request('/echo', b'x'*64)[0] == 413
    # A peer that stops reading must lose only its finite response task. Bound
    # the receive window so the 8 MiB response cannot fit in socket buffers.
    for _ in range(2):
        peer = socket.socket()
        peer.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 1024)
        peer.settimeout(2)
        peer.connect(('127.0.0.1', port))
        peer.sendall(b'GET /large HTTP/1.1\r\nHost: test\r\n\r\n')
        opened.append(peer)
    time.sleep(.08)
    assert request()[0] == 200
    assert request('/echo', b'x')[0] == 503
    time.sleep(.8)
    assert request('/echo', b'after-slow-readers') == (200, b'after-slow-readers')
    # Header deadlines release partial requests independently of body deadlines.
    peer = socket.create_connection(('127.0.0.1', port), timeout=2)
    peer.sendall(b'GET /health HTTP/1.1\r\nHost:')
    opened.append(peer)
    time.sleep(.3)
    assert peer.recv(1) == b''
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        results = list(pool.map(lambda _: request('/echo', b'bounded'), range(12)))
    assert all(status in (200, 503) for status, _ in results)
    # Parent deadline cancels and joins accepted work before stack/pool teardown.
    time.sleep(max(0, 9.7-(time.monotonic()-started)))
    peer = socket.create_connection(('127.0.0.1', port), timeout=2)
    peer.sendall(b'GET /slow HTTP/1.1\r\nHost: test\r\n\r\n')
    opened.append(peer)
    out, err = process.communicate(timeout=10)
    assert process.returncode == 0, err
    assert json.loads(out)['joined']
    print('Shared HTTP: framing, chunked bodies, slow-reader isolation, control reserve, header/request deadlines and joined shutdown passed.')
finally:
    for peer in opened:
        peer.close()
    if process.poll() is None:
        process.kill()
        process.wait(timeout=10)
