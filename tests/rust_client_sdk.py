"""Compile and run public Rust client artifacts from a clean external consumer."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
from sdk_raw_client import run as schedule


def run(node, cli, library, artifacts):
    root = Path(__file__).resolve().parents[1]
    def install(target):
        for name in ('transit-client', 'transit-native-client'):
            with tarfile.open(Path(artifacts).resolve() / f'{name}-0.2.0.crate') as archive:
                archive.extractall(target / 'vendor', filter='data')
        (target / 'src').mkdir()
        shutil.copyfile(root / 'tests/rust_client_sdk.rs', target / 'src/main.rs')
        shutil.copyfile(root / 'tests/rust_native_lifetime.rs', target / 'src/native_lifetime.rs')
        (target / 'Cargo.toml').write_text('''[package]
name = "transit-rust-client-proof"
version = "0.1.0"
edition = "2024"
[dependencies]
transit-client = "=0.2.0"
serde_json = { version = "=1.0.145", features = ["arbitrary_precision"] }
[patch.crates-io]
transit-client = { path = "vendor/transit-client-0.2.0" }
transit-native-client = { path = "vendor/transit-native-client-0.2.0" }
''')
        lock = (target / 'vendor/transit-client-0.2.0/Cargo.lock').read_text()
        lock += '''\n[[package]]
name = "transit-rust-client-proof"
version = "0.1.0"
dependencies = ["serde_json", "transit-client"]
'''
        (target / 'Cargo.lock').write_text(lock)
        env = {k: v for k, v in os.environ.items() if k not in ('TRANSIT_LIBRARY_DIR', 'LD_LIBRARY_PATH', 'LIBRARY_PATH')}
        subprocess.run(['cargo', 'build', '--locked', '--offline'], cwd=target, env=env, check=True)
        executable = target / 'consumer'
        shutil.copy2(target / 'target/debug/transit-rust-client-proof', executable)
        # Language-level rejection is the blocking API's admission/disposal guard.
        cases = {
            'E0499': 'fn overlap(client: &mut transit_client::Client) { let first = &mut *client; let second = &mut *client; drop((first, second)); } fn main() {}',
            'E0382': 'fn closed(client: transit_client::Client) { client.close().unwrap(); client.last_receipt(); } fn main() {}',
            'E0277': 'fn share<T: Sync>() {} fn main() { share::<transit_client::Client>(); }',
        }
        for code, source in cases.items():
            (target / 'src/main.rs').write_text(source)
            checked = subprocess.run(['cargo', 'check', '--locked', '--offline'], cwd=target, env=env, capture_output=True, text=True)
            assert checked.returncode != 0 and code in checked.stderr, checked.stderr
        # Installation must survive removal of build outputs and extracted crates.
        override = target / 'native-override'
        override.mkdir()
        shutil.copy2(target / 'vendor/transit-native-client-0.2.0/lib/libtransit_client.so', override)
        env['TRANSIT_RUST_TEST_NATIVE_DIRECTORY'] = str(override)
        shutil.rmtree(target / 'vendor'); shutil.rmtree(target / 'target'); shutil.rmtree(target / 'src')
        def invoke(mode, config):
            return subprocess.check_output([executable, mode, config], cwd=target, env=env, timeout=30)
        return invoke
    schedule(node, cli, library, install, 'Rust')


if __name__ == '__main__': run(*sys.argv[1:])
