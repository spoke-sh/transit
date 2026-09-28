"""Independent ANTLR/typed-model agreement through the actual application CLI."""
import json
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


def run(command, data, directory, success=True):
    path = directory / 'input'
    path.write_text(data)
    result = subprocess.run([CLI, command, path], capture_output=True, text=True)
    assert (result.returncode == 0) == success, result.stderr
    if not success:
        assert not result.stdout, 'invalid program leaked partial output'
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
        for changed in [{**model, 'unknown': 1}, {**model, 'realm': 9007199254740992},
                        {**model, 'revision': '018'}]:
            run('format', json.dumps(changed), directory, False)
    schema = json.loads(subprocess.check_output([CLI, 'schema']))
    assert schema['$defs']['Definition']['properties']['revision']['type'] == 'string'
    query = schema['$defs']['Binding']['properties']['source']['oneOf'][1]
    assert query['properties']['query']['properties']['sql']['maxLength'] == 4096
    print('Application grammar: independent model agreement, visual round-trip, full-width revision, complete rejection passed.')


if __name__ == '__main__':
    main()
