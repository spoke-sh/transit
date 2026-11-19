"""Check direct imports and I/O authority of the extracted libraries."""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[2]
PURE = {'transit_sql_frontend', 'transit_protocol', 'transit_memory'}
ALLOWED = {'transitc-compiler': PURE, 'transitc-workspace': PURE | {'transit_compiler'}}

def inventory():
    result = {}
    for package, allowed in ALLOWED.items():
        files = {}
        for path in sorted((ROOT / 'packages' / package / 'src').glob('*.zig')):
            text = path.read_text()
            imports = sorted(set(re.findall(r'@import\("([^"\n]+)"\)', text)))
            for name in imports:
                assert name == 'std' or name in allowed or (name.endswith('.zig') and '/' not in name), (path, name)
            if package == 'transitc-compiler':
                assert not re.search(r'\bstd\.process\b|\bstd\.fs\.(?!path\b)|\bstd\.Io\.(?:Dir|File|net)\b', text), path
            external = [name for name in imports if name in allowed]
            if external:
                files[str(path.relative_to(ROOT))] = external
        result[package] = {'allowed_imports': sorted(allowed), 'external_imports': files}
    return result

if __name__ == '__main__':
    import sys
    result = inventory()
    path = ROOT / 'tests/dependencies/inventory.json'
    if sys.argv[1:] == ['--record']:
        path.write_text(json.dumps(result, indent=2) + '\n')
    else:
        assert json.loads(path.read_text()) == result, 'Review dependency ownership before recording drift'
    print('Compiler/workspace imports match the bounded ownership inventory')
