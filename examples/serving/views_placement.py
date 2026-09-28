"""Compose/reference composition of the same actual Board/counter browser proof.

Only placement and private files differ. All provisioning, controls, result reads
and browser assertions use the public interfaces shared with the native fixture.
"""
import json
import subprocess
import time
from types import SimpleNamespace
from urllib.parse import urlsplit

from serving import TLS, native_query
from serving_tls import TLSProxy
from storage import free_port


def run(owner):
    from reactive_views import run as browser_proof
    placement, work, keys = (owner[name] for name in ('placement', 'work', 'keys'))
    profile, owned = owner['profile'], owner['owned']
    public_ports = [free_port(), free_port()]
    # These indexes identify the TLS routes in the shared independent peer.
    gateway_ports = [free_port(), free_port()]
    hosts, endpoints, proxies = {}, {}, {}
    observer = None

    def mount(name):
        return '/gateway' if profile == 'reference' else '/' + name

    def files(name, viewer):
        for filename, principal in (('seed.key', 79), ('credential', viewer)):
            path = work / name / filename
            path.write_bytes(keys[principal].seed.read_bytes())
            path.chmod(0o600)

    def gateway(index):
        name = 'gateway-' + str(index)
        principal = 65536 if index == 0 else 65537
        prefix = mount(name)
        files(name, principal)
        host = f'127.0.0.1:{public_ports[index]}'
        return dict(service=1, ingress=owner['ingress'], resource=owner['ingress_resource'], listen='0.0.0.0', port=8080,
            host=host, public_origin='https://' + host, reactive=True,
            callers=[dict(principal=p, public_key=keys[p].public) for p in (33, 65536, 65537)],
            options=dict(requests=4, request_timeout_ms=30000), per_caller_requests=4,
            viewer=dict(principal=principal, seed_file=prefix + '/credential', snapshot_values=index == 1, refresh=index == 0))

    def start_host(index, config, board=False):
        name = 'gateway-' + str(index)
        path = work / name / 'config.json'
        path.write_text(json.dumps(config)); path.chmod(0o600)
        if index == 0:
            placement.env['SERVING_GATEWAY_IMAGE'] = placement.env['EXCHANGE_BOARD_IMAGE' if board else 'EXCHANGE_CALLER_IMAGE']
        hosts[index] = placement.start_gateway(name, board) if profile == 'reference' else placement.start(name)
        endpoint = placement.url(name)
        if index in endpoints:
            assert endpoint == endpoints[index], 'physical recovery changed the private TLS backend'
        endpoints[index] = endpoint
        if index not in proxies:
            target = urlsplit(endpoint)
            proxies[index] = owned.enter_context(TLSProxy(work / (name + '-view-tls'), target.port, target.hostname, public_ports[index], read_timeout=35))
            TLS[gateway_ports[index]] = proxies[index]
        until = time.monotonic() + 30
        while True:
            try:
                owner['request']('https://127.0.0.1:' + str(public_ports[index]), '/health', tls=proxies[index].context)
                break
            except (OSError, AssertionError):
                assert time.monotonic() < until, 'view host readiness'
                time.sleep(.1)
        return hosts[index]

    def stop_gateway(index):
        placement.stop_for_recovery('gateway-' + str(index), hosts[index])

    def start(name, executable, config):
        nonlocal observer
        if name == 'board-live':
            config['upstream'] = placement.authority
            config['listen'] = '0.0.0.0'
            config['port'] = 8080
            config['seed_file'] = mount('gateway-0') + '/seed.key'
            config['query_v2']['seed_file'] = mount('gateway-0') + '/credential'
            config['reactive']['seed_file'] = config['seed_file']
            config['reactive']['gateway'] = gateway(0)
            return start_host(0, config, True)
        assert name == 'clock-observer'
        # The clock is an explicit host-side deployment observer in both
        # placements. It has no root key, storage connection or worker ownership.
        path = owner['write'](name + '.json', config)
        log = (work / (name + '.log')).open('w+')
        owner['logs'].append(log)
        observer = subprocess.Popen([executable, path], env=owner['env'], stdout=log, stderr=subprocess.STDOUT)
        owner['local'].append(observer)
        return observer

    def recover():
        for index in range(2): stop_gateway(index)
        owner['recover_views']()
        for index in range(2):
            config = json.loads((work / f'gateway-{index}' / 'config.json').read_text())
            start_host(index, config, index == 0)

    for index in range(2):
        config = dict(url=placement.authority, realm=49, principal=79, seed_file=mount('gateway-' + str(index)) + '/seed.key',
            counter_view=index == 1, role={'gateway': gateway(index)})
        start_host(index, config)
    try:
        environment = owner | dict(store=SimpleNamespace(root=work, env=owner['env']),
            example='zig-out/bin/transit-serving-example',
            board='transit-board', worker_url=owner['url'], deadline_ms=owner['deadline'], gateway_ports=gateway_ports,
            public_host=f'127.0.0.1:{public_ports[0]}', start=start, stop_gateway=stop_gateway,
            hosts_alive=lambda: all(host.poll() is None for host in hosts.values()), recover=recover,
            query=lambda principal, kind: owner['request'](owner['url'], '/v3/query', native_query(keys[principal], principal, kind)))
        browser_proof(environment, TLS)
    finally:
        for port in gateway_ports: TLS.pop(port, None)
