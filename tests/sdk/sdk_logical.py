"""Install wheels/tarballs outside the checkout and exercise only public APIs."""
from runner.paths import ROOT
import json
import os
from pathlib import Path
import select
import shutil
import subprocess
import sys
import tempfile
from fuze_logical_codec import check



class Consumer:
    def __init__(self, command, root, env):
        self.child = subprocess.Popen(command, cwd=root, env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)

    def call(self, action, *, invalid=False):
        self.child.stdin.write(json.dumps(action) + '\n'); self.child.stdin.flush()
        assert select.select([self.child.stdout], [], [], 60)[0], 'installed logical consumer timed out'
        output = json.loads(self.child.stdout.readline())
        assert bool(output['status']) == invalid, output
        return output['value']

    def close(self):
        try:
            self.child.stdin.write('{"close":{}}\n'); self.child.stdin.flush(); self.child.stdin.close()
            assert select.select([self.child.stdout], [], [], 30)[0]
            assert json.loads(self.child.stdout.readline()) == {'closed': True}
            assert self.child.wait(timeout=30) == 0
        finally:
            if self.child.poll() is None: self.child.kill(); self.child.wait(timeout=10)
            self.child.stdin.close(); self.child.stdout.close()


def install(root, language):
    env = {k: v for k, v in os.environ.items() if k not in ('PYTHONPATH', 'PYTHONHOME', 'NODE_PATH', 'TRANSIT_HOST', 'TRANSIT_LIBRARY_DIR')}
    if language == 'python':
        subprocess.run([sys.executable, '-m', 'venv', '--without-pip', root / 'venv'], env=env, check=True)
        python = root / 'venv/bin/python'
        subprocess.run([sys.executable, '-m', 'pip', '--python', python, 'install', '--no-index', '--find-links', ROOT / '.cache/bindings/wheels', 'transit-station==0.2.0'], env=env, check=True, stdout=subprocess.DEVNULL)
        script = root / 'consumer.py'; shutil.copyfile(ROOT / 'tests/sdk/consumers/python/python_logical_sdk.py', script)
        return Consumer([python, '-B', script], root, env)
    if language == 'node':
        dependencies = {f'@transit/{name}': 'file:' + str(ROOT / '.cache/bindings/node' / f'transit-{name}-0.2.0.tgz') for name in ('client', 'native-client', 'station', 'native-station')}
        manager = json.loads((ROOT / 'package.json').read_text())['packageManager']
        (root / 'package.json').write_text(json.dumps(dict(private=True, type='module', packageManager=manager, dependencies=dependencies, pnpm=dict(overrides=dependencies))))
        subprocess.run(['vp', 'env', 'exec', '--package-manager', manager, 'pnpm', 'install', '--prefer-offline', '--ignore-scripts'], cwd=root, env=env, check=True, stdout=subprocess.DEVNULL)
        script = root / 'consumer.mjs'; shutil.copyfile(ROOT / 'tests/sdk/consumers/node/node_logical_sdk.mjs', script)
        return Consumer(['node', script], root, env)
    raise ValueError(language)


if __name__ == '__main__':
    for language in sys.argv[1:]:
        with tempfile.TemporaryDirectory(prefix=f'transit-logical-{language}-', dir='/var/tmp') as directory:
            consumer = install(Path(directory), language)
            try: assert check(consumer, capabilities=False) == 111
            finally: consumer.close()
        print(f'Installed {language}: 111 logical fixtures, public owned values, exact codecs, hashes, casts, Arrow and released inputs passed.')
