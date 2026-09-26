"""Install the public Node Station packages outside the checkout."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from sdk_station_runner import Consumer, run as schedule


def run(node, cli, library, artifacts, *, execute=None):
    root = Path(__file__).resolve().parents[1]
    packages = Path(artifacts).resolve()
    def install(target):
        names = ('client', 'native-client', 'station', 'native-station', 'sdk-examples')
        dependencies = {f'@transit/{name}': 'file:' + str(packages / f'transit-{name}-0.2.0.tgz') for name in names}
        manifest = {'private': True, 'type': 'module', 'packageManager': json.loads((root / 'package.json').read_bytes())['packageManager'],
            'dependencies': dependencies, 'pnpm': {'overrides': dict(dependencies)}}
        environment = {key: value for key, value in os.environ.items() if key not in ('NODE_PATH', 'TRANSIT_HOST', 'TRANSIT_LIBRARY_DIR')}
        def package_install():
            (target / 'package.json').write_text(json.dumps(manifest))
            installed = subprocess.run(['vp', 'env', 'exec', '--package-manager', manifest['packageManager'],
                'pnpm', 'install', '--prefer-offline', '--ignore-scripts'], cwd=target, env=environment, capture_output=True, text=True)
            assert installed.returncode == 0, f'Node dependency installation failed with exit {installed.returncode}'
        package_install()
        script = target / 'consumer.mjs'
        shutil.copyfile(root / 'tests/node_station_sdk.mjs', script)
        def command(mode, config):
            if mode == 'arrow':
                manifest['dependencies']['apache-arrow'] = '21.2.0'
                package_install()
            return ['node', script, mode, config]
        return Consumer(environment, command,
            lambda config, role: [target / 'node_modules/.bin/transit-node-counter', config, role, '--commits', '1'],
            'dropped-operation')
    (execute or schedule)(node, cli, library, install, 'Node')


if __name__ == '__main__': run(*sys.argv[1:])
