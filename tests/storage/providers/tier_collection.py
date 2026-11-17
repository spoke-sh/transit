"""Run the real retained-graph schedules against explicit native MinIO tiering."""
import json
import os
from pathlib import Path
import subprocess
import sys

from storage.providers.cold_storage import ColdStore


def run(binary):
    binary = str(Path(binary).resolve(strict=True))
    with ColdStore(tls=True) as cold:
        config = Path(cold.directory.name) / 'tier.json'
        config.write_text(json.dumps(cold.native_config()))
        config.chmod(0o600)
        subprocess.run([binary], check=True, timeout=3600,
                       env=os.environ | {'TRANSIT_TEST_OBJECT_STORAGE': str(config)})
        assert cold.native_data_objects() > 0, 'Collection schedules did not publish immutable generations'
    print('Native MinIO graph: protected Document sources, Table pins/admitted work, Stream receipts/compaction and Queue closure survived verified eviction, collection and cold owner reopen.', flush=True)


if __name__ == '__main__':
    run(*sys.argv[1:])
