"""Run the finite Zig caller, including process restart with exact frozen intent."""
import json
import subprocess
import time


def check(binary, root, client, fault, kind):
    config = json.loads((root/'shell.json').read_text())
    # Hosts always use the fault proxy; shell.json uses it only when the shell
    # schedule was selected. The standalone example must cross the same fault.
    config['url'] = json.loads((root/'source.json').read_text())['url']
    config.pop('request_timeout_ms', None)
    config.update(namespace=8, sql='SELECT * FROM items LIMIT 33', recovery_file=str(root/'example-recovery.json'))
    path = root/'example.json'
    path.write_text(json.dumps(config)); path.chmod(0o600)
    fault['lost'], fault['retry'] = None, False
    failed = subprocess.run([binary, str(path)], capture_output=True, timeout=120)
    assert failed.returncode and b'InvalidAuthorityResponse' in failed.stderr, failed.stderr
    frozen = json.loads((root/'example-recovery.json').read_text())
    assert frozen['pending'] is not None
    assert (root/'example-recovery.json').stat().st_mode & 0o777 == 0o600
    changed = config | {'sql': 'SELECT * FROM items LIMIT 1'}
    path.write_text(json.dumps(changed))
    rejected = subprocess.run([binary, str(path)], capture_output=True, timeout=30)
    assert rejected.returncode and b'RecoveryConfigurationChanged' in rejected.stderr
    assert json.loads((root/'example-recovery.json').read_text()) == frozen
    path.write_text(json.dumps(config))
    resumed = subprocess.run([binary, str(path)], capture_output=True, timeout=180)
    assert resumed.returncode == 0, resumed.stderr
    assert fault['retry'], 'recovered caller changed the signed pending command'
    assert json.loads(resumed.stdout)['status']['phase'] in ('admitted', 'complete')
    deadline = time.monotonic()+300
    while client.call({'status': '8'})['status']['phase'] != 'complete':
        assert time.monotonic() < deadline
        time.sleep(.1)
    config['mode'] = 'read'; path.write_text(json.dumps(config))
    result = subprocess.run([binary, str(path)], capture_output=True, timeout=120)
    assert result.returncode == 0, result.stderr
    pages = [json.loads(line) for line in result.stdout.splitlines()]
    assert sum(len(page['cells']) for page in pages) == (12 if kind == 'document' else 33)
    assert all(page['manifest']['basis']['cut']['kind'] == kind for page in pages)
    assert all(page['complete_coverage'] == (i+1 == len(pages)) for i, page in enumerate(pages))
    assert [page['ordinal'] for page in pages] == [str(i) for i in range(len(pages))]
    print(f'Unified {kind} example: private frozen intent, changed-plan rejection, exact process retry and complete bounded pages passed.', flush=True)
