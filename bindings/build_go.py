"""Package the Go module and its separately installed, matching native library."""
import argparse
import io
from pathlib import Path
import tarfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = (ROOT / 'VERSION').read_text().strip()


def archive(path, files):
    with tarfile.open(path, 'w:gz') as output:
        for relative, source in sorted(files.items()):
            data = source.read_bytes()
            info = tarfile.TarInfo(relative)
            info.size, info.mode = len(data), 0o644
            output.addfile(info, io.BytesIO(data))


def build(output, native_prefix):
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    native_prefix = Path(native_prefix).resolve()
    library = native_prefix / 'lib/libtransit_client.so'
    if not library.is_file():
        raise SystemExit('Run just bindings::build before packaging Go artifacts')
    source = ROOT / 'sdks/go'
    files = {str(path.relative_to(source)): path for path in source.rglob('*')
             if path.is_file() and (path.suffix in ('.go', '.c', '.h', '.md') or path.name == 'go.mod')
             and not any(part.startswith('.') for part in path.relative_to(source).parts)}
    archive(output / f'transit-go-{VERSION}.tar.gz', files)
    archive(output / f'transit-go-native-{VERSION}.tar.gz', {'lib/libtransit_client.so': library})
    print(f'Built Go module and native {VERSION} installation archives')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output')
    parser.add_argument('--native-prefix', required=True)
    args = parser.parse_args()
    build(args.output, args.native_prefix)
