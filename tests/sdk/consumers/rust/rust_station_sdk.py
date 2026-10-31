"""Install Rust Station artifacts outside the checkout and share the live schedule."""

from sdk.artifact_versions import package_text
from runner.paths import ROOT
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tomllib
import tempfile
from harness.phases import phase
from sdk.sdk_station_runner import Consumer, run as schedule


def compile_consumer(target, artifacts):
    root = ROOT
    names = ('transit-client', 'transit-native-client', 'transit-station-sdk', 'transit-native-station', 'transit-sdk-examples-rust')
    for name in names:
        with tarfile.open(Path(artifacts).resolve() / package_text(f'{name}-0.0.1.crate', 'rust')) as archive:
            archive.extractall(target / 'vendor', filter='data')
    (target / 'src/bin').mkdir(parents=True)
    shutil.copyfile(root / 'tests/sdk/consumers/rust/rust_station_sdk.rs', target / 'src/main.rs')
    shutil.copyfile(root / 'tests/sdk/consumers/rust/rust_native_lifetime.rs', target / 'src/native_lifetime.rs')
    shutil.copyfile(target / package_text('vendor/transit-sdk-examples-rust-0.0.1/src/main.rs', 'rust'), target / 'src/bin/transit-rust-counter.rs')
    manifest = package_text('''[package]
name = "transit-rust-station-proof"
version = "0.1.0"
edition = "2024"
[features]
arrow = ["transit-station-sdk/arrow", "dep:arrow-array"]
[dependencies]
transit-client = "=0.0.1"
transit-station-sdk = "=0.0.1"
transit-sdk-examples-rust = "=0.0.1"
serde_json = { version = "=1.0.145", features = ["arbitrary_precision"] }
arrow-array = { version = "=59.1.0", optional = true, default-features = false }
[patch.crates-io]
''', 'rust')
    manifest += ''.join(package_text(f'{name} = {{ path = "vendor/{name}-0.0.1" }}\n', 'rust') for name in names)
    (target / 'Cargo.toml').write_text(manifest)
    lock = target / package_text('vendor/transit-station-sdk-0.0.1/Cargo.lock', 'rust')
    shutil.copyfile(lock, target / 'Cargo.lock')
    environment = {k: v for k, v in os.environ.items() if k not in ('TRANSIT_LIBRARY_DIR', 'LD_LIBRARY_PATH', 'LIBRARY_PATH')}
    # Add the installed example and consumer to the SDK lock without changing
    # any registry dependency; then enforce that resulting lock for builds.
    subprocess.run(['cargo', 'check', '--offline'], cwd=target, env=environment, check=True)
    def registry(path):
        return {(p['name'], p['version'], p['checksum']) for p in tomllib.loads(path.read_text())['package'] if 'source' in p}
    assert registry(target / 'Cargo.lock') == registry(lock)
    tree = subprocess.check_output(['cargo', 'tree', '--locked', '--offline', '-e', 'normal'], cwd=target, env=environment, text=True)
    assert 'arrow-' not in tree, tree
    subprocess.run(['cargo', 'build', '--locked', '--offline'], cwd=target, env=environment, check=True)
    core = target / 'consumer'
    shutil.copy2(target / 'target/debug/transit-rust-station-proof', core)
    executable_cli = target / 'transit-rust-counter'
    shutil.copy2(target / 'target/debug/transit-rust-counter', executable_cli)
    subprocess.run(['cargo', 'build', '--locked', '--offline', '--features', 'arrow', '--bin', 'transit-rust-station-proof'], cwd=target, env=environment, check=True)
    arrow = target / 'consumer-arrow'
    shutil.copy2(target / 'target/debug/transit-rust-station-proof', arrow)
    cases = {
        'E0499': "fn overlap(turn: &mut transit_station_sdk::Turn<'_>) { let state = turn.state(); turn.budgets().unwrap(); drop(state); } fn main() {}",
        'E0277': "fn send<T: Send>() {} fn main() { send::<transit_station_sdk::Turn<'static>>(); }",
        'lifetime may not live long enough': "fn escape<'a>(turn: &'a mut transit_station_sdk::Turn<'a>) -> transit_station_sdk::State<'static> { turn.state() } fn main() {}",
        'E0308': 'use transit_station_sdk::Codec; fn main() { transit_sdk_examples::codecs::U64Codec.encode(&true).unwrap(); }',
    }
    cases['cannot borrow `*runner` as mutable more than once at a time'] = "fn overlap(runner: &mut transit_station_sdk::Runner<()>, outcome: &transit_station_sdk::HttpOutcome) { let mut reader = runner.open_http(outcome, transit_station_sdk::HttpReplayPolicy::Captured).unwrap(); runner.next().unwrap(); reader.read().unwrap(); } fn main() {}"
    document_reader_case = "fn overlap(runner: &mut transit_station_sdk::Runner<()>) { let mut reader = runner.documents().unwrap(); runner.next().unwrap(); reader.describe(transit_client::ResourceRef::new(72,1).unwrap(),1).unwrap(); } fn main() {}"
    document_owner_case = "fn escape<'a>(turn: &'a mut transit_station_sdk::Turn<'a>) -> transit_station_sdk::DocumentOwner<'static> { turn.document(1).unwrap() } fn main() {}"
    for code, source in [*cases.items(),
            ('cannot borrow `*runner` as mutable more than once at a time', document_reader_case),
            ('lifetime may not live long enough', document_owner_case)]:
        (target / 'src/main.rs').write_text(source)
        checked = subprocess.run(['cargo', 'check', '--locked', '--offline', '--bin', 'transit-rust-station-proof'], cwd=target, env=environment, capture_output=True, text=True)
        assert checked.returncode != 0 and code in checked.stderr, checked.stderr
    shutil.rmtree(target / 'vendor'); shutil.rmtree(target / 'target'); shutil.rmtree(target / 'src')
    return environment


def run(node, cli, library, artifacts, http_worker=None, grpc_worker=None, *, execute=None):
    if execute is None and http_worker is None:
        raise ValueError("The full Station SDK schedule requires the HTTP worker binary")
    # Reuse only compiled programs within this invocation. Every schedule still
    # installs its own copies and owns fresh services, configuration and disk.
    # Package/feature/negative-type checks execute once before any live schedule.
    with tempfile.TemporaryDirectory(prefix="transit-rust-consumer-") as directory:
        prepared = Path(directory)
        with phase("consumer-build", "rust-station"):
            environment = compile_consumer(prepared, artifacts)
        def install(target):
            for name in ('consumer', 'consumer-arrow', 'transit-rust-counter'):
                shutil.copy2(prepared / name, target / name)
            def command(mode, config):
                cfg = json.loads(config.read_text())
                selected = 'consumer-arrow' if cfg.get('role') == 'query' and cfg.get('arrow_adapter', True) else 'consumer'
                return [target / selected, mode, config]
            return Consumer(environment.copy(), command,
                lambda config, role: [target / 'transit-rust-counter', config, role, '--commits', '1'],
                'panic-handler', ('panic-block',))
        (execute or schedule)(node, cli, library, install, 'Rust')
        if execute is None:
            from sdk.sdk_http_runner import run as http_schedule
            http_schedule(node, cli, library, http_worker, install, 'Rust', public_release=True, public_followup=True)
            if grpc_worker is not None:
                from sdk.sdk_exchange_runner import run as grpc_schedule
                grpc_schedule(node, cli, library, grpc_worker, install, 'Rust',
                              public_release=True, public_followup=True, protocol='grpc')


if __name__ == '__main__': run(*sys.argv[1:])
