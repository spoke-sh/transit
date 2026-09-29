"""Ctrl-C against real query workers, signed requests, disk storage and a PTY."""
import json
import os
import select
import signal
import subprocess
import threading
import time

from console_terminal import Terminal


def payload(message):
    request = message.get('request', {})
    command = request.get('command', {})
    if request.get('principal') == 1234 and 'send' in command:
        return bytes.fromhex(command['send']['value'])[13:]
    return b''


class Gate:
    def __init__(self):
        self.reached = threading.Event()
        self.release = threading.Event()

    def pause(self):
        if not self.reached.is_set():
            self.reached.set()
            assert self.release.wait(30), 'interrupt fixture did not release response'


def check(binary, path, root, kind, invoke, fault):
    terminal = Terminal(binary, path)
    recovery = root/'console-recovery.json'
    gates = []

    def gate():
        value = Gate()
        gates.append(value)
        return value

    def record():
        return json.loads(recovery.read_text())

    def idle(message):
        terminal.expect(message, timeout=60)
        terminal.expect('\rtransit> ', timeout=10)
        assert terminal.process.poll() is None
        assert not terminal.buffer
        assert not select.select([terminal.process.stdout], [], [], .05)[0], 'unexpected result output'

    def next_query():
        fault.pop('console_hook', None)
        terminal.send('SELECT COUNT(*) FROM items;\r')
        page = terminal.read(timeout=420)
        assert page['complete_coverage']
        assert page['cells'][0][0]['value']['uint64'] in ('12', '41')
        terminal.expect('\rtransit> ')

    try:
        # No upload exists yet: Ctrl-C must not cancel the previous saved query.
        before = recovery.read_bytes()
        sends = fault['console_sends']
        fault['console_waiting'].clear(); fault['console_delay'].set()
        terminal.send('SELECT COUNT(*) FROM items;\r')
        assert fault['console_waiting'].wait(10)
        terminal.send('\x03')
        idle('Query cancelled before submission.')
        fault['console_delay'].clear()
        assert fault['console_sends'] == sends and recovery.read_bytes() == before
        terminal.send('SELECT unfinished')
        terminal.send('\x03')
        terminal.expect('\rtransit> ')

        # Lose an accepted upload reply while Ctrl-C is pending. Cancellation
        # must replay that exact signature, not upload the rest of the bundle.
        upload, cancel = gate(), gate()
        signed, commands = [], []

        def interrupted_upload(route, message, data):
            command = payload(message)
            if command:
                commands.append(command[:4])
            if command.startswith(b'UQP2'):
                signed.append(message)
                if not upload.reached.is_set():
                    upload.pause()
                    return b'{"position":0}'
            if command.startswith(b'UQK2'):
                cancel.pause()
            return data

        fault['console_hook'] = interrupted_upload
        terminal.send('SELECT * FROM items; SELECT COUNT(*) FROM items;\r')
        assert upload.reached.wait(60)
        query = record()['namespace']
        terminal.send('\x03')
        upload.release.set()
        assert cancel.reached.wait(30)
        for _ in range(3):
            terminal.process.send_signal(signal.SIGINT)
            time.sleep(.02)
        cancel.release.set()
        idle(f'Query {query} cancelled.')
        assert len(signed) == 2 and signed[0] == signed[1], 'frozen upload identity changed'
        assert commands == [b'UQB2', b'UQP2', b'UQP2', b'UQK2'], commands
        assert record()['namespace'] is None and record()['pending'] is None
        status = invoke('status', str(query), direct=True)
        assert status['phase'] == 'cancelled' and status['collected']
        next_query()

        # Stop a source after its first staged segment. Releasing it when the
        # cancellation commits proves the source closes instead of continuing
        # to produce a complete result behind the console's prompt.
        source = gate()

        def interrupted_execution(route, message, data):
            request = message.get('request', {})
            command = request.get('command', {})
            turn = command.get('turn', command.get('turn_with_versions', {}).get('turn', {}))
            if request.get('principal') == 65536 and any(
                    item and bytes.fromhex(item['key']).startswith(b'\x00Us')
                    for item in turn.get('mutations', [])):
                source.pause()
            if payload(message).startswith(b'UQK2'):
                source.release.set()
            return data

        fault['console_hook'] = interrupted_execution
        terminal.send('SELECT * FROM items;\r')
        assert source.reached.wait(120)
        query = record()['namespace']
        terminal.send('\x03')
        idle(f'Query {query} cancelled.')
        until = time.monotonic()+60
        while True:
            snapshot = invoke('job', str(query), direct=True)
            job = snapshot['job']
            if job and job['phase'] in ('cancelled', 'denied'):
                break
            assert time.monotonic() < until, snapshot
            time.sleep(.05)
        assert invoke('status', str(query), direct=True)['phase'] == 'cancelled'
        next_query()

        # The engine has already completed, but only one result page has been
        # disclosed. Pause the second segment read deterministically.
        page_gate = gate()

        def interrupted_results(route, message, data):
            query = message.get('query', {})
            entry = query.get('kind', {}).get('entries', {})
            key = bytes.fromhex(entry.get('key') or '')
            if query.get('principal') == 1234 and key.startswith(b'\x00Us') and int.from_bytes(key[11:19], 'big') == 1:
                page_gate.pause()
            return data

        fault['console_hook'] = interrupted_results
        terminal.send('SELECT * FROM items;\r')
        prefix = terminal.read(timeout=420)
        assert not prefix['complete_coverage']
        assert page_gate.reached.wait(30)
        query = record()['namespace']
        sends = fault['console_sends']
        terminal.send('\x03')
        page_gate.release.set()
        idle(f'Query {query} already completed; result display interrupted.')
        assert fault['console_sends'] == sends, 'completed work was spuriously cancelled'
        assert invoke('status', str(query), direct=True)['phase'] == 'complete'
        next_query()

        # The same partial-display rule applies to .resume and the default table
        # format. Do not print a success row-total footer for a cancelled prefix.
        terminal.send('.mode table\r')
        terminal.expect('\rtransit> ')
        page_gate = gate()
        fault['console_hook'] = interrupted_results
        terminal.send(f'.resume {query}\r')
        first_line = terminal.read(json_line=False, timeout=120)
        assert first_line.startswith('┌'.encode()), first_line
        assert page_gate.reached.wait(30)
        terminal.send('\x03')
        page_gate.release.set()
        terminal.expect(f'Query {query} already completed; result display interrupted.')
        terminal.expect('\rtransit> ')
        displayed = first_line+b'\n'+terminal.buffer
        terminal.buffer = b''
        while select.select([terminal.process.stdout], [], [], .05)[0]:
            displayed += os.read(terminal.process.stdout.fileno(), 65536)
        assert b' rows\n' not in displayed and b' row\n' not in displayed, displayed
        terminal.send('.mode json\r')
        terminal.expect('\rtransit> ')
        next_query()

        # A lost cancellation acknowledgement remains uncertain locally even
        # when the requester later closes. Preserve its exact signed operation.
        upload = gate()
        cancellations = []

        def lost_cancellation(route, message, data):
            command = payload(message)
            if command.startswith(b'UQP2'):
                upload.pause()
            if command.startswith(b'UQK2'):
                cancellations.append(message)
                if len(cancellations) == 1:
                    return b'{"position":0}'
            return data

        fault['console_hook'] = lost_cancellation
        terminal.send('SELECT * FROM items;\r')
        assert upload.reached.wait(60)
        query = record()['namespace']
        terminal.send('\x03')
        upload.release.set()
        idle('query cancellation could not be confirmed')
        assert f'Query {query} cancelled.'.encode() not in terminal.screen
        saved = record()
        assert saved['namespace'] == query and saved['pending']['signed'] == cancellations[0]
        terminal.send('SELECT COUNT(*) FROM items;\r')
        idle('UnresolvedSubmission')
        assert record() == saved, 'new SQL replaced unresolved cancellation'
        result = terminal.call('.cancel')
        assert result['query'] == query and result['phase'] == 'cancelled'
        assert cancellations[0] == cancellations[1], 'cancellation retry changed signed identity'
        next_query()

        # Completion already printed remains complete; Ctrl-C now clears input.
        saved = recovery.read_bytes()
        sends = fault['console_sends']
        terminal.send('\x03')
        terminal.expect('\rtransit> ')
        assert recovery.read_bytes() == saved and fault['console_sends'] == sends
        next_query()
        terminal.close()
        terminal = None

        # Noninteractive invocation uses the same cancellation path and exits
        # 130; diagnostics must not leak into machine stdout.
        fault['console_waiting'].clear(); fault['console_delay'].set()
        batch = subprocess.Popen([binary, 'console', '--no-rc', '--config', str(path),
                                  '-c', 'SELECT COUNT(*) FROM items'],
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            assert fault['console_waiting'].wait(10)
            batch.send_signal(signal.SIGINT)
            out, err = batch.communicate(timeout=30)
            assert batch.returncode == 130 and not out, (batch.returncode, out, err)
            assert b'Query cancelled before submission.' in err and b'not cancelled' not in err, err
        finally:
            if batch.poll() is None:
                batch.kill(); batch.communicate(timeout=10)
        print(f'Transit console {kind}: Ctrl-C before submission, exact uncertain-upload/cancellation retry, repeated interrupts, discarded pasted tail, active source closure, JSON/table streamed-prefix/completion races, prompt reuse and batch exit 130 passed.', flush=True)
    finally:
        for value in gates:
            value.release.set()
        fault.pop('console_hook', None)
        fault['console_delay'].clear()
        if terminal is not None:
            terminal.close()
