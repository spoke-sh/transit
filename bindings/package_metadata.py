"""Apply the distribution identity only to isolated SDK packaging inputs."""
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
BASE_VERSION = (ROOT / 'VERSION').read_text().strip()
IDENTITY = (json.loads(subprocess.check_output(
    [sys.executable, '-B', str(ROOT / 'tasks/release_identity.py'), 'show'], text=True))
    if os.environ.get('TRANSIT_RELEASE_IDENTITY') else None)


def version(language):
    return IDENTITY['package_versions'][language] if IDENTITY else BASE_VERSION


def rewrite(data, language, name=''):
    """Rewrite owned package pins and embedded version literals, never IP addresses."""
    effective = version(language)
    if effective == BASE_VERSION:
        return data
    try:
        text = data.decode('utf-8')
    except UnicodeDecodeError:
        return data
    pattern = rf'(?<![0-9A-Za-z_])(?<![0-9]\.){re.escape(BASE_VERSION)}(?![0-9A-Za-z_]|\.[0-9])'
    if name == 'Cargo.lock':
        # External packages can happen to share our base version.
        text = '\n[[package]]\n'.join(
            re.sub(pattern, effective, part) if re.search(r'^name = "transit-', part, re.M) else part
            for part in text.split('\n[[package]]\n'))
    elif name == 'package.json':
        manifest = json.loads(text)
        if manifest.get('version') == BASE_VERSION:
            manifest['version'] = effective
        for group in ('dependencies', 'devDependencies', 'peerDependencies', 'optionalDependencies'):
            for dependency, pin in manifest.get(group, {}).items():
                if dependency.startswith('@transit/'):
                    manifest[group][dependency] = re.sub(pattern, effective, pin)
        text = json.dumps(manifest, indent=2) + '\n'
    else:
        text = re.sub(pattern, effective, text)
    return text.encode()


def rewrite_tree(directory, language):
    for path in directory.rglob('*'):
        if path.is_file() and not path.is_symlink():
            original = path.read_bytes()
            changed = rewrite(original, language, path.name)
            if changed != original:
                path.write_bytes(changed)
