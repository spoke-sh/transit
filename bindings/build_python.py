"""Build version-matched SDK wheels from explicit native build outputs."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def build(output: Path, packages: list[str]) -> None:
    output = output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    for name in packages:
        source = ROOT / ('examples/station-sdk/python' if name == 'transit-sdk-examples' else 'packages/python/' + name)
        with tempfile.TemporaryDirectory(prefix='transit-wheel-') as temporary:
            staging = Path(temporary) / name
            shutil.copytree(source, staging, ignore=shutil.ignore_patterns('__pycache__', '*.egg-info', 'build', 'dist'))
            if name.startswith('transit-native-'):
                family = name.removeprefix('transit-native-')
                module = staging / ('transit_native_' + family)
                for directory, filename in [('lib', f'libtransit_{family}.so'), ('bin', f'transit-{family}-host')]:
                    artifact = ROOT / 'zig-out' / directory / filename
                    if not artifact.is_file():
                        raise SystemExit('Missing native artifact: run just bindings::build first')
                    (module / directory).mkdir()
                    shutil.copy2(artifact, module / directory / filename)
            subprocess.run([sys.executable, '-m', 'build', '--wheel', '--no-isolation', '--outdir', str(output), str(staging)], check=True)


if __name__ == '__main__':
    build(Path(sys.argv[1]), sys.argv[2:] or ['transit-native-client', 'transit-native-station', 'transit-client', 'transit-station', 'transit-sdk-examples'])
