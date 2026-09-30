"""Install catalog SDK packages in isolated consumer environments."""
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tarfile
import tomllib
from sdk_unified import Consumer, CConsumer

ROOT = Path(__file__).resolve().parents[1]


def install(root, languages):
    root.mkdir()
    factories = []
    for language in languages:
        if language in ('c', 'cpp'):
            factories.append(install_c(root / language, language))
            continue
        if language == 'node':
            factories.append(install_node(root / language))
            continue
        if language == 'rust':
            factories.append(install_rust(root / language))
            continue
        if language == 'ruby':
            factories.append(install_ruby(root / language))
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


def install_rust(target):
    target.mkdir()
    artifacts = {}
    names = ('transit-client', 'transit-native-client', 'transit-station-sdk', 'transit-native-station')
    for name in names:
        filename = f'{name}-0.2.0.crate'
        path = target / filename
        shutil.copy2(ROOT / '.cache/bindings/rust' / filename, path)
        artifacts[filename] = hashlib.sha256(path.read_bytes()).hexdigest()
        with tarfile.open(path) as archive: archive.extractall(target / 'vendor', filter='data')
    (target / 'artifacts.json').write_text(json.dumps(artifacts))
    (target / 'src').mkdir()
    shutil.copy2(ROOT / 'tests/rust_catalog_sdk.rs', target / 'src/main.rs')
    manifest = '[package]\nname = "transit-catalog-proof"\nversion = "0.1.0"\nedition = "2024"\n[dependencies]\ntransit-client = "=0.2.0"\ntransit-station-sdk = "=0.2.0"\nserde_json = { version = "=1.0.145", features = ["arbitrary_precision"] }\n[patch.crates-io]\n'
    manifest += ''.join(f'{name} = {{ path = "vendor/{name}-0.2.0" }}\n' for name in names)
    (target / 'Cargo.toml').write_text(manifest)
    lock = target / 'vendor/transit-station-sdk-0.2.0/Cargo.lock'
    shutil.copy2(lock, target / 'Cargo.lock')
    environment = {k:v for k,v in os.environ.items() if k not in ('TRANSIT_LIBRARY_DIR', 'LD_LIBRARY_PATH', 'LIBRARY_PATH')}
    subprocess.run(['cargo', 'test', '--offline', '-p', 'transit-station-sdk', '--lib'], cwd=target, env=environment, check=True)
    def registry(path):
        return {(p['name'], p['version'], p['checksum']) for p in tomllib.loads(path.read_text())['package'] if 'source' in p}
    selected = registry(target / 'Cargo.lock')
    assert selected and selected <= registry(lock)
    assert not any(name.startswith('arrow-') for name, _, _ in selected)
    subprocess.run(['cargo', 'build', '--locked', '--offline'], cwd=target, env=environment, check=True)
    executable = target / 'consumer'
    shutil.copy2(target / 'target/debug/transit-catalog-proof', executable)
    (target / 'src/main.rs').write_text('fn overlap(client: &mut transit_station_sdk::catalog::Client) { let a = &mut *client; let b = &mut *client; a.describe().unwrap(); b.describe().unwrap(); } fn main() {}')
    rejected = subprocess.run(['cargo', 'check', '--locked', '--offline'], cwd=target, env=environment, capture_output=True, text=True)
    assert rejected.returncode and 'cannot borrow `*client` as mutable more than once' in rejected.stderr
    (target / 'src/main.rs').write_text('fn reused(client: transit_station_sdk::catalog::Client) { client.close().unwrap(); client.close().unwrap(); } fn main() {}')
    rejected = subprocess.run(['cargo', 'check', '--locked', '--offline'], cwd=target, env=environment, capture_output=True, text=True)
    assert rejected.returncode and 'use of moved value: `client`' in rejected.stderr
    shutil.rmtree(target / 'vendor'); shutil.rmtree(target / 'target'); shutil.rmtree(target / 'src')
    def create(url, connection, state):
        config = target / 'client.json'
        config.write_text(json.dumps(dict(url=url, connection=connection, seed_file=str(state / 'caller.seed'))))
        return Consumer([str(executable), str(config)], environment, target)
    return 'rust', create


