"""Independent finite expectations for the admitted nominal program fragment."""
import copy

from query.application_source.verify import execute, same

DOMAINS = {'machine': 'example.machine-id', 'site': 'example.site-id'}


def cases():
    for raw in (-7, 7):
        for domain in DOMAINS:
            for late_guard in (False, True):
                yield {'raw': raw, 'domain': domain, 'late_guard': late_guard}


def source(case):
    # A data description, not a resolver or an alternate program interpreter.
    return (f"CREATE DOMAIN Id AS BIGINT IDENTITY '{DOMAINS[case['domain']]}'; "
            "CREATE MODULE Run(ty TYPE, expected Id) AS BEGIN "
            "CREATE PUBLIC QUEUE jobs (id $ty NOT NULL); "
            "CREATE PUBLIC TABLE lookup (id $ty PRIMARY KEY); "
            "CREATE PUBLIC TABLE state (id $ty PRIMARY KEY); "
            "CREATE PUBLIC STREAM events (id $ty NOT NULL); "
            "CREATE PUBLIC DATAFLOW process FROM QUEUE jobs AS request AS BEGIN "
            "LET alias = request.id; "
            "BEGIN ATOMIC "
            "LET found = SELECT id FROM lookup WHERE id = alias; "
            "REQUIRE found IS NOT NULL ELSE 'Missing'; "
            + ("REQUIRE alias = $expected ELSE 'Wrong'; " if not case['late_guard'] else '')
            + "INSERT INTO state VALUES (alias) ON CONFLICT (id) DO ASSERT SAME ROW; "
            + ("REQUIRE alias = $expected ELSE 'Wrong'; " if case['late_guard'] else '')
            + "PRODUCE INTO events VALUES (alias); END; END; END; "
            f"CREATE TARGET default AS BEGIN USE Run(TYPE Id, Id({case['raw']})); END;")


def scalar(domain=None, nullable=False):
    return dict(kind='integer', nullable=nullable, domain=domain, fields=[])


def expected_nodes(case):
    text = source(case)
    domain = DOMAINS[case['domain']]
    record = dict(kind='record', nullable=False, domain=None,
                  fields=[dict(name='id', value=scalar(domain))])
    optional = {**record, 'nullable': True, 'fields': record['fields'][:1]}
    boolean = dict(kind='boolean', nullable=False, domain=None, fields=[])
    def node(at, kind, type_, delta=0):
        return dict(source_offset=text.index(at) + delta, kind=kind, type=type_)
    nodes = [node('request.id;', 'name', record), node('request.id;', 'field', scalar(domain)),
             node('LET alias', 'binding', scalar(domain)),
             node('id = alias', 'name', scalar(domain)), node('alias;', 'name', scalar(domain)),
             node('id = alias', 'binary', boolean), node('LET found', 'binding', optional),
             node('found IS', 'name', optional), node('found IS', 'unary', boolean)]
    guard = [node("alias = $expected", 'name', scalar(domain))]
    if case['raw'] < 0:
        # Negative literal is a unary AST with an ordinary positive child. Both
        # map to the same source hole; only the complete expression is nominal.
        guard += [node('$expected ELSE', 'integer', scalar()), node('$expected ELSE', 'unary', scalar(domain))]
    else:
        guard += [node('$expected ELSE', 'integer', scalar(domain))]
    guard += [node('alias = $expected', 'binary', boolean)]
    insert = [node('alias) ON', 'name', scalar(domain))]
    nodes += insert + guard if case['late_guard'] else guard + insert
    nodes += [node('alias); END;', 'name', scalar(domain))]
    return nodes


def expected_events(case):
    domain = DOMAINS[case['domain']]
    kinds = [('acquire', 'jobs'), ('let', None), ('atomic_begin', None), ('read', 'lookup'), ('require', None)]
    kinds += [('insert', 'state'), ('require', None)] if case['late_guard'] else [('require', None), ('insert', 'state')]
    kinds += [('append', 'events'), ('atomic_end', None)]
    return [dict(kind=kind, resource=resource, columns=[] if resource is None else [dict(column='id', domain=domain)])
            for kind, resource in kinds]


def expected_sql(case):
    lines = ['CREATE QUEUE JOBS ( ID BIGINT NOT NULL )', 'CREATE TABLE LOOKUP ( ID BIGINT PRIMARY KEY )',
             'CREATE TABLE STATE ( ID BIGINT PRIMARY KEY )', 'CREATE STREAM EVENTS ( ID BIGINT NOT NULL )']
    guard = f"REQUIRE ALIAS = {case['raw']} ELSE 'Wrong' ; "
    insert = 'INSERT INTO STATE VALUES ( ALIAS ) ON CONFLICT ( ID ) DO ASSERT SAME ROW ; '
    lines += ["CREATE DATAFLOW PROCESS FROM QUEUE JOBS AS REQUEST AS BEGIN LET ALIAS = REQUEST . ID ; BEGIN ATOMIC "
              "LET FOUND = SELECT ID FROM LOOKUP WHERE ID = ALIAS ; REQUIRE FOUND IS NOT NULL ELSE 'Missing' ; "
              + (insert + guard if case['late_guard'] else guard + insert)
              + 'PRODUCE INTO EVENTS VALUES ( ALIAS ) ; END ; END']
    return lines


