"""Install the public Node Station packages outside the checkout."""
from runner.paths import ROOT
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from sdk.sdk_station_runner import Consumer, run as schedule


def run(node, cli, library, artifacts, http_worker=None, *, execute=None):
    if execute is None and http_worker is None:
        raise ValueError("The full Station SDK schedule requires the HTTP worker binary")
    root = ROOT
    packages = Path(artifacts).resolve()
    def install(target):
        names = ('client', 'native-client', 'station', 'native-station', 'sdk-examples')
        dependencies = {f'@transit/{name}': 'file:' + str(packages / f'transit-{name}-0.0.1.tgz') for name in names}
        manifest = {'private': True, 'type': 'module', 'packageManager': json.loads((root / 'package.json').read_bytes())['packageManager'],
            'dependencies': dependencies, 'pnpm': {'overrides': dict(dependencies)}}
        environment = {key: value for key, value in os.environ.items() if key not in ('NODE_PATH', 'TRANSIT_HOST', 'TRANSIT_LIBRARY_DIR')}
        def package_install(*, update_lock=False):
            (target / 'package.json').write_text(json.dumps(manifest))
            installed = subprocess.run(['vp', 'env', 'exec', '--package-manager', manifest['packageManager'],
                'pnpm', 'install', '--prefer-offline', '--ignore-scripts',
                *(['--no-frozen-lockfile'] if update_lock else [])], cwd=target, env=environment, capture_output=True, text=True)
            codes = sorted(set(re.findall(r'ERR_PNPM_[A-Z0-9_]+', installed.stdout + installed.stderr)))
            assert installed.returncode == 0, f'Node dependency installation failed with exit {installed.returncode}; codes: {codes}'
        package_install()
        script = target / 'consumer.mjs'
        shutil.copyfile(root / 'tests/sdk/consumers/node/node_station_sdk.mjs', script)
        def command(mode, config):
            if mode == 'arrow':
                manifest['dependencies']['apache-arrow'] = '21.2.0'
                # The earlier codec proof requires Arrow to be absent. Update
                # only this disposable consumer's generated lock after adding
                # the adapter; CI otherwise freezes the now-outdated lock.
                package_install(update_lock=True)
            return ['node', script, mode, config]
        return Consumer(environment, command,
            lambda config, role: [target / 'node_modules/.bin/transit-node-counter', config, role, '--commits', '1'],
            'dropped-operation')
    (execute or schedule)(node, cli, library, install, 'Node')
    if execute is None:
        from sdk.sdk_http_runner import run as http_schedule
        http_schedule(node, cli, library, http_worker, install, 'Node', public_release=True, public_followup=True)


if __name__ == '__main__': run(*sys.argv[1:])
