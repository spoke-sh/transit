"""Install built Node raw artifacts outside the checkout, with no Station package."""

from sdk.artifact_versions import package_text
from runner.paths import ROOT
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from sdk.sdk_raw_client import run as schedule


def run(node, cli, library, artifacts, evidence=None):
    root = ROOT
    packages = Path(artifacts).resolve()
    def install(target):
        manifest = {'private': True, 'type': 'module', 'packageManager': json.loads((root / 'package.json').read_bytes())['packageManager'],
            'dependencies': {'@transit/client': 'file:' + str(packages / package_text('transit-client-0.0.1.tgz', 'node')),
                             '@transit/native-client': 'file:' + str(packages / package_text('transit-native-client-0.0.1.tgz', 'node'))}}
        manifest['pnpm'] = {'overrides': dict(manifest['dependencies'])}
        (target / 'package.json').write_text(json.dumps(manifest))
        environment = {key: value for key, value in os.environ.items() if key not in ('NODE_PATH', 'TRANSIT_HOST', 'TRANSIT_LIBRARY_DIR')}
        installed = subprocess.run(['vp', 'env', 'exec', '--package-manager', manifest['packageManager'],
            'pnpm', 'install', '--prefer-offline', '--ignore-scripts'], cwd=target, env=environment, capture_output=True, text=True)
        assert installed.returncode == 0, installed.stdout + installed.stderr
        script = target / 'consumer.mjs'
        shutil.copyfile(root / 'tests/sdk/consumers/node/node_client_sdk.mjs', script)
        def invoke(mode, config):
            return subprocess.check_output(['node', script, mode, config], cwd=target, env=environment, timeout=30)
        return invoke
    schedule(node, cli, library, install, 'Node', evidence)


if __name__ == '__main__': run(*sys.argv[1:])
