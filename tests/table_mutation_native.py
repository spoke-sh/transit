"""Native Table mutation rows/results, exact receipt recovery and writer fencing."""
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
from table_mutation_abi import Native, Port, Failure, check_profiles


def run(node, proof, host, port_host, library, *, sdks=()):
    started = time.monotonic()
    print('Mutation SDK selection: '+(', '.join(sdks) if sdks else 'native/port only'),flush=True)
    with Fixture() as fixture:
        root = fixture.root
        installed = []
        install_started = time.monotonic()
        if sdks:
            from sdk_mutations import install
            installed = install(root/'installed',sdks)
        sdk_install_seconds = round(time.monotonic()-install_started,3) if sdks else 0
        # Keep a matched build through worker/node/store restarts.
        for name, original in [('node', node), ('proof', proof), ('host', host), ('port',port_host), ('library.so',library)]:
            shutil.copy2(original, root/name)
        node, proof, host = str(root/'node'), str(root/'proof'), str(root/'host')
        port_host, library = str(root/'port'), str(root/'library.so')
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
            first = mutation({'next':compiled})['prepared']
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
            assert submit(premature) == 'not_sealed'
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
            factories = [('native',lambda: Native(library,proxy_url,connection)),('port',lambda: Port(port_host,root,proxy_url,connection))]
            factories += [(label,lambda factory=factory: factory(proxy_url,connection,root)) for label,factory in installed]
            foreign_statuses = []
            caller_timings = []
            for namespace,(label,factory) in enumerate(factories,7):
                if label == 'node': namespace = (1 << 64)-1
                if label == 'ruby': namespace = (1 << 63)+17
                if label == 'rust': namespace = (1 << 63)+18
                if label == 'c': namespace = (1 << 63)+19
                if label == 'cpp': namespace = (1 << 63)+20
                if label == 'java': namespace = (1 << 63)+21
                if label == 'dotnet': namespace = (1 << 63)+22
                caller_started = time.monotonic()
                owner = factory(); clients.append(owner)
                assert owner.call({'capabilities':{}})['capabilities']['max_rows'] == 3
                assert owner.call({'describe':{}})['description']['resource'] == description['resource']
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
                except Failure as error: assert error.status == 6, error
                else: raise AssertionError('Missing admitted receipt was reported as success')
                owner.close(); clients.remove(owner)
                owner = factory(); clients.append(owner)
                assert saved.read_text() == token
                receipt = owner.call({'submit':saved.read_text()})['receipt']
                assert send_fault['recovered'] and receipt['position'] == send_fault['receipt']['position']
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
                snapshot(namespace,'applied',[('replacement',),(label,),(None,)],1)
                foreign_statuses.append((owner,operation['reference'],result))
                caller_timings.append(dict(caller=label,seconds=round(time.monotonic()-caller_started,3)))
                print(f'Mutation caller {label}: exact lost-receipt recovery and durable application passed.',flush=True)
            for reader,reference,result in foreign_statuses:
                assert reader.call({'status':reference})['status'] == result
            writer.kill(); writer.wait(timeout=10); writer = None
            invoke('revoke-reader')
            mutation({'status':compiled['reference']},error='AccessDenied')
            invoke('inspect',1,error='AccessDenied')
            for reader,reference,_ in foreign_statuses:
                try: reader.call({'status':reference})
                except Failure as error: assert error.status == 4, error
                else: raise AssertionError('Foreign status reader ignored current revocation')
            assert counts['max_mutations'] == 4
            print(json.dumps({'proof':'Table mutation native admission','elapsed_seconds':round(time.monotonic()-started,3),
                **counts,'selected_sdks':list(sdks),'sdk_install_seconds':sdk_install_seconds,'caller_timings':caller_timings,'resident_authority_pages':8,'lost_receipts':counts['lost_caller_receipts']+1,
                'node_sha256':hashlib.sha256(Path(node).read_bytes()).hexdigest(),
                'proof_sha256':hashlib.sha256(Path(proof).read_bytes()).hexdigest(),
                'host_sha256':hashlib.sha256(Path(host).read_bytes()).hexdigest(),
                'port_sha256':hashlib.sha256(Path(port_host).read_bytes()).hexdigest(),
                'library_sha256':hashlib.sha256(Path(library).read_bytes()).hexdigest()}),flush=True)
            print('Table mutation native: shared client preparation/observation/resumption, exact caller-send and writer-commit lost-receipt disk recovery, atomic rows/result/input, conflicting retry, duplicate outcome, batch rollback, fenced writer and current native/application grants passed.',flush=True)
            print('Native mutation ABI and port: shared actions, lost admission receipts, caller recreation, exact retry, durable status and current denial passed.',flush=True)
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


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('node','proof','host','port_host','library'): parser.add_argument(name)
    parser.add_argument('--sdk',action='append',default=[])
    args = parser.parse_args()
    run(args.node,args.proof,args.host,args.port_host,args.library,sdks=args.sdk)
