"""Generated standalone application against real workers and disk-backed history."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import tempfile
from types import SimpleNamespace
import urllib.error
import urllib.request
from harness.services import free_port, wait_ready


def run(node, worker, query_host, gateway, caller):
    node, worker, query_host, gateway, caller = [str(Path(p).resolve()) for p in (node, worker, query_host, gateway, caller)]
    with tempfile.TemporaryDirectory(prefix="transit-work-items-browser-") as directory:
        fixture = SimpleNamespace(root=Path(directory), env=os.environ.copy(),
            http=urllib.request.build_opener(urllib.request.ProxyHandler({})))
        started = time.monotonic()
        processes, logs, residents = [], [], {}
        def resident(name, process):
            status = Path(f"/proc/{process.pid}/status")
            if status.exists():
                for line in status.read_text().splitlines():
                    if line.startswith("VmHWM:"): residents[name] = int(line.split()[1]) * 1024
        def start(name, command):
            log = (fixture.root/f'{name}.log').open('w+')
            logs.append((name, log))
            process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, env=fixture.env)
            processes.append(process)
            return process
        def invoke(phase):
            subprocess.run([caller, url, phase, str(fixture.root)], check=True, timeout=600)
        port, web_port = free_port(), free_port()
        url, origin = f'http://127.0.0.1:{port}', f'http://127.0.0.1:{web_port}'
        public = json.loads(subprocess.check_output([caller, 'public'], timeout=10))
        node_config = fixture.root/'node.json'
        settings = dict(genesis=dict(realm=51, root_key=public, max_clock_error_ms=10000),
            local_directory=str(fixture.root / 'native'), port=port, resident_pages=16)
        node_config.write_text(json.dumps(settings))
        def request(path, body=None, status=200, origin_header=origin):
            headers = {'Content-Type': 'application/json'}
            if origin_header is not None: headers['Origin'] = origin_header
            request = urllib.request.Request(origin+path,data=None if body is None else json.dumps(body).encode(),headers=headers)
            try: response = fixture.http.open(request, timeout=15)
            except urllib.error.HTTPError as error: response = error
            with response:
                data=response.read()
                assert response.status == status, (path,response.status,data)
                return json.loads(data)
        try:
            authority=start('node',[node,str(node_config),'--bootstrap'])
            wait_ready(fixture.http,authority,url+'/health')
            invoke('setup')
            authority.terminate(); authority.wait(timeout=15)
            settings['table'] = json.loads((fixture.root / 'data-catalog.json').read_text())
            node_config.write_text(json.dumps(settings))
            authority = start('node', [node, str(node_config), '--bootstrap'])
            wait_ready(fixture.http, authority, url + '/health')
            invoke('initialize-data')
            for name,binary in [('data',worker),('publication',worker),('requester',query_host),('courier',query_host)]:
                start(name,[binary,str(fixture.root/f'{name}.json')])
            invoke('seed')
            provisioning = time.monotonic()-started
            config=json.loads((fixture.root/'gateway-base.json').read_text())
            config.update(port=web_port,public_origin=origin,development_allow_insecure_http=True)
            config_path=fixture.root/'gateway.json'; config_path.write_text(json.dumps(config))
            invalid = config | {"application": config["application"] | {"operators": [1234]+[None]*15}}
            invalid_path = fixture.root/"invalid-gateway.json"; invalid_path.write_text(json.dumps(invalid))
            refused = subprocess.run([gateway, str(invalid_path)], capture_output=True, timeout=10)
            assert refused.returncode != 0 and b"InvalidApplicationScope" in refused.stderr
            serving=start('gateway',[gateway,str(config_path)])
            wait_ready(fixture.http,serving,origin+'/health')
            assert request('/api/v1/interface')['published']['head']['revision']=='1'
            request('/api/v1/query',{'describe':{}},status=403,origin_header=None)
            request('/api/v1/application',{'info':{}},status=403,origin_header='https://untrusted.example')
            invalid = request('/api/v1/application',{'compile':{'source':'CREATE INTERFACE broken WITH (realm = 51);'}},status=400)['diagnostic']
            assert invalid['code'] == 'application.missing_interface_option' and invalid['outcome'] == 'not_submitted'
            invalid = request('/api/v1/query',{'compile':{'sql':'SELECT missing FROM items'}},status=400)['diagnostic']
            assert invalid['code'] == 'sql.unknown_column' and invalid['outcome'] == 'not_submitted'
            assert invalid['location']['offset'] == '7'
            assert any(f and f['field'] == 'column' and f['value'] == {'text':'missing'} for f in invalid['facts'])
            invalid = request('/api/v1/query',{'submit':{'token':'{}'}},status=400)['diagnostic']
            assert invalid['outcome'] == 'not_submitted' and invalid['evidence'] == 'local_before_dispatch'
            assert not any(a and a['kind'] == 'resume_exact' for a in invalid['actions'])
            request('/api/v1/query',{'suggest':{'search':''}})
            marker=fixture.root/'browser'
            browser=start('browser',['node','examples/work-items/web/browser/proof.mjs',origin,str(marker)])
            def await_phase(phase):
                deadline=time.monotonic()+180
                while not marker.exists() or marker.read_text()!=phase:
                    assert browser.poll() is None, ('browser exited',browser.returncode)
                    assert time.monotonic()<deadline,('browser timeout',phase)
                    time.sleep(.1)
            await_phase('migrate')
            invoke('migrate')
            assert request('/api/v1/interface')['published']['head']['revision']=='2'
            # A gateway is disposable; pending native signatures live in the
            # explicit recovery file and requester history, never its process.
            resident('gateway-first', serving)
            serving.kill();serving.wait(timeout=10)
            serving=start('gateway-restarted',[gateway,str(config_path)])
            wait_ready(fixture.http,serving,origin+'/health')
            marker.write_text('migrated')
            await_phase('deny')
            invoke('deny')
            request('/api/v1/query',{'describe':{}},status=403)
            marker.write_text('denied')
            assert browser.wait(timeout=120)==0
            resident("gateway-restarted", serving)
            for (name, _), process in zip(logs, processes):
                if name in ("node", "data", "publication", "requester", "courier"): resident(name, process)
            print(f'Generated work items: standalone browser, full result coverage, application schema/publication migration, gateway replacement, original upload recovery/cancellation, new generation and current denial passed in {time.monotonic()-started:.2f}s ({provisioning:.2f}s provisioning); per-process peak RSS bytes {residents}.',flush=True)
        except BaseException:
            for name,log in logs:
                log.flush();log.seek(0);print(name,log.read()[-9000:],file=sys.stderr)
            raise
        finally:
            for process in reversed(processes):
                if process.poll() is None: process.kill()
                process.wait(timeout=10)
            for _,log in logs:log.close()


if __name__=='__main__':run(*sys.argv[1:])
