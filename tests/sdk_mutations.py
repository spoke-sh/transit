"""Install public mutation SDK consumers outside the checkout for shared faults."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tomllib
from sdk_unified import Consumer

ROOT = Path(__file__).resolve().parents[1]


def install(root, languages):
    root.mkdir()
    factories = []
    for language in languages:
        if language == 'node':
            factories.append(install_node(root/'node'))
            continue
        if language == 'ruby':
            factories.append(install_ruby(root/'ruby'))
            continue
        if language == 'rust':
            factories.append(install_rust(root/'rust'))
            continue
        if language != 'python': raise ValueError('Unsupported mutation SDK proof language')
        target = root/language
        target.mkdir()
        environment = {k:v for k,v in os.environ.items() if k not in ('PYTHONPATH','PYTHONHOME','TRANSIT_LIBRARY_DIR')}
        venv = target/'venv'
        subprocess.run([sys.executable,'-m','venv','--without-pip',str(venv)],check=True,env=environment)
        python = str(venv/'bin/python')
        subprocess.run([sys.executable,'-m','pip','--python',python,'install','--no-index','--find-links',str(ROOT/'.cache/bindings/wheels'),'transit-station==0.2.0'],check=True,env=environment,stdout=subprocess.DEVNULL)
        script = target/'consumer.py'
        shutil.copy2(ROOT/'tests/python_mutation_sdk.py',script)
        for mode in ('sync','async'):
            def create(url,connection,state,mode=mode,python=python,script=script,target=target,environment=environment):
                config = target/f'{mode}.json'
                config.write_text(json.dumps(dict(url=url,connection=connection,seed_file=str(state/'caller.seed'))))
                return Consumer([python,'-B',str(script),mode,str(config)],environment,target)
            factories.append((f'python-{mode}',create))
    return factories


def install_node(target):
    target.mkdir()
    dependencies = {f'@transit/{name}': 'file:'+str(ROOT/'.cache/bindings/node'/f'transit-{name}-0.2.0.tgz')
        for name in ('client','native-client','station','native-station')}
    manifest = dict(private=True,type='module',packageManager=json.loads((ROOT/'package.json').read_text())['packageManager'],
        dependencies=dependencies,pnpm=dict(overrides=dependencies))
    (target/'package.json').write_text(json.dumps(manifest))
    environment = {k:v for k,v in os.environ.items() if k not in ('NODE_PATH','TRANSIT_HOST','TRANSIT_LIBRARY_DIR')}
    subprocess.run(['vp','env','exec','--package-manager',manifest['packageManager'],'pnpm','install','--prefer-offline','--ignore-scripts'],
        cwd=target,env=environment,check=True,stdout=subprocess.DEVNULL)
    script = target/'consumer.mjs'
    shutil.copy2(ROOT/'tests/node_mutation_sdk.mjs',script)
    def create(url,connection,state):
        config = target/'client.json'
        config.write_text(json.dumps(dict(url=url,connection=connection,seed_file=str(state/'caller.seed'))))
        return Consumer(['node',str(script),str(config)],environment,target)
    return 'node',create


def install_ruby(target):
    target.mkdir()
    default = subprocess.check_output(['ruby','-rrubygems','-e','puts Gem.default_dir'],text=True).strip()
    environment = {k:v for k,v in os.environ.items() if k not in ('RUBYLIB','RUBYOPT','GEM_HOME','GEM_PATH','TRANSIT_HOST','TRANSIT_LIBRARY_DIR')}
    environment.update(GEM_HOME=str(target/'gems'),GEM_PATH=f'{target / "gems"}:{default}')
    files = [ROOT/'.cache/bindings/ruby'/name for name in (
        'transit-native-client-0.2.0-x86_64-linux.gem','transit-client-0.2.0.gem',
        'transit-native-station-0.2.0-x86_64-linux.gem','transit-station-0.2.0.gem')]
    subprocess.run(['gem','install','--local','--no-document','--ignore-dependencies',*files],env=environment,cwd=target,check=True,stdout=subprocess.DEVNULL)
    script = target/'consumer.rb'
    shutil.copy2(ROOT/'tests/ruby_mutation_sdk.rb',script)
    def create(url,connection,state):
        config = target/'client.json'
        config.write_text(json.dumps(dict(url=url,connection=connection,seed_file=str(state/'caller.seed'))))
        return Consumer(['ruby',str(script),str(config)],environment,target)
    return 'ruby',create


def install_rust(target):
    target.mkdir()
    names = ('transit-client','transit-native-client','transit-station-sdk','transit-native-station')
    for name in names:
        with tarfile.open(ROOT/'.cache/bindings/rust'/f'{name}-0.2.0.crate') as archive:
            archive.extractall(target/'vendor',filter='data')
    (target/'src').mkdir()
    shutil.copy2(ROOT/'tests/rust_mutation_sdk.rs',target/'src/main.rs')
    manifest = '''[package]
name = "transit-mutation-proof"
version = "0.1.0"
edition = "2024"
[dependencies]
transit-client = "=0.2.0"
transit-station-sdk = "=0.2.0"
serde_json = { version = "=1.0.145", features = ["arbitrary_precision"] }
[patch.crates-io]
'''+''.join(f'{name} = {{ path = "vendor/{name}-0.2.0" }}\n' for name in names)
    (target/'Cargo.toml').write_text(manifest)
    lock = target/'vendor/transit-station-sdk-0.2.0/Cargo.lock'
    shutil.copy2(lock,target/'Cargo.lock')
    environment = {k:v for k,v in os.environ.items() if k not in ('TRANSIT_LIBRARY_DIR','LD_LIBRARY_PATH','LIBRARY_PATH')}
    subprocess.run(['cargo','check','--offline'],cwd=target,env=environment,check=True)
    def registry(path):
        return {(p['name'],p['version'],p['checksum']) for p in tomllib.loads(path.read_text())['package'] if 'source' in p}
    # This caller leaves the optional Arrow reader disabled. Cargo removes that
    # unused graph from a consumer lock; every retained version/checksum must
    # still come from the packaged lock, with no new registry resolution.
    selected = registry(target/'Cargo.lock')
    assert selected and selected <= registry(lock)
    assert not any(name.startswith('arrow-') for name, _, _ in selected)
    subprocess.run(['cargo','build','--locked','--offline'],cwd=target,env=environment,check=True)
    executable = target/'consumer'
    shutil.copy2(target/'target/debug/transit-mutation-proof',executable)
    (target/'src/main.rs').write_text('fn overlap(client: &mut transit_station_sdk::mutations::Client) { let a = &mut *client; let b = &mut *client; a.describe().unwrap(); b.describe().unwrap(); } fn main() {}')
    rejected = subprocess.run(['cargo','check','--locked','--offline'],cwd=target,env=environment,capture_output=True,text=True)
    assert rejected.returncode and 'cannot borrow `*client` as mutable more than once' in rejected.stderr
    shutil.rmtree(target/'vendor'); shutil.rmtree(target/'target'); shutil.rmtree(target/'src')
    def create(url,connection,state):
        config = target/'client.json'
        config.write_text(json.dumps(dict(url=url,connection=connection,seed_file=str(state/'caller.seed'))))
        return Consumer([str(executable),str(config)],environment,target)
    return 'rust',create
