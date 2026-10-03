"""Native Table mutation rows/results, exact receipt recovery and writer fencing."""
from contextlib import nullcontext
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import threading
import time

from storage import Fixture, free_port, wait_ready
from cold_storage import ColdStore
from table_mutation_abi import Native, Port, Failure, check_profiles
from table_mutation_cli import Cli


def run(node, proof, host, port_host, library, cli, *, sdks=(), cold=False):
    started = time.monotonic()
    source_root = Path(__file__).resolve().parents[1]
    identity = dict(revision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=source_root,text=True).strip(),
        dirty=bool(subprocess.check_output(['git','status','--porcelain'],cwd=source_root,text=True).strip()),
        runner_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest())
    print('Mutation SDK selection: '+(', '.join(sdks) if sdks else 'native/port/CLI'),flush=True)
    with ColdStore() if cold else nullcontext() as cold_store, Fixture(cold_store.config() if cold_store else None) as fixture:
        root = fixture.root
        installed = []
        install_started = time.monotonic()
        if sdks:
            from sdk_mutations import install
            installed = install(root/'installed',sdks)
        sdk_install_seconds = round(time.monotonic()-install_started,3) if sdks else 0
        # Keep a matched build through worker/node/store restarts.
        for name, original in [('node', node), ('proof', proof), ('host', host), ('port',port_host), ('library.so',library), ('cli',cli)]:
            shutil.copy2(original, root/name)
        node, proof, host = str(root/'node'), str(root/'proof'), str(root/'host')
        port_host, library = str(root/'port'), str(root/'library.so')
        cli = str(root/'cli')
        clients = []
        public = json.loads(subprocess.check_output([proof, 'public'], timeout=10))
        port = free_port()
        url = f'http://127.0.0.1:{port}'
        config = root/'node.json'
        config.write_text(json.dumps({'profile':'native_v1',
            'genesis':{'realm':46,'root_key':public,'max_clock_error_ms':10000},
            'ursula_url':fixture.url,'bucket':'mutation','journal':'authority',
            'port':port,'resident_pages':8,'request_timeout_ms':10000}))
        faults = {'lose':False,'body':None,'receipt':None,'recovered':False}
        send_fault = {'lose':False,'body':None,'receipt':None,'recovered':False}
        counts = {'reads':0,'turns':0,'mutation_send_responses':0,'max_mutations':0,'max_value_bytes':0,'lost_caller_receipts':0}
        errors = []

        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_): pass
            def do_POST(self):
                body = self.rfile.read(int(self.headers['Content-Length']))
                connection = HTTPConnection('127.0.0.1', port, timeout=15)
                try:
                    envelope = json.loads(body)
                    if self.path == '/v1/query': counts['reads'] += 1
                    connection.request('POST', self.path, body, {'Content-Type':'application/json'})
                    response = connection.getresponse()
                    data = response.read()
                    request = envelope.get('request',{})
                    if request.get('principal') == 1234 and 'send' in request.get('command',{}) and response.status == 200:
                        counts['mutation_send_responses'] += 1
                        if send_fault['lose']:
                            counts['lost_caller_receipts'] += 1
                            send_fault.update(lose=False,body=body,receipt=json.loads(data))
                            data = b'{}'
                        elif send_fault['body'] == body:
                            assert json.loads(data)['position'] == send_fault['receipt']['position']
                            send_fault['recovered'] = True
                    turn = envelope.get('request',{}).get('command',{}).get('turn')
                    if turn and response.status == 200:
                        mutations = [entry for entry in turn['mutations'] if entry]
                        assert len(mutations) <= 4
                        counts['turns'] += 1
                        counts['max_mutations'] = max(counts['max_mutations'],len(mutations))
                        for entry in mutations:
                            if entry['value'] is not None:
                                size = len(bytes.fromhex(entry['value']))
                                assert size <= 256
                                counts['max_value_bytes'] = max(counts['max_value_bytes'],size)
                        if faults['lose']:
                            faults.update(lose=False,body=body,receipt=json.loads(data))
                            # Authority accepted the complete proposal, but the
                            # submitting process receives no valid receipt.
                            data = b'{}'
                        elif faults['body'] == body:
                            assert json.loads(data)['position'] == faults['receipt']['position']
                            faults['recovered'] = True
                    self.send_response(response.status)
                    self.send_header('Content-Length',str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                except (BrokenPipeError,ConnectionResetError): pass
                except BaseException as error:
                    errors.append(error)
                    self.close_connection = True
                finally: connection.close()

        proxy = ThreadingHTTPServer(('127.0.0.1',0),Proxy)
        proxy.daemon_threads = True
        thread = threading.Thread(target=proxy.serve_forever,daemon=True)
        thread.start()
        proxy_url = f'http://127.0.0.1:{proxy.server_port}'
        authority = None
        writer = None
        writer_logs = []
        log = (root/'node.log').open('w+')
        def start():
            nonlocal authority
            authority = subprocess.Popen([node,str(config)],env=fixture.env,stdout=log,stderr=log)
            wait_ready(fixture.http,authority,url+'/health')
        def invoke(mode,*args,error=None):
            result = subprocess.run([proof,proxy_url,mode,str(root),*map(str,args)],
                env=fixture.env,capture_output=True,text=True,timeout=120)
            if errors: raise ExceptionGroup('mutation proxy errors',errors)
            if error is not None:
                assert result.returncode != 0 and error in result.stderr, (mode,result.returncode,result.stderr)
                return None
            assert result.returncode == 0, (mode,result.stdout,result.stderr)
            return json.loads(result.stdout)
        def snapshot(namespace,phase,values,affected=None):
            result = invoke('inspect',namespace)
            assert result['phase'] == phase, result
            assert result['row_zero'] is None, 'An earlier row from a rejected batch leaked'
            actual = [None if row is None else ('row',None if row['value'] is None else bytes.fromhex(row['value']).decode()) for row in result['rows']]
            assert actual == [None if value is None else ('row',value[0]) for value in values], (actual,values)
            if affected is not None: assert result['affected_rows'] == affected, result
            return result
        def start_writer():
            nonlocal writer
            current = json.loads((root/'mutation.json').read_text())['writer']
            seed = root/'writer.seed'
            seed.write_text('08'*32)
            seed.chmod(0o600)
            (root/'activations').mkdir(exist_ok=True)
            host_config = dict(url=proxy_url,realm=46,principal=65536,seed_file=str(seed),
                pid=current['pid'],generation=current['generation'],activation_directory=str(root/'activations'),
                interval_ms=10,request_timeout_ms=10000,
                role={'table_writer':dict(resource=current['resource'],initializer=0,principal=1234,
                    permissions=7,value_type='utf8')})
            (root/'writer.json').write_text(json.dumps(host_config))
            output = (root/f"writer-{current['generation']}.log").open('w+')
            writer_logs.append(output)
            writer = subprocess.Popen([host,str(root/'writer.json')],env=fixture.env,stdout=output,stderr=output)
            deadline = time.monotonic()+15
            while time.monotonic()<deadline:
                records = Path(output.name).read_text()
                assert writer.poll() is None, records[-5000:]
                if 'service.ready' in records: return
                time.sleep(0.02)
            raise TimeoutError('Supplied mutation writer did not become ready')
        def processed(position):
            deadline = time.monotonic()+15
            while time.monotonic()<deadline:
                assert writer.poll() is None, 'Supplied writer exited during admitted work'
                current = invoke('progress')
                if current['pending'] is None or current['pending']>position: return
                time.sleep(0.02)
            raise TimeoutError('Supplied mutation writer did not process its admitted input')
        try:
            subprocess.run([node,str(config),'--initialize'],env=fixture.env,check=True,capture_output=True,timeout=30)
            start()
            invoke('provision')
            text = '東京🙂/'+'x'*180
            statement = f"INSERT INTO items (id,value) VALUES(1,'{text}'),(2,'two'),(3,NULL)"
            # Caller loss is separate from writer commit loss. Recover the
            # original prepared native send before selecting an upload successor.
            invoke('prepare-upload',1,statement)
            frozen_send = (root/'mutation-send.json').read_bytes()
            send_fault['lose'] = True
            invoke('submit-upload',error='InvalidAuthorityResponse')
            assert send_fault['receipt'] is not None and not send_fault['lose']
            authority.kill(); authority.wait(timeout=10); authority = None
            fixture.stop(); fixture.start(); start()
            receipt = invoke('submit-upload')
            assert receipt['position'] == send_fault['receipt']['position'] and send_fault['recovered']
            assert (root/'mutation-send.json').read_bytes() == frozen_send
            assert invoke('progress')['pending'] == receipt['position']
            invoke('resume')
            snapshot(1,'uploading',[None,None,None])
            saved_reference = (root/'mutation-1.json').read_bytes()
            invoke('stage',1,'DELETE FROM items WHERE id=1',error='MutationIdentityConflict')
            assert (root/'mutation-1.json').read_bytes() == saved_reference
            invoke('prepare-upload',99,'DELETE FROM items WHERE id=1',error='MutationBusy')
            # No accepted second begin or mutated row can arise from preparation.
            assert invoke('progress')['pending'] is None
            invoke('stage',1,statement)
            before = snapshot(1,'sealed',[None,None,None])
            prepared = invoke('prepare',1)
            assert prepared['mutations'] == 4
            assert snapshot(1,'sealed',[None,None,None]) == before
            frozen = (root/'mutation-commit.json').read_bytes()
            faults['lose'] = True
            invoke('commit',error='InvalidAuthorityResponse')
            assert faults['receipt'] is not None and not faults['lose']
            after = snapshot(1,'applied',[(text,),('two',),(None,)],3)
            assert after['input'] == prepared['input']
            assert {row['revision'] for row in after['rows']} == {after['result_revision']}
            progress = invoke('progress')
            assert progress['consumed'] == progress['admitted'] and progress['pending'] is None
            # Kill/reopen the physical store and authority. The worker process
            # already exited, leaving only the frozen proposal and durable data.
            authority.kill(); authority.wait(timeout=10); authority = None
            fixture.stop(); fixture.start(); start()
            receipt = invoke('commit')
            assert receipt['position'] == faults['receipt']['position'] and faults['recovered']
            assert (root/'mutation-commit.json').read_bytes() == frozen
            assert snapshot(1,'applied',[(text,),('two',),(None,)],3) == after
            invoke('changed-retry',error='ConflictingRetry')
            invoke('apply',1)
            repeated = snapshot(1,'applied',[(text,),('two',),(None,)],3)
            assert repeated['input'] == after['input'] and repeated['result_revision'] == after['result_revision']
            assert repeated['rows'] == after['rows']
            # An INSERT conflict after proposing an earlier absent row cannot
            # publish either row. The outcome is the only new resource key.
            invoke('stage',2,"INSERT INTO items (id,value) VALUES(0,'new'),(2,'conflict')")
            # Source metadata acquired before intervening staging commits must
            # not become a current captured view, even with the current fence.
            invoke('stale-view',2,after['resource_revision'],error='StaleStateResource')
            snapshot(2,'sealed',[(text,),('two',),(None,)])
            invoke('resume')
            rejected = snapshot(2,'rejected',[(text,),('two',),(None,)],0)
            assert rejected['reason'] == 'row_exists'
            assert rejected['rows'] == after['rows']
            # Known refusal after generation replacement: no stale rows/result.
            invoke('stage',3,"UPDATE items SET value='replacement' WHERE id=1")
            invoke('prepare',3)
            old = snapshot(3,'sealed',[(text,),('two',),(None,)])
            invoke('reown')
            invoke('commit',error='StaleGeneration')
            assert snapshot(3,'sealed',[(text,),('two',),(None,)]) == old
            invoke('resume')
            snapshot(3,'applied',[('replacement',),('two',),(None,)],1)
            # Current write rights gate even an already prepared signed turn.
            invoke('stage',4,'DELETE FROM items WHERE id=2')
            invoke('prepare',4)
            before_revocation = snapshot(4,'sealed',[('replacement',),('two',),(None,)])
            frozen = (root/'mutation-commit.json').read_bytes()
            invoke('revoke-writer')
            invoke('commit',error='AccessDenied')
            assert snapshot(4,'sealed',[('replacement',),('two',),(None,)]) == before_revocation
            invoke('restore-writer')
            invoke('commit')
            assert (root/'mutation-commit.json').read_bytes() == frozen
            snapshot(4,'applied',[('replacement',),None,(None,)],1)
            # Application policy revocation is independent of native ownership.
            invoke('stage',5,"UPDATE items SET value='denied' WHERE id=3")
            invoke('revoke-policy')
            invoke('apply',5)
            denied = snapshot(5,'rejected',[('replacement',),None,(None,)],0)
            assert denied['reason'] == 'denied'
            invoke('prepare-upload',6,'DELETE FROM items WHERE id=1',error='MutationDenied')
            invoke('cancel',5)
            repeated = snapshot(5,'rejected',[('replacement',),None,(None,)],0)
            assert repeated['input'] == denied['input'] and repeated['result_revision'] == denied['result_revision']
            # Actual supplied host, with an explicit role, saved configuration,
            # fresh fencing on restart and retained activation markers.
            invoke('restore-policy')
            invoke('reown')
            start_writer()
            def mutation(action, **kwargs):
                return invoke('bridge',json.dumps(action),**kwargs)
            def submit(prepared):
                # Opaque signed text survives host replacement and is never
                # parsed/re-encoded by this foreign adapter.
                (root/'bridge-prepared.txt').write_text(prepared)
                receipt = mutation({'submit':(root/'bridge-prepared.txt').read_text()})['receipt']
                processed(receipt['position'])
                observation = dict(prepared=prepared,input=receipt['position'])
                assert mutation({'observe':observation}) == {'observation':'processed'}
                return mutation({'rejection':observation})['rejection']
            assert mutation({'capabilities':{}})['capabilities']['max_rows'] == 3
            description = mutation({'describe':{}})['description']
            assert description['permissions'] == 7 and description['value_type'] == 'utf8'
            compiled = mutation({'compile':dict(name='items',sql="INSERT INTO items (id,value) VALUES(2,'host')",namespace='6')})['compiled']
            (root/'bridge-compiled.json').write_text(json.dumps(compiled))
            # Exercise explicit staging independently of automatic direct admission.
            first = mutation({'prepare': {'begin': {'reference': compiled['reference'], 'table': 1, 'policy_revision': description['policy_revision']}}})['prepared']
            assert first is not None and submit(first) is None
            current = mutation({'status':compiled['reference']})['status']
            assert current['phase'] == 'uploading' and current['affected_rows'] == 0
            writer.kill(); writer.wait(timeout=10); writer = None
            invoke('reown')
            start_writer()
            compiled = json.loads((root/'bridge-compiled.json').read_text())
            # A valid but premature apply is acknowledged with a disposition,
            # leaving upload state intact and subsequent accepted work runnable.
            premature = mutation({'prepare':{'apply':compiled['reference']}})['prepared']
            assert submit(premature)['reason'] == 'not_sealed'
            assert mutation({'status':compiled['reference']})['status'] == current
            for _ in range(16):
                prepared = mutation({'next':compiled})['prepared']
                if prepared is None: break
                assert submit(prepared) is None
            else: raise AssertionError('Supplied writer exceeded bounded upload steps')
            status = mutation({'status':compiled['reference']})['status']
            assert status['phase'] == 'applied' and status['affected_rows'] == 1
            assert status['reference'] == compiled['reference'] and status['reason'] == 'none'
            cancelled = mutation({'prepare':{'cancel':compiled['reference']}})['prepared']
            assert submit(cancelled) is None
            assert mutation({'status':compiled['reference']})['status'] == status
            snapshot(6,'applied',[('replacement',),('host',),(None,)],1)
            duplicate_host = subprocess.run([host,str(root/'writer.json')],env=fixture.env,capture_output=True,text=True,timeout=15)
            assert duplicate_host.returncode != 0 and 'FreshOwnershipRequired' in duplicate_host.stderr
            caller_seed = root/'caller.seed'
            caller_seed.write_text('0a'*32)
            caller_seed.chmod(0o600)
            connection = dict(realm=46,principal=1234,writer=json.loads((root/'mutation.json').read_text())['writer']['pid'],resource=description['resource'],table=1)
            check_profiles(port_host,root,proxy_url,connection)
            factories = [('native',lambda: Native(library,proxy_url,connection)),('port',lambda: Port(port_host,root,proxy_url,connection)),('cli',lambda: Cli(cli,root,proxy_url,connection))]
            factories += [(label,lambda factory=factory: factory(proxy_url,connection,root)) for label,factory in installed]
            foreign_statuses = []
            foreign_dispositions = []
            caller_timings = []
            profile_measurements = []
            for caller_index,(label,factory) in enumerate(factories):
                namespace = caller_index + 7
                if label == 'node': namespace = (1 << 64)-1
                if label == 'ruby': namespace = (1 << 63)+17
                if label == 'rust': namespace = (1 << 63)+18
                if label == 'c': namespace = (1 << 63)+19
                if label == 'cpp': namespace = (1 << 63)+20
                if label == 'java': namespace = (1 << 63)+21
                if label == 'dotnet': namespace = (1 << 63)+22
                if label == 'erlang': namespace = (1 << 63)+23
                if label == 'elixir': namespace = (1 << 63)+24
                if label == 'cli': namespace = (1 << 63)+25
                caller_started = time.monotonic()
                owner = factory(); clients.append(owner)
                assert owner.call({'capabilities':{}})['capabilities']['max_rows'] == 3
                assert owner.call({'describe':{}})['description']['resource'] == description['resource']
                bad_sql = "INSERT INTO items (id,value) VALUES(1,100)"
                try: owner.call({'compile':dict(name='items',sql=bad_sql,namespace=str(namespace))})
                except Failure as error:
                    diagnostic = error.detail['diagnostic']
                    assert error.status == 1 and not error.detail.get('diagnostic_invalid', False), (label,error)
                    assert diagnostic['code'] == 'sql.type_mismatch' and diagnostic['outcome'] == 'not_submitted', (label,diagnostic)
                    assert diagnostic['evidence'] == 'local_before_dispatch'
                    facts = {fact['field']:fact['value'] for fact in diagnostic['facts'] if fact}
                    assert facts['expected_type'] == {'text':'utf8'} and facts['actual_type'] == {'text':'int64'}, (label,facts)
                    assert facts['supplied_value'] == {'text':'100'} and facts['input_row'] == {'unsigned':'1'}, (label,facts)
                else: raise AssertionError('Mutation compiler accepted an incompatible scalar')
                operation = owner.call({'compile':dict(name='items',sql=f"UPDATE items SET value='{label}' WHERE id=2",namespace=str(namespace))})['compiled']
                altered = dict(operation)
                altered['reference'] = operation['reference'][:-1]+('1' if operation['reference'][-1] != '1' else '2')
                try: owner.call({'next':altered})
                except Failure as error: assert error.status == 5, error
                else: raise AssertionError('Mutation caller silently replaced a changed request commitment')
                token = owner.call({'next':operation})['prepared']
                saved = root/f'{label}-prepared.txt'
                saved.write_text(token)
                send_fault.update(lose=True,recovered=False)
                try: owner.call({'submit':token})
                except Failure as error:
                    assert error.status == 6, error
                    diagnostic = error.detail['diagnostic']
                    assert diagnostic['code'] == 'mutation.send_unknown' and diagnostic['outcome'] == 'unknown', (label,diagnostic)
                    assert diagnostic['identity']['sequence'] == str(json.loads(token)['signed']['request']['sequence'])
                    assert [action['kind'] for action in diagnostic['actions'] if action] == ['inspect_status','resume_exact']
                else: raise AssertionError('Missing admitted receipt was reported as success')
                owner.close(); clients.remove(owner)
                owner = factory(); clients.append(owner)
                assert saved.read_text() == token
                receipt = owner.call({'submit':saved.read_text()})['receipt']
                assert send_fault['recovered'] and receipt['position'] == send_fault['receipt']['position']
                if label == 'cli':
                    processed(receipt['position'])
                    premature = owner.call({'prepare':{'apply':operation['reference']}})['prepared']
                    premature_receipt = owner.call({'submit':premature})['receipt']
                    processed(premature_receipt['position'])
                    assert owner.call({'rejection':dict(prepared=premature,input=premature_receipt['position'])}) == {'rejection':None}
                    assert owner.call({'status':operation['reference']})['status']['phase'] == 'applied'
                for _ in range(16):
                    processed(receipt['position'])
                    observation = dict(prepared=token,input=receipt['position'])
                    assert owner.call({'observe':observation}) == {'observation':'processed'}
                    assert owner.call({'rejection':observation}) == {'rejection':None}
                    token = owner.call({'next':operation})['prepared']
                    if token is None: break
                    saved.write_text(token)
                    receipt = owner.call({'submit':saved.read_text()})['receipt']
                else: raise AssertionError('Foreign mutation caller exceeded bounded stage count')
                result = owner.call({'status':operation['reference']})['status']
                assert result['phase'] == 'applied' and result['affected_rows'] == 1
                if label == 'cli':
                    cancel = owner.call({'prepare':{'cancel':operation['reference']}})['prepared']
                    cancellation = owner.call({'submit':cancel})['receipt']
                    processed(cancellation['position'])
                    assert owner.call({'status':operation['reference']})['status'] == result
                snapshot(namespace,'applied',[('replacement',),(label,),(None,)],1)
                history = [(operation['reference'],result)]
                profile_measurements.append(dict(caller=label,profile='update',namespace=str(namespace),
                    seconds=round(time.monotonic()-caller_started,3),phase=result['phase'],affected_rows=1))
                # Every installed caller executes the same profiles through its
                # public mutation API. Python only drives the schedule and
                # compares independent row/result expectations; Zig still owns
                # parsing, signing, staging, policy and application semantics.
                profiles = [
                    ('delete', 'DELETE FROM items WHERE id=2', 'applied', 'none', 1, None),
                    ('delete_missing', 'DELETE FROM items WHERE id=2', 'applied', 'none', 0, None),
                    ('update_missing', "UPDATE items SET value='absent' WHERE id=2", 'applied', 'none', 0, None),
                    ('insert', f"INSERT INTO items (value,id) VALUES('{label}',2)", 'applied', 'none', 1, (label,)),
                    ('insert_conflict', "INSERT INTO items (id,value) VALUES(0,'rollback'),(2,'conflict')", 'rejected', 'row_exists', 0, (label,)),
                    ('cancel_upload', "INSERT INTO items (id,value) VALUES(0,'" + 'cancelled'*24 + "')", 'cancelled', 'none', 0, (label,)),
                ]
                for profile_index,(profile,sql,phase,reason,affected,value) in enumerate(profiles):
                    profile_started = time.monotonic()
                    # Keep the existing full-width UPDATE namespaces and give
                    # additional profiles distinct, explicit durable identities.
                    profile_namespace = 1000 + caller_index * 16 + profile_index
                    previous_rows = invoke('inspect',namespace)['rows']
                    request = owner.call({'compile':dict(name='items',sql=sql,namespace=str(profile_namespace))})['compiled']
                    assert owner.call({'status':request['reference']})['status'] is None
                    prepared = owner.call({'next':request})['prepared']
                    saved = root/f'{label}-{profile}-prepared.txt'
                    recovered = False
                    for step in range(16):
                        assert prepared is not None, (label,profile,step)
                        current = owner.call({'status':request['reference']})['status']
                        current_phase = current['phase'] if current else None
                        # Begin and at least one data part have committed before
                        # cancellation; abandoning an empty descriptor alone
                        # would not test disposal of partially staged input.
                        cancel_now = profile == 'cancel_upload' and current_phase == 'uploading' and step >= 2
                        if cancel_now:
                            prepared = owner.call({'prepare':{'cancel':request['reference']}})['prepared']
                        saved.write_text(prepared)
                        # Lose direct/APPLY admission receipt (or CANCEL during
                        # upload), then recreate the caller. Never select a
                        # successor or re-sign before reconciling this send.
                        direct = len(bytes.fromhex(request['request'])) <= 223
                        lose = not recovered and (cancel_now if profile == 'cancel_upload' else (current_phase is None if direct else current_phase == 'sealed'))
                        if lose:
                            send_fault.update(lose=True,recovered=False)
                            try: owner.call({'submit':prepared})
                            except Failure as error: assert error.status == 6, (label,profile,error)
                            else: raise AssertionError((label,profile,'Lost admission receipt reported success'))
                            assert send_fault['receipt'] is not None and not send_fault['lose']
                            owner.close(); clients.remove(owner)
                            owner = factory(); clients.append(owner)
                            assert saved.read_text() == prepared
                        receipt = owner.call({'submit':saved.read_text()})['receipt']
                        if lose:
                            assert send_fault['recovered'] and receipt['position'] == send_fault['receipt']['position']
                            recovered = True
                        processed(receipt['position'])
                        observation = dict(prepared=prepared,input=receipt['position'])
                        assert owner.call({'observe':observation}) == {'observation':'processed'}
                        assert owner.call({'rejection':observation}) == {'rejection':None}
                        if profile == 'cancel_upload' and step == 0:
                            # An admitted APPLY against the unsealed upload has
                            # its own disposition; it does not reject the SQL.
                            before = owner.call({'status':request['reference']})['status']
                            assert before['phase'] == 'uploading'
                            early = owner.call({'prepare':{'apply':request['reference']}})['prepared']
                            early_receipt = owner.call({'submit':early})['receipt']
                            processed(early_receipt['position'])
                            early_input = dict(prepared=early,input=early_receipt['position'])
                            disposition = owner.call({'rejection':early_input})['rejection']
                            assert disposition['reason'] == 'not_sealed' and disposition['input'] == early_receipt['position'], (label,disposition)
                            assert disposition == mutation({'rejection':early_input})['rejection'], (label,disposition)
                            detail = disposition['diagnostic']
                            assert detail['code'] == 'mutation.input.not_sealed' and detail['outcome'] == 'input_rejected'
                            assert detail['identity']['domain'] == 'transport' and detail['identity']['id'] == str(disposition['input'])
                            facts = {fact['field']:fact['value'] for fact in detail['facts'] if fact}
                            assert facts['source_basis'] == {'digest':list(bytes.fromhex(disposition['payload']))}
                            assert owner.call({'status':request['reference']})['status'] == before
                            foreign_dispositions.append((label,early_input,disposition))
                        prepared = owner.call({'next':request})['prepared']
                        if prepared is None: break
                    else: raise AssertionError((label,profile,'Bounded stage count exceeded'))
                    assert recovered, (label,profile,'Recovery injection was not reached')
                    outcome = owner.call({'status':request['reference']})['status']
                    assert outcome['reference'] == request['reference']
                    assert (outcome['phase'],outcome['reason'],outcome['affected_rows']) == (phase,reason,affected), (label,profile,outcome)
                    assert outcome['conflict'] == (dict(key='2',row=2) if reason == 'row_exists' else None), (label,profile,outcome)
                    detail = outcome['diagnostic']
                    assert detail == mutation({'status':request['reference']})['status']['diagnostic'], (label,profile,detail)
                    assert detail['outcome'] == phase and detail['evidence'] == 'domain_status'
                    assert detail['identity']['domain'] == 'mutation' and detail['identity']['id'] == str(profile_namespace)
                    facts = {fact['field']:fact['value'] for fact in detail['facts'] if fact}
                    assert facts['affected_rows'] == {'unsigned':str(affected)}
                    assert all(action['kind'] not in ('resume_exact','cancel_mutation') for action in detail['actions'] if action)
                    if reason == 'row_exists':
                        assert detail['code'] == 'mutation.primary_key_conflict'
                        assert facts['key'] == {'signed':'2'} and facts['input_row'] == {'unsigned':'2'}
                    rows = snapshot(profile_namespace,phase,[('replacement',),value,(None,)],affected)
                    assert rows['reason'] == reason and rows['input'] == receipt['position']
                    assert rows['rows'][0] == previous_rows[0] and rows['rows'][2] == previous_rows[2]
                    if affected == 0: assert rows['rows'] == previous_rows, (label,profile,'No-op or rollback changed rows')
                    if profile == 'insert': assert rows['rows'][1]['revision'] == rows['result_revision']
                    # Later explicit controls cannot rewrite an applied,
                    # rejected or cancelled terminal result or its input basis.
                    for control in ('apply','cancel'):
                        terminal = owner.call({'prepare':{control:request['reference']}})['prepared']
                        terminal_receipt = owner.call({'submit':terminal})['receipt']
                        processed(terminal_receipt['position'])
                        assert owner.call({'rejection':dict(prepared=terminal,input=terminal_receipt['position'])}) == {'rejection':None}
                        assert owner.call({'status':request['reference']})['status'] == outcome
                    repeated = snapshot(profile_namespace,phase,[('replacement',),value,(None,)],affected)
                    assert all(repeated[key] == rows[key] for key in ('rows','input','result_revision'))
                    history.append((request['reference'],outcome))
                    profile_measurements.append(dict(caller=label,profile=profile,namespace=str(profile_namespace),
                        seconds=round(time.monotonic()-profile_started,3),phase=phase,affected_rows=affected,
                        recovered_input=receipt['position']))
                    print(f'Mutation caller {label}: {profile}, exact saved recovery and terminal identity passed.',flush=True)
                foreign_statuses.extend((owner,reference,status) for reference,status in history)
                foreign_dispositions[:] = [(owner if who == label else who, observed, value) for who,observed,value in foreign_dispositions]
                caller_timings.append(dict(caller=label,seconds=round(time.monotonic()-caller_started,3)))
                print(f'Mutation caller {label}: all seven profiles passed.',flush=True)
            for reader,reference,result in foreign_statuses:
                assert reader.call({'status':reference})['status'] == result
            for reader,observed,result in foreign_dispositions:
                assert reader.call({'rejection':observed})['rejection'] == result
            writer.kill(); writer.wait(timeout=10); writer = None
            # Retain all installed-callers' exact outcomes across a physical
            # store/node restart, independently of their local handle lifetime.
            authority.kill(); authority.wait(timeout=10); authority = None
            fixture.stop(); fixture.start(); start()
            for reader,reference,result in foreign_statuses:
                assert reader.call({'status':reference})['status'] == result
            for reader,observed,result in foreign_dispositions:
                assert reader.call({'rejection':observed})['rejection'] == result
            invoke('revoke-reader')
            mutation({'status':compiled['reference']},error='AccessDenied')
            invoke('inspect',1,error='AccessDenied')
            for reader,reference,_ in foreign_statuses:
                try: reader.call({'status':reference})
                except Failure as error: assert error.status == 4, error
                else: raise AssertionError('Foreign status reader ignored current revocation')
            for reader,observed,_ in foreign_dispositions:
                try: reader.call({'rejection':observed})
                except Failure as error: assert error.status == 4, error
                else: raise AssertionError('Foreign input reader ignored current revocation')
            assert counts['max_mutations'] == 4
            if cold_store:
                assert cold_store.data_objects() > 0, 'Mutation history did not spill to cold storage'
            report = {'proof':'Table mutation native admission',**identity,'elapsed_seconds':round(time.monotonic()-started,3),
                **counts,'selected_sdks':list(sdks),'sdk_install_seconds':sdk_install_seconds,'caller_timings':caller_timings,
                'profiles':profile_measurements,'resident_authority_pages':8,'lost_receipts':counts['lost_caller_receipts']+1,
                'storage':dict(cold=cold,hot_bytes_limit=(8 if cold else 64)*1024*1024,
                    cold_objects=cold_store.data_objects() if cold_store else 0,
                    cold_file_bytes=cold_store.file_bytes() if cold_store else 0),
                'node_sha256':hashlib.sha256(Path(node).read_bytes()).hexdigest(),
                'proof_sha256':hashlib.sha256(Path(proof).read_bytes()).hexdigest(),
                'host_sha256':hashlib.sha256(Path(host).read_bytes()).hexdigest(),
                'port_sha256':hashlib.sha256(Path(port_host).read_bytes()).hexdigest(),
                'library_sha256':hashlib.sha256(Path(library).read_bytes()).hexdigest(),
                'cli_sha256':hashlib.sha256(Path(cli).read_bytes()).hexdigest()}
            print('Table mutation native: shared client preparation/observation/resumption, exact caller-send and writer-commit lost-receipt disk recovery, atomic rows/result/input, conflicting retry, duplicate outcome, batch rollback, fenced writer and current native/application grants passed.',flush=True)
            print('Native mutation ABI and port: shared actions, lost admission receipts, caller recreation, exact retry, durable status and current denial passed.',flush=True)
            print('Mutation CLI: private non-replacing artifacts, full-width SQL identity, altered commitment rejection, exact saved retry in fresh processes and current read denial passed.',flush=True)
            print('Supplied Table writer: explicit configuration, fresh-fenced restart during upload, recorded input rejection, continued application, exact status and activation reuse refusal passed.',flush=True)
        except BaseException:
            log.flush(); log.seek(0); sys.stderr.write(log.read()[-5000:])
            for output in writer_logs:
                sys.stderr.write(Path(output.name).read_text()[-5000:])
            raise
        finally:
            for client in reversed(clients): client.close()
            if writer is not None:
                if writer.poll() is None: writer.kill()
                writer.wait(timeout=10)
            for output in writer_logs: output.close()
            if authority is not None:
                if authority.poll() is None: authority.kill()
                authority.wait(timeout=10)
            proxy.shutdown(); proxy.server_close(); thread.join(timeout=5)
            log.close()
    # Only a completed schedule and successful fixture cleanup emit a result.
    report['completed'] = True
    print(json.dumps(report),flush=True)


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('node','proof','host','port_host','library','cli'): parser.add_argument(name)
    parser.add_argument('--sdk',action='append',default=[])
    parser.add_argument('--cold',action='store_true',help='use the owned S3 cold tier with an 8 MiB hot-store limit')
    args = parser.parse_args()
    run(args.node,args.proof,args.host,args.port_host,args.library,args.cli,sdks=args.sdk,cold=args.cold)
