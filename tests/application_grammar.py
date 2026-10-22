"""Independent ANTLR/typed-model agreement through the actual application CLI."""
import json
import os
import re
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / '.cache/verification/application-grammar'
CLI = ROOT / 'zig-out/bin/transit-app'


def reference(source):
    from antlr4 import InputStream, CommonTokenStream
    from antlr4.error.ErrorListener import ErrorListener
    from antlr4.atn.PredictionMode import PredictionMode
    from ApplicationLexer import ApplicationLexer
    from ApplicationParser import ApplicationParser

    class Strict(ErrorListener):
        def syntaxError(self, recognizer, offendingSymbol, line, column, msg, e):
            raise ValueError(f'{line}:{column}: {msg}')

        def reportAmbiguity(self, *args):
            raise AssertionError('ambiguous application syntax')

    def name(ctx):
        value = ctx.getText()
        return value[1:-1].replace('""', '"') if value.startswith('"') else value.lower()

    def options(ctx):
        result = {}
        for item in ctx.option():
            key = name(item.identifier())
            assert key not in result
            result[key] = (item.STRING().getText()[1:-1].replace("''", "'")
                           if item.STRING() else int(item.INTEGER().getText()))
        return result

    lexer = ApplicationLexer(InputStream(source))
    lexer.removeErrorListeners()
    lexer.addErrorListener(Strict())
    parser = ApplicationParser(CommonTokenStream(lexer))
    parser.removeErrorListeners()
    parser.addErrorListener(Strict())
    parser._interp.predictionMode = PredictionMode.LL_EXACT_AMBIG_DETECTION
    program = parser.program()
    declaration = program.interfaceDeclaration()
    model = {'version': 1, 'name': name(declaration.identifier()),
             **options(declaration.optionList()),
             'themes': [], 'screens': [], 'bindings': [], 'actions': []}
    model['revision'] = str(model['revision'])
    for item in program.memberDeclaration():
        assert name(item.identifier(0)) == model['name']
        member = {'name': name(item.identifier(1))}
        fields = options(item.optionList())
        kind = item.kind().getText().lower()
        if kind == 'binding':
            source = fields.pop('kind')
            if source == 'query':
                fields['name'] = fields.pop('source')
                fields['sql'] = fields.pop('query')
                fields['schema'] = list(bytes.fromhex(fields['schema']))
            member['source'] = {source: fields}
        elif kind == 'action':
            member.update(label=fields['label'], target={fields['kind']: fields['target']})
        else:
            member.update(fields)
        model[kind + 's'].append(member)
    return model


def run(command, data, directory, success=True, expected=(), facts=None):
    path = directory / 'input'
    path.write_text(data)
    result = subprocess.run([CLI, command, path], capture_output=True, text=True)
    assert (result.returncode == 0) == success, result.stderr
    if not success:
        assert not result.stdout, 'invalid program leaked partial output'
        assert 'Application Declaration Error:' in result.stderr, result.stderr
        assert 'No application was published.' in result.stderr, result.stderr
        assert 'private-value' not in result.stderr, result.stderr
        assert 'stack trace' not in result.stderr and '/src/' not in result.stderr, result.stderr
        for message in expected:
            assert message in result.stderr, (message, result.stderr)
        machine = subprocess.run([CLI, '--diagnostics=json', command, path], capture_output=True, text=True)
        assert machine.returncode == result.returncode and not machine.stdout
        assert len(machine.stderr.splitlines()) == 1, machine.stderr
        diagnostic = json.loads(machine.stderr)
        assert diagnostic['version'] == 1 and diagnostic['definition']
        assert diagnostic['outcome'] == 'not_submitted' and diagnostic['evidence'] == 'local_before_dispatch'
        assert diagnostic['code'].startswith(('application.', 'sql.')) and diagnostic['code'] != 'application.diagnostic_unavailable'
        assert 'private-value' not in machine.stderr
        assert not any(action and action['kind'] in ('resume_exact','cancel_mutation','reconcile_effect') for action in diagnostic['actions'])
        if diagnostic['location']:
            assert diagnostic['location']['source'] == str(path)
            assert int(diagnostic['location']['line']) >= 1 and int(diagnostic['location']['byte_column']) >= 1
        for field, value in (facts or {}).items():
            assert any(fact and fact['field'] == field and fact['value'] == value
                       for fact in diagnostic['facts']), (field, diagnostic)
    else:
        machine = subprocess.run([CLI, '--diagnostics=json', command, path], capture_output=True, text=True)
        assert machine.returncode == 0 and machine.stdout == result.stdout and not machine.stderr
    return result.stdout


