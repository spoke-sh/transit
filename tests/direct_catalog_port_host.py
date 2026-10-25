#!/usr/bin/env python3
"""Fixture: retain real handshakes, then inject selected catalog reply faults."""
import json
import os
from pathlib import Path
import select
import subprocess
import sys
import time

root = Path(__file__).resolve().parent
child = subprocess.Popen([str(root / 'native-host'), sys.argv[1]], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
(root / 'host-pid').write_text(str(os.getpid()))
def stop_native():
    if not child.stdin.closed: child.stdin.close()
    try: child.wait(timeout=2)
    except subprocess.TimeoutExpired:
        child.kill(); child.wait(timeout=2)
    child.stdout.close()
try:
    for line in sys.stdin:
        request = json.loads(line)
        if 'shutdown' in request:
            print(json.dumps({'status': 0, 'value': {'closed': True}}), flush=True)
            break
        if 'catalog' in request and request['catalog'] != {'catalog': {'capabilities': {}}}:
            mode = json.loads((root / 'mode.json').read_text())
            (root / 'entered').write_text('1')
            if mode == 'loss': break
            if mode == 'block':
                deadline = time.monotonic() + 10
                while not (root / 'release').exists():
                    if time.monotonic() >= deadline: raise TimeoutError('release was not supplied')
                    time.sleep(.01)
                mode = json.loads((root / 'reply.json').read_text())
            print(json.dumps(mode), flush=True)
        else:
            child.stdin.write(line); child.stdin.flush()
            if not select.select([child.stdout], [], [], 10)[0]: raise TimeoutError('native handshake did not complete')
            response = child.stdout.readline()
            if not response: raise RuntimeError('native handshake exited')
            # Faults can kill the wrapper without finally executing. Complete
            # and join its handshake helper before admitting faulted calls.
            if request.get('catalog') == {'catalog': {'capabilities': {}}}: stop_native()
            print(response, end='', flush=True)
finally:
    stop_native()
