"""Audit explicit local Python imports without running services or consumers."""
import argparse
import ast
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def build_invocations(root):
    """Check the literal Python command forms used by build registration.

    This is an invocation convention check, not a Zig interpreter. Computed
    commands and example-owned launchers still need their actual schedules.
    """
    result = []
    for path in [root / 'build.zig', *sorted((root / 'build').glob('*.zig'))]:
        if not path.is_file():
            continue
        source = path.read_text()
        pattern = r'const (\w+) = b\.addSystemCommand\(&\.\{([^}]+)\}\);'
        for match in re.finditer(pattern, source):
            arguments = re.findall(r'"([^"\\]*)"', match[2])
            if arguments[:2] != ['python3', '-B']:
                continue
            if len(arguments) > 2:
                script = arguments[2]
            else:
                files = re.search(re.escape(match[1]) + r'\.addFileArg\(b\.path\("([^"]+)"\)\)',
                                  source[match.end():])
                if files is None:
                    continue
                script = files[1]
            script = script.removeprefix('./')
            owner = str(path.relative_to(root))
            line = source[:match.start()].count('\n') + 1
            assert not script.startswith('tests/') or script.startswith('tests/runner/'), (
                f'{owner}:{line}: domain driver {script} requires tests/runner/launch.py')
            result.append(dict(source=owner, line=line, command=match[1], entry_point=script))
    return result


def declarations(tree):
    names = set()

    def visit(node):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            names.add(node.name)
            return
        if isinstance(node, (ast.Lambda, ast.ListComp, ast.SetComp, ast.DictComp, ast.GeneratorExp)):
            return
        if isinstance(node, ast.Import):
            names.update(value.asname or value.name.split('.')[0] for value in node.names)
        elif isinstance(node, ast.ImportFrom):
            names.update(value.asname or value.name for value in node.names if value.name != '*')
        elif isinstance(node, ast.Name) and isinstance(node.ctx, ast.Store):
            names.add(node.id)
        for child in ast.iter_child_nodes(node):
            visit(child)

    visit(tree)
    return names


def audit(root):
    tests = root / 'tests'
    owners = set(json.loads((tests / 'runner/layout.json').read_text())['owners'])
    listing = subprocess.run(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z', '--', 'tests'],
                             cwd=root, capture_output=True, text=True)
    paths = ([root / name for name in set(listing.stdout.split('\0')) if name.endswith('.py')]
             if listing.returncode == 0 else list(tests.rglob('*.py')))
    modules = {}
    for path in paths:
        if not path.is_file() or '__pycache__' in path.parts:
            continue
        parts = path.relative_to(tests).with_suffix('').parts
        modules['.'.join(parts[:-1] if parts[-1] == '__init__' else parts)] = path
    trees = {name: ast.parse(path.read_text(), filename=str(path)) for name, path in modules.items()}
    exports = {name: declarations(tree) for name, tree in trees.items()}
    edges = []

    def local(name, current):
        if name.split('.')[0] in owners:
            return name
        # Runner entry points also support direct execution from their directory.
        if current.startswith('runner.') and 'runner.' + name in modules:
            return 'runner.' + name
        return None

    def exists(name):
        return name in modules or any(module.startswith(name + '.') for module in modules)

    for name, tree in trees.items():
        path = str(modules[name].relative_to(root))
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                for value in node.names:
                    target = local(value.name, name)
                    if target:
                        assert exists(target), f'{path}:{node.lineno}: missing local module {target}'
                        edges.append(dict(source=path, line=node.lineno, module=target))
            elif isinstance(node, ast.ImportFrom):
                target = node.module or ''
                if node.level:
                    package = name if modules[name].name == '__init__.py' else name.rpartition('.')[0]
                    prefix = package.split('.')[:len(package.split('.')) - node.level + 1]
                    target = '.'.join([*prefix, *([target] if target else [])])
                target = local(target, name)
                if target is None:
                    continue
                for value in node.names:
                    assert value.name != '*', f'{path}:{node.lineno}: local wildcard import hides dependencies'
                    child = target + '.' + value.name
                    assert exists(target), f'{path}:{node.lineno}: missing local module {target}'
                    assert exists(child) or value.name in exports.get(target, set()), (
                        f'{path}:{node.lineno}: {target} does not declare {value.name}')
                    edges.append(dict(source=path, line=node.lineno,
                                      module=child if exists(child) else target, symbol=value.name))
            elif isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and node.func.attr == 'import_module':
                assert node.args and isinstance(node.args[0], ast.Constant) and isinstance(node.args[0].value, str), (
                    f'{path}:{node.lineno}: computed imports need explicit consumer registration')
                target = local(node.args[0].value, name)
                if target:
                    assert exists(target), f'{path}:{node.lineno}: missing local module {target}'
                    edges.append(dict(source=path, line=node.lineno, module=target))
    return {'version': 1, 'module_count': len(modules), 'edges': edges,
            'build_invocations': build_invocations(root),
            'limits': 'Static declarations only; generated scripts, runtime conditions and external packages require their real schedules.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--json', action='store_true')
    args = parser.parse_args()
    report = audit(ROOT)
    print(json.dumps(report, indent=2) if args.json else
          f"Local test imports: {report['module_count']} modules, {len(report['edges'])} explicit edges "
          f"and {len(report['build_invocations'])} literal build invocations checked")


if __name__ == '__main__':
    main()
