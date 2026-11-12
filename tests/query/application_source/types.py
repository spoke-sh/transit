"""Bounded source/Lean/checked-operand/ordinary-SQL correspondence, not a compiler proof."""
import copy
import hashlib
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

from runner import capture
from runner.paths import ROOT
from query.application_source.verify import execute, same
from query.application_source import program_types

SPEC = ROOT / 'contracts/application-source/TypedTarget.lean'
THEOREMS = {'nominal_substitution', 'exhaustive_selection', 'specialization_preservation', 'projection_substitution', 'program_substitution', 'ordered_erasure'}
DOMAINS = {'machine': 'example.machine-id', 'site': 'example.site-id'}


def audit(source, output, required):
    names = re.findall(r'^#print axioms (\w+)$', source, re.M)
    assert len(names) == len(required) and set(names) == required, 'theorem inventory'
    assert 'sorryAx' not in output and 'warning:' not in output, 'incomplete proof'
    lines = re.findall(r"^'([^']+)' (?:does not depend on any axioms|depends on axioms: \[([^\]]*)\])$", output, re.M)
    assert len(lines) == len(required) and {name for name, _ in lines} == required, 'axiom output coverage'
    for name, axioms in lines:
        allowed = {'propext', 'Quot.sound'} if name == 'exhaustive_selection' or name.endswith('_selection') else {'propext'}
        assert not axioms or set(axioms.split(', ')) <= allowed, 'unexpected axiom'


def lean(path):
    result = subprocess.run(['lean', str(path)], cwd=ROOT, text=True, capture_output=True, timeout=120)
    assert result.returncode == 0 and not result.stderr, result.stdout + result.stderr
    return result.stdout


def descriptors():
    # An independent finite model, with both constructors, equal raw values,
    # signed values, permuted source arms and distinct explicit Table bindings.
    for raw in (-7, 0, 7, 31):
        for target in ('machine', 'site'):
            for reverse in (False, True):
                index = len(str(raw)) + int(reverse)
                yield {'raw': raw, 'target': target, 'reverse': reverse,
                       'tables': {'machine': f'machines_{index}', 'site': f'sites_{index}'}}


def expected(case):
    target = case['target']
    return [{'table': case['tables'][target], 'domain': DOMAINS[target], 'value': value}
            for value in (case['raw'], case['raw'] + 100)]


def program(case):
    definitions = "CREATE DOMAIN MachineId AS BIGINT IDENTITY 'example.machine-id'; CREATE DOMAIN SiteId AS BIGINT IDENTITY 'example.site-id'; CREATE VARIANT Target AS (Machine(id MachineId), Site(id SiteId)); "
    definitions += 'CREATE MODULE Rows(name IDENTIFIER, element TYPE) AS BEGIN CREATE PUBLIC TABLE $name (id $element PRIMARY KEY); EXPORT TABLE $name AS rows; END; '
    for kind in ('Machine', 'Site'):
        definitions += f'CREATE MODULE Put{kind}(rows TABLE(id {kind}Id PRIMARY KEY), id {kind}Id) AS BEGIN INSERT INTO $rows VALUES ($id); END; '
    definitions += 'CREATE MODULE Route(value Target, machines TABLE(id MachineId PRIMARY KEY), sites TABLE(id SiteId PRIMARY KEY)) AS BEGIN MATCH value '
    for kind in (('Site', 'Machine') if case['reverse'] else ('Machine', 'Site')):
        table = 'machines' if kind == 'Machine' else 'sites'
        definitions += f'WHEN Target.{kind}(id) THEN USE Put{kind}({table}, id); USE Put{kind}({table}, {kind}Id({case["raw"] + 100})); '
    definitions += 'END MATCH; END; CREATE TARGET default AS BEGIN '
    for kind in ('Machine', 'Site'):
        table = 'machines' if kind == 'Machine' else 'sites'
        definitions += f"USE Rows(NAME '{case['tables'][kind.lower()]}', TYPE {kind}Id) AS {table}; "
    kind = case['target'].title()
    return definitions + f'USE Route(Target.{kind}({kind}Id({case["raw"]})), machines.rows, sites.rows); END;'


def actions(product):
    result = []
    assert len(product['steps']) == 4, 'ordered action coverage'
    for step in product['steps'][2:]:
        checked = step['checked']
        assert len(checked['operands']) == 1 and len(checked['columns']) == 1
        operand = checked['operands'][0]
        assert operand['role'] == 'assignment' and operand['column'] == 'id'
        assert checked['columns'] == [{'name': 'id', 'domain': operand['domain']}]
        result.append({'table': checked['table'], 'domain': operand['domain'], 'value': operand['value']['integer']})
    return result


