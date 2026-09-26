"""Install Rust Station artifacts outside the checkout and share the live schedule."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tomllib
from sdk_station_runner import Consumer, run as schedule


def run(node, cli, library, artifacts):
    root = Path(__file__).resolve().parents[1]
    def install(target):
        names = ('transit-client', 'transit-native-client', 'transit-station-sdk', 'transit-native-station', 'transit-sdk-examples-rust')
        for name in names:
            with tarfile.open(Path(artifacts).resolve() / f'{name}-0.2.0.crate') as archive:
                archive.extractall(target / 'vendor', filter='data')
        (target / 'src/bin').mkdir(parents=True)
        shutil.copyfile(root / 'tests/rust_station_sdk.rs', target / 'src/main.rs')
        shutil.copyfile(target / 'vendor/transit-sdk-examples-rust-0.2.0/src/main.rs', target / 'src/bin/transit-rust-counter.rs')
        manifest = '''[package]
name = "transit-rust-station-proof"
version = "0.1.0"
edition = "2024"
[features]
arrow = ["transit-station-sdk/arrow", "dep:arrow-array"]
[dependencies]
transit-client = "=0.2.0"
transit-station-sdk = "=0.2.0"
transit-sdk-examples-rust = "=0.2.0"
serde_json = { version = "=1.0.145", features = ["arbitrary_precision"] }
arrow-array = { version = "=59.1.0", optional = true, default-features = false }
[patch.crates-io]
'''
        manifest += ''.join(f'{name} = {{ path = "vendor/{name}-0.2.0" }}\n' for name in names)
        (target / 'Cargo.toml').write_text(manifest)
        lock = target / 'vendor/transit-station-sdk-0.2.0/Cargo.lock'
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
        for code, source in cases.items():
            (target / 'src/main.rs').write_text(source)
            checked = subprocess.run(['cargo', 'check', '--locked', '--offline', '--bin', 'transit-rust-station-proof'], cwd=target, env=environment, capture_output=True, text=True)
            assert checked.returncode != 0 and code in checked.stderr, checked.stderr
        shutil.rmtree(target / 'vendor'); shutil.rmtree(target / 'target'); shutil.rmtree(target / 'src')
        def command(mode, config):
            # The query handler retains original SDK segments; its optional Arrow
            # consumer decodes them only after closing the runner.
            selected = arrow if json.loads(config.read_text())['role'] == 'query' else core
            return [selected, mode, config]
        return Consumer(environment, command,
            lambda config, role: [executable_cli, config, role, '--commits', '1'], 'panic-handler', ('panic-block',))
    schedule(node, cli, library, install, 'Rust')


if __name__ == '__main__': run(*sys.argv[1:])