def main():
    CACHE.mkdir(parents=True, exist_ok=True)
    subprocess.run(['antlr4', '-Dlanguage=Python3', '-Werror', '-o', str(CACHE),
                    'Application.g4'], cwd=ROOT / 'contracts/application', check=True)
    sys.path.insert(0, str(CACHE))
    fixture = (ROOT / 'packages/zig/transit-station-app/src/fixtures/board.sql').read_text()
    with tempfile.TemporaryDirectory(prefix='transit-application-') as temp:
        directory = Path(temp)
        for source in [fixture, '/* outer /* inner */ */\n' + fixture,
                       fixture.replace("label = 'Atlas'", "label = 'Atlas: it''s 東京'")]:
            model = json.loads(run('parse', source, directory))
            assert model == reference(source)
            # A visual edit changes only presentation in the shared typed model.
            edited = json.loads(json.dumps(model))
            edited['theme'] = 'dense'
            edited['screens'][0]['label'] = 'Resource map'
            canonical = run('format', json.dumps(edited), directory)
            assert reference(canonical) == edited
            assert json.loads(run('parse', canonical, directory)) == edited
            assert edited['bindings'] == model['bindings']
            assert edited['revision'] == '18446744073709551615'
        for source in [fixture + 'GRANT ALL;', fixture[:-2], fixture + '/*',
                       fixture.replace('CREATE INTERFACE', '"CREATE" INTERFACE'),
                       fixture.replace('CREATE THEME', 'CREATE "THEME"'),
                       fixture.replace('revision = 18446744073709551615', 'revision = 018')]:
            try:
                reference(source)
            except ValueError:
                pass
            else:
                raise AssertionError('reference accepted malformed complete program')
            run('parse', source, directory, False)
        for source in [fixture.replace("theme = 'mono'", "theme = 'missing'"),
                       fixture.replace('components = 1', 'components = 2'),
                       fixture.replace('starts = 8', 'starts = 9'),
                       fixture.replace("projection = 'atlas'", "unknown = 'atlas'"),
                       fixture.replace('page_budget = 1', 'page_budget = 1, page_budget = 1')]:
            run('parse', source, directory, False)
        diagnostics = [
            (fixture.replace("theme = 'mono'", "theme = 'missing'"),
             ('MissingInterfaceReference', 'interface: "board"', 'option: "theme"', 'Referenced name: "missing"', 'line 2,')),
            (fixture.replace('starts = 8', 'starts = 9'),
             ('InvalidQueryBudget', 'binding: "items"', 'option: "starts"', 'line 8,')),
            (fixture.replace("projection = 'atlas'", "projection = 'atlas', unknown = 'private-value'"),
             ('UnknownInterfaceOption', 'binding: "catalog"', 'option: "unknown"', 'line 5,')),
            (fixture.replace('page_budget = 1', 'page_budget = 1, page_budget = 1'),
             ('DuplicateInterfaceOption', 'binding: "catalog"', 'option: "page_budget"', 'line 5,')),
            (fixture.replace('page_budget = 1', "page_budget = 'private-value'"),
             ('InvalidInterfaceOption', 'option: "page_budget"', 'Expected an unsigned decimal integer')),
            (fixture.replace("binding = 'items'", "binding = 'absent'"),
             ('screen: "explore"', 'option: "binding"', 'Referenced name: "absent"', 'line 11,')),
            (fixture.replace('SELECT id, value FROM items', 'SELECT id FROM'),
             ('binding: "items"', 'option: "query"', 'Embedded SELECT (coordinates within the binding SQL)', 'line 8,')),
            (fixture.replace("path = '/explore'", "path = '/api/internal'"),
             ('ReservedInterfacePath', 'screen: "explore"', 'option: "path"', 'line 11,')),
        ]
        for source, messages in diagnostics:
            run('parse', source, directory, False, messages)
        for source, dimension, actual, limit, rule, unit in [
            (fixture.split(';')[0] + ';', 'themes', 0, 1, 'at_least', 'members'),
            (fixture + "CREATE THEME board.extra WITH (density = 'compact');", 'themes', 3, 2, 'at_most', 'members'),
            ("CREATE INTERFACE board WITH (entry = '" + 'x' * 4097 + "');", 'decoded literal', 4097, 4096, 'at_most', 'bytes'),
            ('/*' * 17 + '*/' * 17 + fixture, 'comment nesting', 17, 16, 'at_most', 'levels'),
        ]:
            run('parse', source, directory, False, facts={
                'budget': {'text': dimension}, 'unit': {'text': unit},
                'constraint': {'text': rule}, 'limit': {'unsigned': str(limit)},
                'actual_count': {'unsigned': str(actual)},
            })
        malformed_json = subprocess.run([CLI, '--diagnostics=json', 'format', directory/'absent'], capture_output=True, text=True)
        assert malformed_json.returncode == 1 and not malformed_json.stdout
        detail = json.loads(malformed_json.stderr)
        assert detail['code'] == 'application.file_not_found' and detail['location'] is None
        run('format', '{\n"name":', directory, False)
        byte_path = directory / os.fsdecode(b'bad-\xff.sql')
        byte_path.write_text(fixture.replace('starts = 8', 'starts = 9'))
        byte_failure = subprocess.run([CLI, '--diagnostics=json', 'parse', byte_path], capture_output=True, text=True)
        assert byte_failure.returncode == 1 and not byte_failure.stdout
        detail = json.loads(byte_failure.stderr)
        assert detail['code'] == 'application.invalid_query_budget'
        assert detail['location']['source_encoding'] == 'escaped_bytes'
        assert detail['location']['source'].endswith('bad-\\xff.sql')
        assert detail['location']['line'] == '8'
        nested_path = directory / 'nested.sql'
        nested_path.write_text(fixture.replace('SELECT id, value FROM items', 'SELECT id FROM'))
        nested_failure = subprocess.run([CLI, '--diagnostics=json', 'parse', nested_path], capture_output=True, text=True)
        nested = json.loads(nested_failure.stderr)
        assert nested_failure.returncode == 1 and nested['location']['line'] == '8'
        positions = [fact['value']['location'] for fact in nested['facts'] if fact and fact['field'] == 'expression']
        assert len(positions) == 1 and positions[0]['line'] == '1' and positions[0]['source'] is None
        with open('/dev/full', 'wb') as full:
            output_failure = subprocess.run([CLI, '--diagnostics=json', 'schema'], stdout=full, stderr=subprocess.PIPE, text=True)
        assert output_failure.returncode == 1
        detail = json.loads(output_failure.stderr)
        assert detail['stage'] == 'output' and detail['outcome'] == 'not_submitted' and detail['location'] is None
        assert any(fact and fact['field'] == 'completion' and fact['value'] == {'boolean':False} for fact in detail['facts'])
        assert not any(fact and fact['field'] in ('name','option','expression') for fact in detail['facts'])
        missing_binding = json.loads(json.dumps(model))
        missing_binding['screens'][1]['binding'] = 'missing'
        run('format', json.dumps(missing_binding), directory, False,
            ('screen: "explore"', 'option: "binding"', 'Referenced name: "missing"'))
        for changed in [{**model, 'unknown': 1}, {**model, 'realm': 9007199254740992},
                        {**model, 'revision': '018'}]:
            run('format', json.dumps(changed), directory, False)
        documentation = (ROOT / 'docs/handbook/reference/sql/application.md').read_text()
        programs = re.findall(r'^```sql\n(.*?)^```', documentation, re.M | re.S)
        assert programs, 'missing complete application documentation example'
        for source in programs:
            documented_model = json.loads(run('parse', source, directory))
            assert documented_model == reference(source)
            canonical = run('format', json.dumps(documented_model), directory)
            assert json.loads(run('parse', canonical, directory)) == documented_model
    schema = json.loads(subprocess.check_output([CLI, 'schema']))
    assert schema['$defs']['Definition']['properties']['revision']['type'] == 'string'
    query = schema['$defs']['Binding']['properties']['source']['oneOf'][1]
    assert query['properties']['query']['properties']['sql']['maxLength'] == 4096
    print('Application grammar: independent model agreement, visual round-trip, full-width revision, complete rejection passed.')
    print(f'Application documentation: {len(programs)} complete programs compile and round-trip.')


if __name__ == '__main__':
    main()