def compare(case, product):
    want = expected(case)
    same(want, actions(product), 'checked nominal actions')
    sql = [f'CREATE TABLE "{case["tables"][kind]}" ( ID BIGINT PRIMARY KEY )' for kind in ('machine', 'site')]
    sql += [f'INSERT INTO "{action["table"]}" VALUES ( {action["value"]} )' for action in want]
    same(sql, [step['sql'] for step in product['steps']], 'ordinary SQL actions')
    same(''.join(line + ';\n' for line in sql), product['sql'], 'complete SQL')


def examples(cases):
    lines = [SPEC.read_text(), 'def emptyEnv : Env [] := fun index => nomatch index']
    names = set(THEOREMS)
    for index, case in enumerate(cases):
        label = f'case{index}'
        # No production output enters these Lean programs or expected actions.
        lines += [f'def {label}Sig (tag : Fin 2) : SourceType := ⟨.integer, some (if tag.val = 0 then "example.machine-id" else "example.site-id")⟩',
                  f'def {label}Arms : Arms [] {label}Sig := fun tag => [',
                  f'  .insert (type := {label}Sig tag) ⟨if tag.val = 0 then "{case["tables"]["machine"]}" else "{case["tables"]["site"]}"⟩ (.var .head),',
                  f'  .insert (type := {label}Sig tag) ⟨if tag.val = 0 then "{case["tables"]["machine"]}" else "{case["tables"]["site"]}"⟩ (.literal ⟨.integer ({case["raw"] + 100}), rfl⟩)]',
                  f'def {label}Value : Variant {label}Sig := ⟨⟨{0 if case["target"] == "machine" else 1}, by decide⟩, ⟨.integer ({case["raw"]}), rfl⟩⟩']
        tags = [1, 0] if case['reverse'] else [0, 1]
        labels = '[' + ', '.join(f'⟨{tag}, by decide⟩' for tag in tags) + ']'
        name = f'{label}_selection'
        lines += [f'def {label}Labels : List (Fin 2) := {labels}',
                  f'theorem {name} : {label}Labels.filter (fun tag => decide (tag = {label}Value.tag)) = [{label}Value.tag] :=',
                  f'  (exhaustive_selection {label}Value {label}Arms {label}Labels (by decide) (by decide)).1',
                  f'#print axioms {name}']
        names.add(name)
        want = ', '.join(f'⟨"{a["table"]}", ⟨.integer, some "{a["domain"]}"⟩, .integer ({a["value"]})⟩' for a in expected(case))
        for suffix, expression in [('source', f'sourceActions emptyEnv {label}Value {label}Arms'),
                                   ('bound', f'boundActions emptyEnv (specialize {label}Value {label}Arms)')]:
            name = f'{label}_{suffix}'
            lines += [f'theorem {name} : {expression} = [{want}] := by decide', f'#print axioms {name}']
            names.add(name)
    programs, program_names = program_types.lean_examples(list(program_types.cases()))
    return '\n'.join(lines) + '\n' + programs, names | program_names


def must_fail(label, operation):
    try:
        operation()
    except AssertionError:
        return label
    raise AssertionError(f'negative control passed: {label}')


def inventory():
    source = SPEC.read_text()
    assert set(re.findall(r'^theorem (\w+)', source, re.M)) == THEOREMS, 'source theorem inventory'
    output = "\n".join(f"'{name}' depends on axioms: [propext]" for name in sorted(THEOREMS))
    audit(source, output, THEOREMS)
    controls = [
        must_fail('missing theorem', lambda: audit(source.replace('#print axioms nominal_substitution', ''), output, THEOREMS)),
        must_fail('incomplete proof', lambda: audit(source, output.replace('[propext]', '[sorryAx]'), THEOREMS)),
        must_fail('unreviewed axiom', lambda: audit(source, output.replace('[propext]', '[Classical.choice]'), THEOREMS)),
        must_fail('missing evidence', lambda: audit(source, '', THEOREMS)),
    ]
    return controls


