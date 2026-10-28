"""Explicit resolution of installed artifacts; importing starts no work."""
from pathlib import Path
import platform
import sys

__version__ = '0.0.1'


def _artifact(directory: str, name: str) -> Path:
    if sys.platform != 'linux' or platform.machine() != 'x86_64':
        raise RuntimeError('Transit native 0.0.1 is qualified for Linux x86_64')
    path = Path(__file__).parent / directory / name
    if not path.is_file():
        raise RuntimeError('Missing Transit native artifact; install the built transit-native wheel')
    return path


def library_path() -> Path:
    return _artifact('lib', 'libtransit_station.so')


def host_path() -> Path:
    return _artifact('bin', 'transit-station-host')
