"""Select exact package versions from the supplied release, or the source baseline."""
import json
import os
import platform
import re
from pathlib import Path

from runner.paths import ROOT


def package_text(text, language):
    binary = isinstance(text, bytes)
    value = text.decode() if binary else text
    base = (ROOT / 'VERSION').read_text().strip()
    manifest = os.environ.get('TRANSIT_SDK_TEST_MANIFEST')
    version = base
    architecture = platform.machine()
    if manifest:
        data = json.loads(Path(manifest).read_text())
        version = data['identity']['package_versions'][language]
        architecture = data['target'].split('-')[0]
    value = re.sub(rf'(?<![0-9A-Za-z_])(?<![0-9]\.){re.escape(base)}(?![0-9A-Za-z_]|\.[0-9])', version, value)
    value = value.replace('linux-x86_64', 'linux-' + architecture)
    value = value.replace('x86_64-linux', architecture + '-linux')
    return value.encode() if binary else value
