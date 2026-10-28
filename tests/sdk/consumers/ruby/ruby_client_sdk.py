"""Run installed Ruby client gems against the shared raw authority schedule."""
from runner.paths import ROOT
import os
from pathlib import Path
import shutil
import subprocess
import sys
from sdk.sdk_raw_client import run as schedule


def run(node, cli, library, artifacts):
    root = ROOT
    def install(target):
        default = subprocess.check_output(['ruby', '-rrubygems', '-e', 'puts Gem.default_dir'], text=True).strip()
        environment = {k: v for k, v in os.environ.items() if k not in ('RUBYLIB', 'RUBYOPT', 'GEM_HOME', 'GEM_PATH', 'TRANSIT_HOST')}
        environment.update(GEM_HOME=str(target / 'gems'), GEM_PATH=f'{target / "gems"}:{default}')
        files = [Path(artifacts).resolve() / name for name in ('transit-native-client-0.0.1-x86_64-linux.gem', 'transit-client-0.0.1.gem')]
        subprocess.run(['gem', 'install', '--local', '--no-document', '--ignore-dependencies', *files], env=environment, cwd=target, check=True)
        script = target / 'consumer.rb'
        shutil.copyfile(root / 'tests/sdk/consumers/ruby/ruby_client_sdk.rb', script)
        shutil.copyfile(root / 'tests/sdk/consumers/ruby/ruby_schema_values.rb', target / 'schema_values.rb')
        def invoke(mode, config):
            return subprocess.check_output(['ruby', script, mode, config], env=environment, cwd=target, timeout=30)
        return invoke
    schedule(node, cli, library, install, 'Ruby')


if __name__ == '__main__': run(*sys.argv[1:])