def install_ruby(target):
    target.mkdir()
    default = subprocess.check_output(['ruby', '-rrubygems', '-e', 'puts Gem.default_dir'], text=True).strip()
    environment = {k: v for k, v in os.environ.items() if k not in ('RUBYLIB', 'RUBYOPT', 'GEM_HOME', 'GEM_PATH', 'TRANSIT_HOST', 'TRANSIT_LIBRARY_DIR')}
    environment.update(GEM_HOME=str(target / 'gems'), GEM_PATH=f'{target / "gems"}:{default}')
    files = []
    artifacts = {}
    for name in ('transit-native-client-0.2.0-x86_64-linux.gem', 'transit-client-0.2.0.gem',
                 'transit-native-station-0.2.0-x86_64-linux.gem', 'transit-station-0.2.0.gem'):
        path = target / name
        shutil.copy2(ROOT / '.cache/bindings/ruby' / name, path)
        artifacts[name] = hashlib.sha256(path.read_bytes()).hexdigest()
        files.append(path)
    (target / 'artifacts.json').write_text(json.dumps(artifacts))
    subprocess.run(['gem', 'install', '--local', '--no-document', '--ignore-dependencies', *files], env=environment, cwd=target, check=True, stdout=subprocess.DEVNULL)
    script = target / 'consumer.rb'
    values = target / 'values.rb'
    shutil.copy2(ROOT / 'tests/ruby_catalog_sdk.rb', script)
    shutil.copy2(ROOT / 'tests/ruby_catalog_values.rb', values)
    subprocess.run(['ruby', str(values)], env=environment, cwd=target, check=True)
    def create(url, connection, state):
        config = target / 'client.json'
        config.write_text(json.dumps(dict(url=url, connection=connection, seed_file=str(state / 'caller.seed'))))
        return Consumer(['ruby', str(script), str(config)], environment, target)
    return 'ruby', create


class CatalogCConsumer(CConsumer):
    def send(self, action):
        name, value = next(iter(action.items()))
        def scope(v): return f"{v['realm']} {v['resource']} {v['catalog']}"
        def request(v):
            names = [v['name'], *v['schema']['names']]
            assert all(name.isascii() and name.isidentifier() and len(name) <= 16 for name in names)
            return f"{scope(v['scope'])} {v['operation']} {v['object']} {v['table']} {' '.join(names)} {v['schema']['value_type']}"
        if name == 'compile': command = f"compile {value['sql'].encode().hex()} {value['operation']} {value['object']} {value['table']}"
        elif name == 'prepare_initialize': command = f"initialize {scope(value['scope'])} {value['owner']} {value['administrator']}"
        elif name == 'prepare_create': command = 'create ' + request(value)
        elif name == 'prepare_policy':
            v = value['policy']; command = f"policy {scope(v['scope'])} {v['principal']} {v['revision']} {int(v['inspect'])} {int(v['create'])} {value['expected_revision']}"
        elif name == 'submit': command = 'submit ' + value.encode().hex()
        elif name in ('observe', 'input_disposition'): command = f"{name} {value['prepared'].encode().hex()} {value['input']}"
        elif name == 'status': command = 'status ' + request(value)
        else:
            assert name in ('capabilities', 'describe', 'close')
            command = name
        self.child.stdin.write(command + '\n'); self.child.stdin.flush()


def install_c(target, language):
    target.mkdir()
    prefix = target / 'installed'
    artifacts = {}
    for source in sorted((ROOT / '.cache/bindings/c').glob('*.tar.gz')):
        if source.name.startswith('transit-sdk-examples-'): continue
        artifact = target / source.name
        shutil.copy2(source, artifact)
        artifacts[source.name] = hashlib.sha256(artifact.read_bytes()).hexdigest()
        with tarfile.open(artifact) as archive: archive.extractall(prefix, filter='data')
    assert len(artifacts) == 6
    (target / 'artifacts.json').write_text(json.dumps(artifacts))
    environment = {k:v for k,v in os.environ.items() if k not in ('TRANSIT_LIBRARY_DIR', 'LD_LIBRARY_PATH', 'LIBRARY_PATH', 'CPATH', 'CPLUS_INCLUDE_PATH', 'C_INCLUDE_PATH')}
    environment['PKG_CONFIG_PATH'] = str(prefix / 'lib/pkgconfig')
    flags = shlex.split(subprocess.check_output(['pkg-config', '--cflags', '--libs', 'transit-station-c' if language == 'c' else 'transit-station-cpp'], text=True, env=environment))
    source = target / ('c_catalog_sdk.c' if language == 'c' else 'cpp_catalog_sdk.cpp')
    shutil.copy2(ROOT / 'tests' / source.name, source)
    shutil.copy2(ROOT / 'tests/catalog_sdk_io.h', target / 'catalog_sdk_io.h')
    executable = target / 'consumer'
    subprocess.run(['zig', 'cc' if language == 'c' else 'c++', '-std=c11' if language == 'c' else '-std=c++17', '-Wall', '-Wextra', '-Werror', str(source), *flags, '-lpthread', '-o', str(executable)], cwd=target, env=environment, check=True)
    if language == 'cpp':
        for name in ('Client', 'Compiled', 'Prepared'):
            source.write_text(f'#include <transit/catalog.hpp>\nvoid copy(transit::sdk::station::catalog::{name} &value) {{ auto other = value; }}')
            rejected = subprocess.run(['zig', 'c++', '-std=c++17', '-fsyntax-only', str(source), f'-I{prefix / "include"}'], cwd=target, env=environment, capture_output=True, text=True)
            assert rejected.returncode and 'deleted' in rejected.stderr
    source.unlink(); (target / 'catalog_sdk_io.h').unlink()
    def create(url, connection, state):
        s = connection['scope']
        arguments = [str(executable), url, str(state / 'caller.seed'), str(s['realm']), str(connection['principal']), str(connection['owner']), str(s['resource']), str(s['catalog'])]
        return CatalogCConsumer(arguments, environment, target)
    return language, create
