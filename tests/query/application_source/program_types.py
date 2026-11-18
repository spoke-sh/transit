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
    for i, case in enumerate(helper_cases()):
        label = f'helper{i}'
        domain = DOMAINS[case['domain']]
        ty = f'⟨.integer, some "{domain}"⟩'
        raw = case['raw']
        lines += [
            f'def {label}Type : SourceType := {ty}',
            f'def {label}Val : Value {label}Type := ⟨.integer ({raw}), rfl⟩',
            f'def {label}FiveEnv : FiveEnv [] := fun index => nomatch index',
            f'def {label}FnBody : FiveExpr [{label}Type] {label}Type := .branch (.isNull (.var .head)) (.const .null) (.var .head)',
        ]
        fn_val_name = f'{label}_fn_value'
        fn_null_name = f'{label}_fn_null'
        lines += [
            f'theorem {fn_val_name} : (FiveExpr.substExpr (.const (.value {label}Val)) {label}FnBody).eval {label}FiveEnv = .value {label}Val := by decide',
            f'#print axioms {fn_val_name}',
            f'theorem {fn_null_name} : (FiveExpr.substExpr (.const .null) {label}FnBody).eval {label}FiveEnv = .null := by decide',
            f'#print axioms {fn_null_name}',
        ]
        names.update((fn_val_name, fn_null_name))

        g_missing = '⟨.literal ⟨.boolean false, rfl⟩, "Missing"⟩'
        g_wrong = '⟨.literal ⟨.boolean false, rfl⟩, "Wrong"⟩'
        seq = f'[{g_wrong}, {g_missing}]' if case['swap_guards'] else f'[{g_missing}, {g_wrong}]'
        want_refusal = '"Wrong"' if case['swap_guards'] else '"Missing"'
        guard_name = f'{label}_guard_order'
        lines += [
            f'theorem {guard_name} : runGuards emptyEnv {seq} = .refuse {want_refusal} := by decide',
            f'#print axioms {guard_name}',
        ]
        names.add(guard_name)

        lines += [
            f'def {label}Callee : List (AtomicStep [{label}Type]) := ['
            f'.mutate (.insert (type := {label}Type) ⟨"state"⟩ (.var .head)), '
            f'.mutate (.insert (type := {label}Type) ⟨"events"⟩ (.var .head))]',
            f'def {label}AcceptCont : List (AtomicStep []) := [.check ⟨.literal ⟨.boolean true, rfl⟩, "PostCall"⟩]',
            f'def {label}RejectCont : List (AtomicStep []) := [.check ⟨.literal ⟨.boolean false, rfl⟩, "PostCall"⟩]',
        ]
        commit_name = f'{label}_proc_commit'
        rollback_name = f'{label}_proc_rollback'
        want_writes = f'[⟨"state", {ty}, .integer ({raw})⟩, ⟨"events", {ty}, .integer ({raw})⟩]'
        lines += [
            f'theorem {commit_name} : runAtomic emptyEnv (({label}Callee.map (AtomicStep.substitute {label}Val)) ++ {label}AcceptCont) = .commit {want_writes} := by decide',
            f'#print axioms {commit_name}',
            f'theorem {rollback_name} : runAtomic emptyEnv (({label}Callee.map (AtomicStep.substitute {label}Val)) ++ {label}RejectCont) = .rollback "PostCall" := by decide',
            f'#print axioms {rollback_name}',
        ]
        names.update((commit_name, rollback_name))
        return_name = f'{label}_proc_return'
        refuse_name = f'{label}_proc_no_return'
        lines += [
            f'theorem {return_name} : returned (evalProcedureCall emptyEnv {label}Val {label}Callee {label}AcceptCont) {label}Val = some {label}Val := by decide',
            f'#print axioms {return_name}',
            f'theorem {refuse_name} : returned (evalProcedureCall emptyEnv {label}Val {label}Callee {label}RejectCont) {label}Val = none := by decide',
            f'#print axioms {refuse_name}',
        ]
        names.update((return_name, refuse_name))
    for i, case in enumerate(diamond_cases()):
        label = f'diamond{i}'
        domain = DOMAINS[case['domain']]
        ty = f'⟨.integer, some "{domain}"⟩'
        raw = case['raw']
        follow = raw + 100
        shared_name = f'{label}_shared'
        distinct_name = f'{label}_unshared_distinct'
        lines += [
            f'def {label}Type : SourceType := {ty}',
            f'def {label}LeftVal : Value {label}Type := ⟨.integer ({raw}), rfl⟩',
            f'def {label}RightVal : Value {label}Type := ⟨.integer ({follow}), rfl⟩',
            f'def {label}Ctor : ModuleCtor [] (Table {label}Type) := fun _ => ⟨[⟨"shared_tenants", {ty}, .integer 0⟩], ⟨"shared_tenants"⟩⟩',
            f'def {label}Left : ModuleConsumer [] {label}Type (Table {label}Type) := fun tbl => [.insert tbl (.var .head)]',
            f'def {label}Right : ModuleConsumer [] {label}Type (Table {label}Type) := fun tbl => [.insert tbl (.var .head)]',
            f'theorem {shared_name} : evalSharedDiamond emptyEnv {label}Ctor {label}LeftVal {label}Left {label}RightVal {label}Right = '
            f'[⟨"shared_tenants", {ty}, .integer 0⟩, ⟨"shared_tenants", {ty}, .integer ({raw})⟩, ⟨"shared_tenants", {ty}, .integer ({follow})⟩] := by decide',
            f'#print axioms {shared_name}',
            f'theorem {distinct_name} : evalSharedDiamond emptyEnv {label}Ctor {label}LeftVal {label}Left {label}RightVal {label}Right ≠ '
            f'evalUnsharedPair emptyEnv {label}Ctor {label}LeftVal {label}Left {label}RightVal {label}Right := by decide',
            f'#print axioms {distinct_name}',
        ]
        names.update((shared_name, distinct_name))
    return '\n'.join(lines) + '\n', names


