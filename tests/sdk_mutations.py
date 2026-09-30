"""Install public mutation SDK consumers outside the checkout for shared faults."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from sdk_unified import Consumer

ROOT = Path(__file__).resolve().parents[1]


def install(root, languages):
    root.mkdir()
    factories = []
    for language in languages:
        if language != 'python': raise ValueError('Unsupported mutation SDK proof language')
        target = root/language
        target.mkdir()
        environment = {k:v for k,v in os.environ.items() if k not in ('PYTHONPATH','PYTHONHOME','TRANSIT_LIBRARY_DIR')}
        venv = target/'venv'
        subprocess.run([sys.executable,'-m','venv','--without-pip',str(venv)],check=True,env=environment)
        python = str(venv/'bin/python')
        subprocess.run([sys.executable,'-m','pip','--python',python,'install','--no-index','--find-links',str(ROOT/'.cache/bindings/wheels'),'transit-station==0.2.0'],check=True,env=environment,stdout=subprocess.DEVNULL)
        script = target/'consumer.py'
        shutil.copy2(ROOT/'tests/python_mutation_sdk.py',script)
        for mode in ('sync','async'):
            def create(url,connection,state,mode=mode,python=python,script=script,target=target,environment=environment):
                config = target/f'{mode}.json'
                config.write_text(json.dumps(dict(url=url,connection=connection,seed_file=str(state/'caller.seed'))))
                return Consumer([python,'-B',str(script),mode,str(config)],environment,target)
            factories.append((f'python-{mode}',create))
    return factories
