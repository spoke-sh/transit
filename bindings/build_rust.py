"""Build source-crate artifacts with version-matched, embedded native libraries."""
import io
import argparse
from pathlib import Path
import re
import tarfile
import tomllib

from package_metadata import rewrite

ROOT = Path(__file__).resolve().parents[1]


def build(output, names, native_prefix):
    output = Path(output).resolve()
    native_prefix = Path(native_prefix).resolve()
    output.mkdir(parents=True, exist_ok=True)
    for name in names:
        source = ROOT / name if '/' in name else ROOT / 'sdks/rust' / name
        manifest = tomllib.loads(rewrite((source / 'Cargo.toml').read_bytes(), 'rust', 'Cargo.toml').decode())
        stem = f"{manifest['package']['name']}-{manifest['package']['version']}"
        files = {Path('Cargo.toml'): re.sub(r', path = "[^"]+"', '', (source / 'Cargo.toml').read_text()).encode()}
        for member in manifest['package']['include'] + ['Cargo.lock']:
            path = source / member
            if path.is_file(): files[Path(member)] = path.read_bytes()
            elif path.is_dir():
                for item in sorted(path.rglob('*')):
                    if item.is_file(): files[item.relative_to(source)] = item.read_bytes()
        if name.startswith('transit-native-'):
            family = name.removeprefix('transit-native-')
            library = native_prefix / 'lib' / f'libtransit_{family}.so'
            if not library.is_file(): raise SystemExit('Run just bindings::build before packaging Rust artifacts')
            files[Path('lib') / library.name] = library.read_bytes()
        with tarfile.open(output / f'{stem}.crate', 'w:gz') as archive:
            for relative, data in sorted(files.items()):
                data = rewrite(data, 'rust', relative.name) if relative.parts[0] != 'lib' else data
                entry = tarfile.TarInfo(str(Path(stem) / relative))
                entry.size, entry.mode = len(data), 0o644
                archive.addfile(entry, io.BytesIO(data))
        print(f'Built {stem}.crate')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output')
    parser.add_argument('names', nargs='*')
    parser.add_argument('--native-prefix', required=True)
    args = parser.parse_args()
    build(args.output, args.names or ['transit-native-client', 'transit-client',
        'transit-native-station', 'transit-station-sdk', 'examples/station-sdk/rust'], args.native_prefix)
