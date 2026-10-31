#!/usr/bin/env python3
"""Apply reviewed example declarations to a running local Transit installation.

Uses the public typed transit-admin browser interface. Saved requests and replies
stay private so an uncertain command can be inspected by its original mutation.
Run once after the example migration; restart `transit server` afterwards.
"""
import argparse
import json
import os
from pathlib import Path
import secrets
import shutil
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--installation', type=Path, default=Path.cwd())
parser.add_argument('--admin', default='transit-admin')
parser.add_argument('--node', default='http://127.0.0.1:19104')
parser.add_argument('--origin', default='http://127.0.0.1:8090')
parser.add_argument('--port', type=int, default=8090)
parser.add_argument('--provider', type=Path, action='append', default=[], help='Reviewed BrowserDeclarations.Provider JSON; no secret bytes')
parser.add_argument('--secret', action='append', default=[], metavar='NAME=FILE', help='Copy private secret material into the mounted example directory')
args = parser.parse_args()
os.umask(0o077)
root = args.installation.resolve()
# This is the existing local installation's generated SQL account placement,
# not a browser-specific grant authority. It is only an example bootstrap input.
gateway = json.loads((root / '.transit/sql/gateway.json').read_text())
account = gateway['accounts'][0]
binding = account['execution']['bindings'][0]
connection = dict(scope=dict(realm=account['execution']['realm'], resource=binding['resource'], catalog=binding['catalog']), branch=1, audience=binding['owner'], principal=account['execution']['table_principal'], role=binding['role'])
assert connection['principal'] > 1 and connection['role'] != 0
namespace = binding['namespace']
seed = Path(account['keys']['table'])
private = root / 'browser-private'
private.mkdir(mode=0o700)
requests = private / 'requests'
requests.mkdir()
secrets_dir = private / 'secrets'
secrets_dir.mkdir()
shutil.copyfile(seed, secrets_dir / 'reader')
(private / 'cookie.seed').write_text(secrets.token_hex(32))
definition = 'transit.browser.v1.2026-10-30'
count = 0

def call(action):
    global count
    count += 1
    request = requests / f'{count:03}.request.json'
    response = requests / f'{count:03}.response.json'
    request.write_text(json.dumps(dict(definition=definition, connection=connection, namespace=namespace, development=True, action=action), indent=2)+'\n')
    with response.open('w') as output:
        subprocess.run([args.admin, 'browser', str(seed), str(request), args.node], stdout=output, check=True)
    return json.loads(response.read_text())

def change(kind, value):
    return call(dict(change=dict(definition=definition, namespace=namespace, mutation=list(secrets.token_bytes(16)), expected=None, declaration={kind:value})))

change('secret', dict(name='reader', enabled=True, file='reader'))
for specification in args.secret:
    name, source = specification.split('=',1)
    if not name or len(name)>63 or not all(c.isascii() and (c.isalnum() or c in '_-') for c in name) or name == 'reader':
        raise ValueError('invalid or reserved secret name')
    shutil.copyfile(source, secrets_dir / name)
    change('secret',dict(name=name,enabled=True,file=name))
for source in args.provider:
    provider = json.loads(source.read_text())
    provider['profile']['issuer_profile']['realm_id'] = connection['scope']['realm']
    change('provider',provider)
proposal = call(dict(prepare_publication=dict(mutation=list(secrets.token_bytes(16)),expected=None,name='catalog',title='Public catalog',meaning='Visible example catalog items',source_name='catalog_items',sql="SELECT id, category, slug, title, description, href, visibility, status FROM catalog_items WHERE visibility = 'public'",resource_object=2001,definition_id=1,revision=1,audience='public',publisher=dict(principal=connection['principal'],role=connection['role'],secret='reader'))))['proposed']
call(dict(change=proposal))
# Leave the existing placement file for an explicit reviewed merge. The runtime
# consumes these exact browser fields in transit.yaml; no declarations go there.
placement = dict(browser=dict(listen='127.0.0.1',port=args.port,public_origin=args.origin,development_loopback=True,connection=connection,namespace=namespace,catalog_seed_file=str(seed),cookie_seed_file=str(private/'cookie.seed'),secret_directory=str(secrets_dir)))
(private/'placement.json').write_text(json.dumps(placement,indent=2)+'\n')
print('Declarations accepted. Merge browser-private/placement.json into transit.yaml and restart transit server. Retain browser-private and .transit together.')