def compare(case, product):
    same(expected_sql(case), [step['sql'] for step in product['steps']], 'program ordinary SQL')
    same(''.join(sql + ';\n' for sql in expected_sql(case)), product['sql'], 'complete program SQL')
    evidence = product['steps'][4]['checked']['program']
    assert len({node['id'] for node in evidence['nodes']}) == len(evidence['nodes']), 'duplicate expression/binding ID'
    same(expected_nodes(case), [{k: v for k, v in node.items() if k != 'id'} for node in evidence['nodes']], 'complete source annotations')
    events = [{k: v for k, v in event.items() if k not in ('node', 'source_offset', 'columns')} |
              {'columns': [{k: v for k, v in col.items() if k != 'value'} for col in event['columns']]}
              for event in evidence['events']]
    same(expected_events(case), events, 'ordered program events')
    by_id = {node['id']: node for node in evidence['nodes']}
    text = source(case)
    for event in evidence['events']:
        if event['kind'] in ('insert', 'append'):
            value = by_id[event['columns'][0]['value']]
            at = 'alias) ON' if event['kind'] == 'insert' else 'alias); END;'
            same(text.index(at), value['source_offset'], 'write expression association')
        else:
            assert all(column['value'] is None for column in event['columns'])


def lean_examples(cases_):
    lines = []
    names = set()
    for i, case in enumerate(cases_):
        label = f'program{i}'
        domain = DOMAINS[case['domain']]
        ty = f'⟨.integer, some "{domain}"⟩'
        guard = '.guard (.equal (.var .head) (.literal input))'
        insert = '.write .insert ⟨"state"⟩ (.var .head)'
        events = ['.boundary .acquire "jobs"', '.boundary .atomicBegin ""', '.boundary .read "lookup"']
        events += [insert, guard] if case['late_guard'] else [guard, insert]
        events += ['.write .append ⟨"events"⟩ (.var .head)', '.boundary .atomicEnd ""']
        want = []
        for event_index, event in enumerate(expected_events(case)):
            if event['kind'] == 'let' or event_index == 4:
                # LET and nullable-presence checking belong to the shared physical
                # binder; this fragment models the same-domain value guard.
                continue
            kind = {'atomic_begin': 'atomicBegin', 'atomic_end': 'atomicEnd'}.get(event['kind'], event['kind'])
            annotation = f'some {ty}' if kind in ('insert', 'append') else 'some ⟨.boolean, none⟩' if kind == 'require' else 'none'
            value = f'some (.integer ({case["raw"]}))' if kind in ('insert', 'append') else 'some (.boolean true)' if kind == 'require' else 'none'
            want.append(f'⟨.{kind}, "{event["resource"] or ""}", {annotation}, {value}⟩')
        # Explicit event model: no production projection enters the Lean input.
        lines += [f'def {label}Type : SourceType := {ty}',
                  f'def {label}Input : Value {label}Type := ⟨.integer ({case["raw"]}), rfl⟩',
                  f'def {label}Events (input : Value {label}Type) : List (SourceEvent [{label}Type]) := [{", ".join(events)}]']
        name = f'{label}_ordered'
        lines += [f'theorem {name} : (({label}Events {label}Input).map (SourceEvent.substitute {label}Input)).map (SourceEvent.eval emptyEnv) = [{", ".join(want)}] := by decide', f'#print axioms {name}']
        names.add(name)
    return '\n'.join(lines) + '\n', names


def run(driver, destination, must_fail):
    descriptors = list(cases())
    outputs = execute(driver, [dict(name=f'program-{i}', source=source(case), compile='build') for i, case in enumerate(descriptors)], destination, 'program-products')
    for case, output in zip(descriptors, outputs):
        assert 'product' in output, output
        compare(case, output['product'])
    controls = []
    for label in ('dropped domain', 'foreign domain', 'reordered guard', 'missing boundary', 'changed SQL'):
        damaged = copy.deepcopy(outputs[0]['product'])
        evidence = damaged['steps'][4]['checked']['program']
        if label in ('dropped domain', 'foreign domain'):
            evidence['nodes'][1]['type']['domain'] = None if label == 'dropped domain' else DOMAINS['site']
        elif label == 'reordered guard':
            evidence['events'][5:7] = reversed(evidence['events'][5:7])
        elif label == 'missing boundary':
            evidence['events'].pop()
        else:
            damaged['steps'][4]['sql'] = damaged['steps'][4]['sql'].replace("'Missing'", "'Wrong'")
        controls.append(must_fail(label, lambda: compare(descriptors[0], damaged)))
    return len(outputs), controls