def diamond_cases():
    for raw in (-7, 7):
        for domain in DOMAINS:
            yield {'raw': raw, 'domain': domain}


def diamond_request(index, case, bad_domain=False):
    domain = DOMAINS[case['domain']]
    other = DOMAINS['site' if case['domain'] == 'machine' else 'machine']
    raw = case['raw']
    follow = raw + 100
    right_arg = f'other_mod.OtherId({follow})' if bad_domain else f'tenancy_build.TenantId({follow})'
    right_imports = (
        "IMPORT MODULE tenancy_build FROM '../tenancy/build.transit'; "
        + ("IMPORT MODULE other_mod FROM '../other/build.transit'; " if bad_domain else '')
    )
    right_param_ty = 'other_mod.OtherId' if bad_domain else 'tenancy_build.TenantId'
    files = [
        {
            'path': 'apps/build.transit',
            'text': (
                "IMPORT MODULE tenancy_build FROM './tenancy/build.transit'; "
                "IMPORT MODULE left_mod FROM './left/build.transit'; "
                "IMPORT MODULE right_mod FROM './right/build.transit'; "
                + ("IMPORT MODULE other_mod FROM './other/build.transit'; " if bad_domain else '')
                + "EXPORT MODULE application(bindings ROW(tenancy SCHEMA_BINDING)) AS BEGIN "
                "LET tenancy_inst = USE MODULE tenancy_build.application(schema => bindings.tenancy, id_type => TYPE tenancy_build.TenantId); "
                f"LET left_inst = USE MODULE left_mod.application(tenancy => tenancy_inst, initial => tenancy_build.TenantId({raw})); "
                f"LET right_inst = USE MODULE right_mod.application(tenancy => tenancy_inst, followup => {right_arg}); "
                "END; "
                "LET control = USE MODULE application(bindings => ROW(tenancy => SCHEMA_BINDING('public'))); "
                "EXPORT TARGET app AS SQL OF control;"
            ),
        },
        {
            'path': 'apps/tenancy/build.transit',
            'text': (
                f"CREATE PUBLIC DOMAIN TenantId AS BIGINT IDENTITY '{domain}'; "
                "EXPORT MODULE application(schema SCHEMA_BINDING, id_type TYPE) AS BEGIN "
                "BIND SCHEMA tenancy TO schema; "
                "DECLARE FROM './tables.transit'; "
                "EXPORT TABLE shared_tenants; END;"
            ),
        },
        {
            'path': 'apps/tenancy/tables.transit',
            'text': "CREATE PUBLIC TABLE shared_tenants (id $id_type PRIMARY KEY);",
        },
        {
            'path': 'apps/left/build.transit',
            'text': (
                "IMPORT MODULE tenancy_build FROM '../tenancy/build.transit'; "
                "EXPORT MODULE application(tenancy MODULE OF tenancy_build.application, initial tenancy_build.TenantId) AS BEGIN "
                "USE MODULE tenancy; "
                "INSERT INTO shared_tenants VALUES ($initial); END;"
            ),
        },
        {
            'path': 'apps/right/build.transit',
            'text': (
                right_imports
                + f"EXPORT MODULE application(tenancy MODULE OF tenancy_build.application, followup {right_param_ty}) AS BEGIN "
                "USE MODULE tenancy; "
                "INSERT INTO shared_tenants VALUES ($followup); END;"
            ),
        },
    ]
    if bad_domain:
        files.append({'path': 'apps/other/build.transit', 'text': f"CREATE PUBLIC DOMAIN OtherId AS BIGINT IDENTITY '{other}';"})
    return {
        'name': f'diamond-{index}',
        'source': "IMPORT MODULE apps FROM './apps/build.transit'; EXPORT DEFAULT TARGET app; EXPORT TARGET app = apps.app;",
        'compile': 'build',
        'files': files,
    }


