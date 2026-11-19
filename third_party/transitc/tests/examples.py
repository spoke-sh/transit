"""Keep runnable handbook projects and their documented outcomes in agreement."""
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PROJECTS = {
    'first': ('guides/getting-started.md', {'build.transit': 0},
              "CREATE TABLE ITEMS ( ID BIGINT PRIMARY KEY , LABEL TEXT );\n"
              "INSERT INTO ITEMS VALUES ( 7 , 'ready' );\nSELECT * FROM ITEMS;\n"),
    'modules': ('guides/source-workflow.md', {'rows.transit': 0, 'build.transit': 1},
                'CREATE TABLE "items" ( ID BIGINT );\n'
                'INSERT INTO "items" VALUES ( 7 );\nSELECT * FROM ITEMS;\n'),
    'migration': ('reference/artifacts.md', {'build.transit': 0},
                  'CREATE TABLE ITEMS ( ID BIGINT PRIMARY KEY );\n'),
}


def main():
    compiler = Path(sys.argv[1]).resolve()
    for name, (page, files, expected_sql) in PROJECTS.items():
        blocks = re.findall(r'^```sql\n(.*?)^```',
                            (ROOT / 'docs/handbook' / page).read_text(), re.M | re.S)
        for filename, index in files.items():
            assert (ROOT / 'examples' / name / filename).read_text() == blocks[index], (page, filename)
        with tempfile.TemporaryDirectory(prefix='transitc-example-') as temporary:
            root = Path(temporary)
            shutil.copytree(ROOT / 'examples' / name, root / 'source')
            result = subprocess.run([str(compiler), 'build', '--out', str(root / 'output'), '--format', 'json'],
                                    cwd=root / 'source', capture_output=True, text=True, timeout=120)
            assert result.returncode == 0, result
            assert json.loads(result.stdout)['ok'] is True
            output = root / 'output'
            sql = output / ('desired.sql' if name == 'migration' else 'application.sql')
            assert sql.read_text() == expected_sql, (name, sql.read_text())
            assert (output / 'provenance.json').is_file()
            if name == 'migration':
                assert (output / 'basis.json').is_file()
                assert (output / 'migrations/0001-tables.sql').read_text() == expected_sql
        print(f'PASS handbook {page}: exact source and published {name} artifacts')


if __name__ == '__main__':
    main()
