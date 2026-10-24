"""Enforce the one-way boundary from consumer SDKs to shared runtime packages."""
from pathlib import Path
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def violations(root, paths):
    sdk_names = {json.loads(p.read_text())['name'] for p in (root / 'sdks/ts').glob('*/package.json')}
    errors = []
    for relative in paths:
        path = root / relative
        if not relative.startswith(('apps/', 'packages/')) or not path.is_file():
            continue
        if path.name == 'package.json':
            data = json.loads(path.read_text())
            for kind in ('dependencies', 'devDependencies', 'peerDependencies', 'optionalDependencies'):
                for name, version in data.get(kind, {}).items():
                    if name in sdk_names or 'sdks/' in version:
                        errors.append(f'{relative}: runtime dependency on SDK {name}')
        elif path.name == 'go.mod' or path.suffix == '.go':
            # Go SDK consumers declare modules, while runtime implementation
            # must remain independent of the SDK module and local replacements.
            if re.search(r'github\.com/spoke-sh/transit/sdks/|(?:\.\./)+sdks/', path.read_text()):
                errors.append(f'{relative}: runtime dependency on Go SDK')
        elif path.name.startswith('tsconfig') and path.suffix == '.json':
            # Compiler path aliases must not hide an otherwise forbidden import.
            for value in re.findall(r'"([^"\n]+)"', path.read_text()):
                if 'sdks/' in value and (path.parent / value).resolve().is_relative_to(root / 'sdks'):
                    errors.append(f'{relative}: compiler path into SDK {value}')
        elif path.suffix in ('.zig', '.zon', '.ts', '.tsx', '.js', '.mjs'):
            text = path.read_text()
            # Documentation catalogs name Markdown sources; they do not import
            # SDK implementation. Inspect executable import/path declarations.
            references = re.findall(r'@import\("([^"]+)"\)|\.path\s*=\s*"([^"]+)"|\bfrom\s+[\"\x27]([^\"\x27]+)[\"\x27]|\bimport\s*\([\"\x27]([^\"\x27]+)[\"\x27]\)', text)
            references += re.findall(r'\b(?:require\s*\(|import\s+)[\"\x27]([^\"\x27]+)[\"\x27]', text)
            references = [(reference,) if isinstance(reference, str) else reference for reference in references]
            for groups in references:
                value = next(v for v in groups if v)
                resolved = (path.parent / value).resolve()
                if resolved.is_relative_to(root / 'sdks') or any(value == name or value.startswith(name + '/') for name in sdk_names):
                    errors.append(f'{relative}: runtime import of SDK {value}')
    return errors


def main():
    paths = subprocess.check_output(['git', 'ls-files', '-z', 'apps', 'packages'], cwd=ROOT).decode().split('\0')
    errors = violations(ROOT, paths)
    assert not errors, '\n'.join(errors)
    # Negative controls exercise both ecosystems, including a normalized path
    # that hides the SDK directory behind a parent traversal.
    import tempfile
    with tempfile.TemporaryDirectory(prefix='transit-sdk-boundary-') as directory:
        root = Path(directory)
        for name, data in {
            'sdks/ts/client/package.json': '{"name":"@transit/client"}',
            'apps/bad/package.json': '{"dependencies":{"@transit/client":"workspace:*"}}',
            'packages/zig/bad/build.zig.zon': '.{ .dependencies = .{ .sdk = .{ .path = "../../../sdks/zig" } } }',
            'packages/ts/bad/main.ts': 'import { Client } from "@transit/client";',
            'apps/bad/tsconfig.json': '{"compilerOptions":{"paths":{"sdk":["../../sdks/ts/client"]}}}',
            'apps/bad/side-effect.ts': 'import "@transit/client";',
            'apps/bad/main.zig': '@import("../../sdks/zig/consumer.zig")',
            'apps/bad/go.mod': 'module runtime\nrequire github.com/spoke-sh/transit/sdks/go v0.2.0\n',
            'apps/bad/main.go': 'package main\nimport "github.com/spoke-sh/transit/sdks/go/client"\n',
            'apps/bad/replaced/go.mod': 'module runtime\nreplace sdk => ../../../sdks/go\n',
        }.items():
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(data)
        bad = ['apps/bad/package.json', 'packages/zig/bad/build.zig.zon', 'packages/ts/bad/main.ts', 'apps/bad/main.zig', 'apps/bad/side-effect.ts', 'apps/bad/tsconfig.json',
               'apps/bad/go.mod', 'apps/bad/main.go', 'apps/bad/replaced/go.mod']
        assert len(violations(root, bad)) == len(bad)
    print('SDK boundary: runtime manifests/imports are independent; negative controls rejected')


if __name__ == '__main__':
    main()