def main():
    driver = Path(sys.argv[1]).resolve()
    parent = ROOT / '.cache/verification/application-source-types'
    parent.mkdir(parents=True, exist_ok=True)
    destination = Path(tempfile.mkdtemp(prefix='run-', dir=parent))
    cases = list(descriptors())
    meta = {**capture.provenance(ROOT), 'completed': False, 'cases': cases, 'spec_sha256': hashlib.sha256(SPEC.read_bytes()).hexdigest(),
            'driver_sha256': hashlib.sha256(driver.read_bytes()).hexdigest(),
            'lean': subprocess.check_output(['lean', '--version'], text=True).strip(),
            'lean_executable': capture.identity(Path(shutil.which('lean')).resolve()),
            'inputs': {path: capture.identity(ROOT / path) for path in (
                'tests/query/application_source/types.py', 'tests/query/application_source/program_types.py', 'tests/query/application_source/driver.zig',
                'packages/zig/transit-compiler/src/Compiler.zig', 'packages/zig/transit-compiler/src/Syntax.zig',
                'packages/zig/transit-compiler/src/SourceTypes.zig', 'packages/zig/transit-compiler/src/ProgramAnnotations.zig', 'packages/zig/transit-compiler/src/TypedOperands.zig')}}
    capture.write_json(destination / 'evidence.json', meta)
    print(f'typed source evidence: {destination}', flush=True)
    inventory()
    proof = lean(SPEC)
    (destination / 'axioms.txt').write_text(proof)
    audit(SPEC.read_text(), proof, THEOREMS)
    finite, names = examples(cases)
    path = destination / 'Correspondence.lean'
    path.write_text(finite)
    result = lean(path)
    (destination / 'finite-axioms.txt').write_text(result)
    audit(finite, result, names)
    inputs = [{'name': f'case-{i}', 'source': program(case), 'compile': 'build'} for i, case in enumerate(cases)]
    outputs = execute(driver, inputs, destination, 'typed-products')
    for case, output in zip(cases, outputs):
        assert 'product' in output, output
        compare(case, output['product'])
    controls = []
    incomplete = destination / 'Incomplete.lean'
    incomplete.write_text(SPEC.read_text().replace('  induction expr with\n  | literal => rfl\n  | var index => cases index <;> rfl\n  | equal left right ihl ihr => simp only [Expr.substitute, Expr.eval, ihl, ihr]', '  sorry'))
    assert incomplete.read_text() != SPEC.read_text(), 'incomplete-proof control did not mutate its owner'
    incomplete_output = lean(incomplete)
    controls.append(must_fail('executed incomplete proof', lambda: audit(incomplete.read_text(), incomplete_output, THEOREMS)))
    controls.append(must_fail('missing theorem', lambda: audit(SPEC.read_text().replace('#print axioms nominal_substitution', ''), proof, THEOREMS)))
    controls.append(must_fail('sorry axiom', lambda: audit(SPEC.read_text(), proof.replace('[propext]', '[propext, sorryAx]'), THEOREMS)))
    controls.append(must_fail('unreviewed axiom', lambda: audit(SPEC.read_text(), proof.replace('[propext]', '[Classical.choice]'), THEOREMS)))
    base = outputs[0]['product']
    for label in ('swapped domain', 'swapped table', 'wrong value', 'missing action', 'changed SQL'):
        damaged = copy.deepcopy(base)
        if label == 'swapped domain':
            damaged['steps'][2]['checked']['operands'][0]['domain'] = DOMAINS['site']
            damaged['steps'][2]['checked']['columns'][0]['domain'] = DOMAINS['site']
        elif label == 'swapped table':
            damaged['steps'][2]['checked']['table'] = cases[0]['tables']['site']
        elif label == 'wrong value':
            damaged['steps'][2]['checked']['operands'][0]['value']['integer'] += 1
        elif label == 'missing action':
            damaged['steps'].pop()
        else:
            damaged['steps'][2]['sql'] += ' WHERE FALSE'
        controls.append(must_fail(label, lambda: compare(cases[0], damaged)))
    # An inconsistent constructor payload is not accepted merely because the
    # erased integer agrees. Check a real rejected build for each constructor.
    refused = []
    for index, case in enumerate(cases[:4]):
        target = case['target'].title()
        other = 'Site' if target == 'Machine' else 'Machine'
        bad = program(case).replace(f'Target.{target}({target}Id(', f'Target.{target}({other}Id(')
        refused.append({'name': f'refused-{index}', 'source': bad, 'compile': 'build'})
    for output in execute(driver, refused, destination, 'typed-refusals'):
        same('SourceTypeMismatch', output.get('compile_error'))
        assert 'product' not in output
    programs, program_controls = program_types.run(driver, destination, must_fail)
    controls += program_controls
    meta.update(programs_compared=programs, completed=True, named_laws=len(THEOREMS), finite_equalities=len(names) - len(THEOREMS),
                compared=len(outputs), refused=len(refused), negative_controls=controls)
    capture.write_json(destination / 'evidence.json', meta)
    print(f'PASS {len(THEOREMS)} Lean laws, {len(names) - len(THEOREMS)} finite equalities, {len(outputs)} typed/SQL and {programs} program comparisons, {len(refused)} refusals, {len(controls)} negative controls')


if __name__ == '__main__':
    if sys.argv[1:] == ['--check-inventory']:
        controls = inventory()
        print(f'Source proof inventory: {len(THEOREMS)} laws, {len(controls)} audit controls; Lean was not executed.')
    else:
        main()
