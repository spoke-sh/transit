"""Package relocatable C/C++ SDK prefixes with standard pkg-config discovery."""
import io
from pathlib import Path
import sys
import tarfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = '0.2.0'


def build(output):
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    native = ROOT / 'zig-out/lib/libtransit_client.so'
    sdk = ROOT / 'packages/c/transit-client/zig-out/lib/libtransit_sdk_client.so'
    if not native.is_file() or not sdk.is_file():
        raise SystemExit('Run just bindings::c-build to compile both SDK and native dependency')
    packages = {
        'transit-native-client-c': {'lib/libtransit_client.so': native.read_bytes(),
            'include/transit_client.h': (ROOT / 'packages/zig/transit-client/include/transit_client.h').read_bytes()},
        'transit-client-c': {'lib/libtransit_sdk_client.so': sdk.read_bytes()},
        'transit-client-cpp': {},
    }
    for name, language in [('transit-client-c', 'c'), ('transit-client-cpp', 'cpp')]:
        package = ROOT / 'packages' / language / 'transit-client'
        for path in sorted((package / 'include').rglob('*')):
            if path.is_file(): packages[name][str(path.relative_to(package))] = path.read_bytes()
        for path in [package / 'README.md', *sorted((package / 'docs').glob('*.md'))]:
            packages[name][f'share/doc/{name}/{path.name}'] = path.read_bytes()
        libraries = '-L${libdir} -Wl,-rpath,${libdir} -ltransit_sdk_client' if language == 'c' else ''
        requires = 'transit-client-c = 0.2.0' if language == 'cpp' else 'transit-native-client-c = 0.2.0'
        packages[name][f'lib/pkgconfig/{name}.pc'] = (
            'prefix=${pcfiledir}/../..\nlibdir=${prefix}/lib\nincludedir=${prefix}/include\n'
            f'Name: {name}\nDescription: Typed Transit {language} SDK\nVersion: {VERSION}\n'
            f'Requires: {requires}\nCflags: -I${{includedir}}\nLibs: {libraries}\n').encode()
    packages['transit-native-client-c']['lib/pkgconfig/transit-native-client-c.pc'] = (
        f'Name: transit-native-client-c\nDescription: Transit native ABI dependency\nVersion: {VERSION}\n').encode()
    for name, files in packages.items():
        platform = '-linux-x86_64' if name != 'transit-client-cpp' else ''
        artifact = output / f'{name}-{VERSION}{platform}.tar.gz'
        with tarfile.open(artifact, 'w:gz') as archive:
            for relative, data in sorted(files.items()):
                entry = tarfile.TarInfo(relative)
                entry.size, entry.mode = len(data), 0o755 if relative.endswith('.so') else 0o644
                archive.addfile(entry, io.BytesIO(data))
        print(f'Built {artifact.name}')


if __name__ == '__main__': build(sys.argv[1])