def compare_diamond(case, product):
    domain = DOMAINS[case['domain']]
    raw = case['raw']
    follow = raw + 100
    want_sql = [
        'CREATE TABLE SHARED_TENANTS ( ID BIGINT PRIMARY KEY )',
        f'INSERT INTO SHARED_TENANTS VALUES ( {raw} )',
        f'INSERT INTO SHARED_TENANTS VALUES ( {follow} )',
    ]
    same(want_sql, [step['sql'] for step in product['steps']], 'diamond single-DDL ordinary SQL')
    same(''.join(line + ';\n' for line in want_sql), product['sql'], 'complete diamond SQL')
    for step, expected_val in zip(product['steps'][1:], (raw, follow)):
        checked = step['checked']
        same('shared_tenants', checked['table'], 'diamond exported table binding')
        same([{'name': 'id', 'domain': domain}], checked['columns'], 'diamond column domain')
        same(domain, checked['operands'][0]['domain'], 'diamond operand domain')
        same(expected_val, checked['operands'][0]['value']['integer'], 'diamond operand scalar')


def helper_cases():
    for raw in (-7, 7):
        for domain in DOMAINS:
            for swap_guards in (False, True):
                yield {'raw': raw, 'domain': domain, 'swap_guards': swap_guards}


def helper_source(case):
    g1 = 'CHECK GUARD guard_present(lookup, clean); '
    g2 = 'CHECK GUARD guard_expected(clean, $expected); '
    guards = (g2 + g1) if case['swap_guards'] else (g1 + g2)
    return (
        f"CREATE DOMAIN Id AS BIGINT IDENTITY '{DOMAINS[case['domain']]}'; "
        "CREATE FUNCTION pass_id(id Id) RETURNS Id AS BEGIN RETURN id; END; "
        "CREATE GUARD guard_present(rows TABLE(id Id PRIMARY KEY), target Id) AS BEGIN "
        "LET found = SELECT id FROM rows WHERE id = target; "
        "REQUIRE found IS NOT NULL ELSE 'Missing'; END; "
        "CREATE GUARD guard_expected(actual Id, expected Id) AS BEGIN "
        "REQUIRE actual = expected ELSE 'Wrong'; END; "
        "CREATE PROCEDURE write_both(state TABLE(id Id PRIMARY KEY), events STREAM(id Id NOT NULL), id Id) AS BEGIN ATOMIC "
        "INSERT INTO state VALUES (id) ON CONFLICT (id) DO ASSERT SAME ROW; "
        "PRODUCE INTO events VALUES (id); END; "
        "CREATE MODULE Run(ty TYPE, expected Id) AS BEGIN "
        "CREATE PUBLIC QUEUE jobs (id $ty NOT NULL); "
        "CREATE PUBLIC TABLE lookup (id $ty PRIMARY KEY); "
        "CREATE PUBLIC TABLE state (id $ty PRIMARY KEY); "
        "CREATE PUBLIC STREAM events (id $ty NOT NULL); "
        "CREATE PUBLIC DATAFLOW process FROM QUEUE jobs AS request AS BEGIN "
        "LET clean = pass_id(request.id); "
        + guards
        + "BEGIN ATOMIC "
        "CALL write_both(state, events, clean); "
        "REQUIRE clean = $expected ELSE 'PostCall'; "
        "END; END; END; "
        f"CREATE TARGET default AS BEGIN USE Run(TYPE Id, Id({case['raw']})); END;"
    )


