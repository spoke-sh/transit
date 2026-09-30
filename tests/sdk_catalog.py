"""Install catalog SDK packages in isolated consumer environments."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from sdk_unified import Consumer

ROOT = Path(__file__).resolve().parents[1]


def install(root, languages):
    root.mkdir()
    factories = []
    for language in languages:
        if language == 'node':
            factories.append(install_node(root / language))
            continue
        if language != 'python': raise ValueError('Unsupported catalog SDK proof language')
        target = root / language
        target.mkdir()
        env = {k: v for k, v in os.environ.items() if k not in ('PYTHONPATH', 'PYTHONHOME', 'TRANSIT_LIBRARY_DIR')}
        wheels = target / 'wheels'
        wheels.mkdir()
        for path in (ROOT / '.cache/bindings/wheels').glob('*.whl'):
            if path.name.split('-')[0] in ('transit_client', 'transit_native_client', 'transit_station', 'transit_native_station'):
                shutil.copy2(path, wheels / path.name)
        artifacts = {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in wheels.glob('*.whl')}
        assert len(artifacts) == 4
        (target / 'artifacts.json').write_text(json.dumps(artifacts))
        venv = target / 'venv'
        subprocess.run([sys.executable, '-m', 'venv', '--without-pip', str(venv)], check=True, env=env)
        python = str(venv / 'bin/python')
        subprocess.run([sys.executable, '-m', 'pip', '--python', python, 'install', '--no-index', '--find-links', str(wheels), 'transit-station==0.2.0'], check=True, env=env, stdout=subprocess.DEVNULL)
        script = target / 'consumer.py'
        shutil.copy2(ROOT / 'tests/python_catalog_sdk.py', script)
        values = target / 'values.py'
        shutil.copy2(ROOT / 'tests/python_catalog_values.py', values)
        subprocess.run([python, '-B', str(values)], check=True, env=env, cwd=target)
        for mode in ('sync', 'async'):
            def create(url, connection, state, mode=mode, python=python, script=script, target=target, env=env):
                config = target / f'{mode}.json'
                config.write_text(json.dumps(dict(url=url, connection=connection, seed_file=str(state / 'caller.seed'))))
                return Consumer([python, '-B', str(script), mode, str(config)], env, target)
            factories.append((f'python-{mode}', create))
    return factories


def install_node(target):
    target.mkdir()
    packages = target / 'packages'
    packages.mkdir()
    dependencies = {}
    artifacts = {}
    for name in ('client', 'native-client', 'station', 'native-station'):
        filename = f'transit-{name}-0.2.0.tgz'
        path = packages / filename
        shutil.copy2(ROOT / '.cache/bindings/node' / filename, path)
        dependencies[f'@transit/{name}'] = 'file:' + str(path)
        artifacts[filename] = hashlib.sha256(path.read_bytes()).hexdigest()
    (target / 'artifacts.json').write_text(json.dumps(artifacts))
    manifest = dict(private=True, type='module', packageManager=json.loads((ROOT / 'package.json').read_text())['packageManager'], dependencies=dependencies, pnpm=dict(overrides=dependencies))
    (target / 'package.json').write_text(json.dumps(manifest))
    environment = {k: v for k, v in os.environ.items() if k not in ('NODE_PATH', 'TRANSIT_HOST', 'TRANSIT_LIBRARY_DIR')}
    subprocess.run(['vp', 'env', 'exec', '--package-manager', manifest['packageManager'], 'pnpm', 'install', '--prefer-offline', '--ignore-scripts'], cwd=target, env=environment, check=True, stdout=subprocess.DEVNULL)
    script = target / 'consumer.mjs'
    shutil.copy2(ROOT / 'tests/node_catalog_sdk.mjs', script)
    def create(url, connection, state):
        config = target / 'client.json'
        config.write_text(json.dumps(dict(url=url, connection=connection, seed_file=str(state / 'caller.seed'))))
        return Consumer(['node', str(script), str(config)], environment, target)
    return 'node', create
