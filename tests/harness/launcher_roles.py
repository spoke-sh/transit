"""Signal a server-owned role in the fixture's existing process namespace."""
import json
import os
from pathlib import Path
import signal
import subprocess
import time
import uuid

from runner.paths import ROOT
from harness.processes import children, command


def courier_pid(launcher):
    manager = next(row['pid'] for row in launcher.services() if row['name'] == 'node')
    roles = [pid for pid in children(manager) if '/courier.json' in command(pid)]
    assert len(roles) == 1, (manager, roles)
    return roles[0]


def courier_signal(installation, launcher, signum):
    if installation.profile == 'local':
        pid = courier_pid(launcher)
        os.kill(pid, signum)
        return pid
    # The published image remains the product image. Use the already pinned
    # infrastructure image as a transient signal injector in its PID namespace;
    # it does not use installation files, network access or runtime credentials.
    pins = json.loads((ROOT / 'deploy/reference/versions.json').read_text())
    action = signal.Signals(signum).name.removeprefix('SIG')
    script = '''set -eu
found=0
for file in /proc/[0-9]*/cmdline; do
  pid=${file#/proc/}; pid=${pid%/cmdline}
  [ "$pid" = "$$" ] && continue
  [ "$(cat /proc/$pid/comm 2>/dev/null || true)" = transit ] || continue
  args=$(tr '\\000' ' ' < "$file")
  case "$args" in
    *"__transit_role_v1 query_host /data/installation/courier.json "*)
      kill -ACTION "$pid"; echo "$pid"; found=$((found+1));;
  esac
done
[ "$found" = 1 ]
'''.replace('ACTION', action)
    if installation.profile == 'compose':
        container = launcher.docker('ps', '-q', 'node', capture=True).strip()
        assert container
        result = subprocess.check_output(['docker', 'run', '--rm', '--network=none',
            '--pid=container:' + container, f'--user={os.getuid()}:{os.getgid()}', '--cap-drop=ALL',
            '--entrypoint=sh', pins['kind_node'], '-ec', script], text=True, timeout=30)
    else:
        pods = json.loads(launcher.kube('get', 'pods', '-l', 'app.kubernetes.io/component=node', '-o', 'json', capture=True))['items']
        assert len(pods) == 1
        pod = pods[0]
        custom = installation.path / 'role-fault.json'
        custom.write_text(json.dumps({'securityContext': {'runAsUser': 65532, 'runAsGroup': 65532,
            'runAsNonRoot': True, 'allowPrivilegeEscalation': False, 'capabilities': {'drop': ['ALL']}}}))
        name = 'courier-fault-' + uuid.uuid4().hex[:12]
        deadline = time.monotonic() + 60
        launcher.kube('debug', pod['metadata']['name'], '--quiet', '--attach=false', '--container=' + name,
            '--target=' + pod['spec']['containers'][0]['name'], '--image=' + pins['kind_node'],
            '--profile=restricted', '--custom=' + str(custom), '--', 'sh', '-ec', script,
            capture=True, timeout=60)
        # A short-lived injector can exit before kubectl attaches, losing its
        # stdout despite successful signaling. Observe this exact container's
        # terminal status and retained log; never dispatch the signal again.
        while True:
            remaining = deadline - time.monotonic()
            assert remaining > 0, 'Courier signal injector did not complete'
            current = json.loads(launcher.kube('get', 'pod', pod['metadata']['name'], '-o', 'json', capture=True, timeout=remaining))
            status = next((item for item in current['status'].get('ephemeralContainerStatuses', [])
                           if item['name'] == name), None)
            terminal = status['state'].get('terminated') if status else None
            if terminal is not None:
                result = launcher.kube('logs', pod['metadata']['name'], '-c', name, capture=True, timeout=max(.1, deadline-time.monotonic()))
                assert terminal['exitCode'] == 0, (terminal, result)
                break
            assert time.monotonic() < deadline, 'Courier signal injector did not complete'
            time.sleep(.1)
    values = [int(line) for line in result.splitlines() if line.isdigit()]
    assert len(values) == 1, result
    return values[0]