def expected_helper_sql(case):
    raw = case['raw']
    lines = [
        'CREATE QUEUE JOBS ( ID BIGINT NOT NULL )',
        'CREATE TABLE LOOKUP ( ID BIGINT PRIMARY KEY )',
        'CREATE TABLE STATE ( ID BIGINT PRIMARY KEY )',
        'CREATE STREAM EVENTS ( ID BIGINT NOT NULL )',
    ]
    if not case['swap_guards']:
        guards_sql = (
            'LET "__t$3_target" = "__t$2_clean" ; '
            'LET "__t$4_found" = SELECT ID FROM "lookup" WHERE ID = "__t$3_target" ; '
            'REQUIRE "__t$4_found" IS NOT NULL ELSE \'Missing\' ; '
            'LET "__t$5_actual" = "__t$2_clean" ; '
            f'LET "__t$6_expected" = {raw} ; '
            'REQUIRE "__t$5_actual" = "__t$6_expected" ELSE \'Wrong\' ; '
        )
    else:
        guards_sql = (
            'LET "__t$3_actual" = "__t$2_clean" ; '
            f'LET "__t$4_expected" = {raw} ; '
            'REQUIRE "__t$3_actual" = "__t$4_expected" ELSE \'Wrong\' ; '
            'LET "__t$5_target" = "__t$2_clean" ; '
            'LET "__t$6_found" = SELECT ID FROM "lookup" WHERE ID = "__t$5_target" ; '
            'REQUIRE "__t$6_found" IS NOT NULL ELSE \'Missing\' ; '
        )
    lines += [
        'CREATE DATAFLOW PROCESS FROM QUEUE JOBS AS "__t$1_request" AS BEGIN '
        'LET "__t$2_clean" = ( ( "__t$1_request" . ID ) ) ; '
        + guards_sql
        + 'BEGIN ATOMIC '
        'LET "__t$7_id" = "__t$2_clean" ; '
        'INSERT INTO "state" VALUES ( "__t$7_id" ) ON CONFLICT ( ID ) DO ASSERT SAME ROW ; '
        'PRODUCE INTO "events" VALUES ( "__t$7_id" ) ; '
        f'REQUIRE "__t$2_clean" = {raw} ELSE \'PostCall\' ; '
        'END ; END'
    ]
    return lines


def expected_helper_events(case):
    domain = DOMAINS[case['domain']]
    present_events = [('let', None), ('read', 'lookup'), ('require', None)]
    expected_events_seq = [('let', None), ('let', None), ('require', None)]
    guard_events = (expected_events_seq + present_events) if case['swap_guards'] else (present_events + expected_events_seq)
    kinds = (
        [('acquire', 'jobs'), ('let', None)]
        + guard_events
        + [('atomic_begin', None), ('let', None), ('insert', 'state'), ('append', 'events'), ('require', None), ('atomic_end', None)]
    )
    return [
        dict(kind=kind, resource=resource, columns=[] if resource is None else [dict(column='id', domain=domain)])
        for kind, resource in kinds
    ]


