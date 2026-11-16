"""Qualify original Table/KV/Stream/Queue transaction decisions over native MinIO."""
import json
import os
from pathlib import Path
import subprocess

from runner.paths import ROOT
from storage.providers.cold_storage import ColdStore


def run():
    with ColdStore(tls=True) as cold:
        config = Path(cold.directory.name) / 'mixed-tier.json'
        config.write_text(json.dumps(cold.native_config()))
        config.chmod(0o600)
        subprocess.run(['just', 'test::direct-mixed-transaction'], cwd=ROOT, check=True,
                       timeout=1800, env=os.environ | {'TRANSIT_TEST_MIXED_OBJECT_STORAGE': str(config)})
        assert cold.native_data_objects() > 0, 'Mixed transactions did not reach the immutable tier'
    print('Native MinIO mixed transactions: original decisions and lost-reply identities recovered after verified eviction and cold native owner restart.', flush=True)


if __name__ == '__main__':
    run()
