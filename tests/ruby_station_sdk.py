"""Install public Ruby Station gems and run the shared real-authority schedule."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
from sdk_station_runner import Consumer, run as schedule


def run(node, cli, library, artifacts, http_worker=None, *, execute=None):
    if execute is None and http_worker is None:
        raise ValueError("The full Station SDK schedule requires the HTTP worker binary")
    root = Path(__file__).resolve().parents[1]
    def install(target):
        default = subprocess.check_output(['ruby', '-rrubygems', '-e', 'puts Gem.default_dir'], text=True).strip()
        environment = {k: v for k, v in os.environ.items() if k not in ('RUBYLIB', 'RUBYOPT', 'GEM_HOME', 'GEM_PATH', 'TRANSIT_HOST')}
        environment.update(GEM_HOME=str(target / 'gems'), GEM_PATH=f'{target / "gems"}:{default}')
        files = [Path(artifacts).resolve() / name for name in (
            'transit-native-client-0.2.0-x86_64-linux.gem', 'transit-client-0.2.0.gem',
            'transit-native-station-0.2.0-x86_64-linux.gem', 'transit-station-0.2.0.gem', 'transit-sdk-examples-0.2.0.gem')]
        subprocess.run(['gem', 'install', '--local', '--no-document', '--ignore-dependencies', *files], env=environment, cwd=target, check=True)
        script = target / 'consumer.rb'
        shutil.copyfile(root / 'tests/ruby_station_sdk.rb', script)
        return Consumer(environment, lambda mode, config: ['ruby', script, mode, config],
            lambda config, role: [target / 'gems/bin/transit-ruby-counter', config, role, '--commits', '1'],
            'fiber-handler', extra_failures=('exception-stop', 'exception-block', 'codec-poison'), arrow_adapter=False)
    (execute or schedule)(node, cli, library, install, 'Ruby')
    if execute is None:
        from sdk_http_runner import run as http_schedule
        http_schedule(node, cli, library, http_worker, install, 'Ruby', public_release=True)


if __name__ == '__main__': run(*sys.argv[1:])