def compare_helper(case, product):
    same(expected_helper_sql(case), [step['sql'] for step in product['steps']], 'helper lowered ordinary SQL')
    same(''.join(sql + ';\n' for sql in expected_helper_sql(case)), product['sql'], 'complete helper SQL')
    evidence = product['steps'][4]['checked']['program']
    assert len({node['id'] for node in evidence['nodes']}) == len(evidence['nodes']), 'duplicate helper node ID'
    events = [
        {k: v for k, v in event.items() if k not in ('node', 'source_offset', 'columns')}
        | {'columns': [{k: v for k, v in col.items() if k != 'value'} for col in event['columns']]}
        for event in evidence['events']
    ]
    same(expected_helper_events(case), events, 'ordered helper program events')

    # Verify nominal domain preservation on function binding and procedure writes,
    # and verify guard REQUIRE source attribution tracks the lexical CHECK GUARD order.
    domain = DOMAINS[case['domain']]
    by_id = {node['id']: node for node in evidence['nodes']}
    clean_binding = [node for node in evidence['nodes'] if node['kind'] == 'binding'][0]
    same(domain, clean_binding['type']['domain'], 'function return nominal domain')

    text = helper_source(case)
    require_offsets = [ev['source_offset'] for ev in evidence['events'] if ev['kind'] == 'require']
    want_req_offsets = (
        [text.index("REQUIRE actual = expected"), text.index("REQUIRE found IS NOT NULL"), text.index("REQUIRE clean = $expected")]
        if case['swap_guards']
        else [text.index("REQUIRE found IS NOT NULL"), text.index("REQUIRE actual = expected"), text.index("REQUIRE clean = $expected")]
    )
    same(want_req_offsets, require_offsets, 'ordered guard definition offsets')

    for event in evidence['events']:
        if event['kind'] in ('insert', 'append'):
            value_node = by_id[event['columns'][0]['value']]
            same(domain, value_node['type']['domain'], 'procedure write nominal domain')


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

    h_descriptors = list(helper_cases())
    h_outputs = execute(driver, [dict(name=f'helper-{i}', source=helper_source(case), compile='build') for i, case in enumerate(h_descriptors)], destination, 'helper-products')
    for case, output in zip(h_descriptors, h_outputs):
        assert 'product' in output, output
        compare_helper(case, output['product'])
    for label in ('helper dropped domain', 'helper swapped guard order', 'helper nested atomic', 'helper changed SQL'):
        damaged = copy.deepcopy(h_outputs[0]['product'])
        evidence = damaged['steps'][4]['checked']['program']
        if label == 'helper dropped domain':
            for node in evidence['nodes']:
                if node['kind'] == 'binding':
                    node['type']['domain'] = None
                    break
        elif label == 'helper swapped guard order':
            req_indices = [idx for idx, ev in enumerate(evidence['events']) if ev['kind'] == 'require']
            evidence['events'][req_indices[0]], evidence['events'][req_indices[1]] = (
                evidence['events'][req_indices[1]],
                evidence['events'][req_indices[0]],
            )
        elif label == 'helper nested atomic':
            evidence['events'].insert(9, dict(kind='atomic_begin', node=None, source_offset=0, resource=None, columns=[]))
        else:
            damaged['steps'][4]['sql'] = damaged['steps'][4]['sql'].replace("'PostCall'", "'Tampered'")
        controls.append(must_fail(label, lambda: compare_helper(h_descriptors[0], damaged)))

    helper_refusals = [
        (
            'helper-domain-refusal',
            "CREATE DOMAIN OrderId AS BIGINT IDENTITY 'example.machine-id'; "
            "CREATE DOMAIN SiteId AS BIGINT IDENTITY 'example.site-id'; "
            "CREATE FUNCTION pass_order(id OrderId) RETURNS OrderId AS BEGIN RETURN id; END; "
            "CREATE MODULE M(o TYPE, s TYPE) AS BEGIN CREATE PUBLIC QUEUE q (id $o NOT NULL, other $s NOT NULL); "
            "CREATE PUBLIC DATAFLOW p FROM QUEUE q AS r AS BEGIN LET bad = pass_order(r.other); END; END; "
            "CREATE TARGET default AS BEGIN USE M(TYPE OrderId, TYPE SiteId); END;",
            'SourceDomainMismatch',
        ),
        (
            'helper-guard-interface-refusal',
            "CREATE DOMAIN OrderId AS BIGINT IDENTITY 'example.machine-id'; "
            "CREATE DOMAIN SiteId AS BIGINT IDENTITY 'example.site-id'; "
            "CREATE GUARD check_order(rows TABLE(id OrderId PRIMARY KEY), target OrderId) AS BEGIN "
            "LET f = SELECT id FROM rows WHERE id = target; REQUIRE f IS NOT NULL ELSE 'Missing'; END; "
            "CREATE MODULE M(o TYPE, s TYPE) AS BEGIN CREATE PUBLIC QUEUE q (id $o NOT NULL); "
            "CREATE PUBLIC TABLE wrong_rows (id $s PRIMARY KEY); "
            "CREATE PUBLIC DATAFLOW p FROM QUEUE q AS r AS BEGIN CHECK GUARD check_order(wrong_rows, r.id); END; END; "
            "CREATE TARGET default AS BEGIN USE M(TYPE OrderId, TYPE SiteId); END;",
            'TableInterfaceMismatch',
        ),
        (
            'helper-recursion-refusal',
            "CREATE FUNCTION f1(x BIGINT) RETURNS BIGINT AS BEGIN RETURN f2(x); END; "
            "CREATE FUNCTION f2(x BIGINT) RETURNS BIGINT AS BEGIN RETURN f1(x); END; "
            "CREATE TARGET default AS BEGIN CREATE PUBLIC TABLE t (id BIGINT PRIMARY KEY); END;",
            'RecursiveSourceCall',
        ),
        (
            'helper-impure-refusal',
            "CREATE FUNCTION f1() RETURNS TEXT AS BEGIN RETURN RANDOM_TOKEN(16); END; "
            "CREATE TARGET default AS BEGIN CREATE PUBLIC TABLE t (id BIGINT PRIMARY KEY); END;",
            'ImpureSourceFunction',
        ),
    ]
    for (_, _, want_err), output in zip(
        helper_refusals,
        execute(driver, [dict(name=name, source=src, compile='build') for name, src, _ in helper_refusals], destination, 'helper-refusals'),
    ):
        same(want_err, output.get('compile_error'))
        assert 'product' not in output

    d_descriptors = list(diamond_cases())
    d_outputs = execute(driver, [diamond_request(i, case) for i, case in enumerate(d_descriptors)], destination, 'diamond-products')
    for case, output in zip(d_descriptors, d_outputs):
        assert 'product' in output, output
        compare_diamond(case, output['product'])
    for label in ('diamond duplicate DDL', 'diamond dropped domain', 'diamond changed SQL'):
        damaged = copy.deepcopy(d_outputs[0]['product'])
        if label == 'diamond duplicate DDL':
            damaged['steps'].insert(2, copy.deepcopy(damaged['steps'][0]))
        elif label == 'diamond dropped domain':
            damaged['steps'][1]['checked']['operands'][0]['domain'] = None
            damaged['steps'][1]['checked']['columns'][0]['domain'] = None
        else:
            damaged['steps'][2]['sql'] += ' WHERE FALSE'
        controls.append(must_fail(label, lambda: compare_diamond(d_descriptors[0], damaged)))
    for output in execute(driver, [diamond_request(i, case, bad_domain=True) for i, case in enumerate(d_descriptors)], destination, 'diamond-refusals'):
        same('SourceDomainMismatch', output.get('compile_error'))
        assert 'product' not in output

    return len(outputs) + len(h_outputs) + len(d_outputs), controls
