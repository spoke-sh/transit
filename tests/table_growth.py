"""Independent general catalog growth checks over the real supplied owner."""
import json
from pathlib import Path
import time

from catalog_helpers import Cli


def qualify(count, cli, root, url, call, execute, applied, restart, actors):
    began = time.monotonic()
    connection = json.loads((root / 'console.json').read_text())['catalog']
    connection['scope']['catalog'] = str(connection['scope']['catalog'])
    client = Cli(cli, root, url, connection)
    samples = []
    residents = {}

    def resident():
        current = {}
        for name, process in actors().items():
            assert process.poll() is None, (name, process.returncode)
            status = Path(f'/proc/{process.pid}/status').read_text().splitlines()
            size = int(next(line.split()[1] for line in status if line.startswith('VmHWM:'))) * 1024
            residents[name] = max(residents.get(name, 0), size)
            current[name] = size
        # The existing finite application proof's aggregate resident ceiling.
        assert sum(current.values()) <= 512 * 1024 * 1024, current

    def listing():
        cursor, revision, previous = None, None, 0
        rows, pages = {}, 0
        while True:
            page = client.call({'list': cursor})['page']
            if revision is None:
                revision = page['resource_revision']
            assert page['resource_revision'] == revision, page
            entries = [entry for entry in page['entries'] if entry]
            assert len(entries) <= 8, page
            pages += 1
            for entry in entries:
                metadata = entry['metadata']
                object_id = int(metadata['object'])
                assert object_id > previous and metadata['name'] not in rows, metadata
                previous = object_id
                rows[metadata['name']] = entry
            cursor = page['next']
            if cursor is None:
                return rows, pages
            assert pages < count + 100, 'Catalog cursor did not terminate'

    try:
        baseline, _ = listing()
        resident()
        saved = None
        for index in range(count):
            name = f'growth_{index:05d}'
            operation = 4_000_000 + index * 2
            started = time.monotonic()
            applied(execute(operation, f'CREATE TABLE {name} (id INTEGER PRIMARY KEY, label VARCHAR(200) NOT NULL, active BOOL DEFAULT TRUE)', operation))
            created = time.monotonic()
            result = execute(operation + 1, f"INSERT INTO {name} (id, label) VALUES ({index}, 'row {index}')")
            applied(result)
            assert (result['matched'], result['changed']) == (1, 1), result
            samples.append({'create_seconds': created - started, 'insert_seconds': time.monotonic() - created})
            if index == 0:
                saved = ((root / 'intent.bin').read_bytes(), result)
            if index % 16 == 0 or index + 1 == count:
                resident()
        rows, pages = listing()
        expected = {f'growth_{index:05d}' for index in range(count)}
        assert set(rows) == set(baseline) | expected, (len(rows), len(baseline), count)
        for index in range(count):
            entry = rows[f'growth_{index:05d}']
            assert int(entry['metadata']['object']) == 4_000_000 + 2 * index, entry
            assert entry['head']['rows'] == '1' and entry['head']['pending'] == '0', entry
        if count >= 65:
            assert pages > 8, pages

        # Reopen the actual authority/store, replacing both application workers
        # with fresh ownership. No old process cache survives this boundary.
        restart()
        recovered, recovered_pages = listing()
        assert recovered == rows and recovered_pages == pages, 'Restart changed accepted catalog evidence'
        (root / 'intent.bin').write_bytes(saved[0])
        assert call('status') == saved[1], 'Growth/restart changed the original mutation outcome'
        for index in sorted({0, count // 2, count - 1}):
            result = call('select', f'SELECT id, label, active FROM growth_{index:05d}')
            assert result['object'] == 4_000_000 + index * 2 and len(result['rows']) == 1, result
            atoms = [column['cell']['value']['atom'] for column in result['rows'][0]]
            assert atoms == [{'signed': str(index)}, {'utf8': f'row {index}'}, {'boolean': True}], atoms
        resident()
        return {'tables': count, 'metadata_pages': pages, 'seconds': time.monotonic() - began,
                'resident_high_water_bytes': residents, 'samples': samples, 'recovered': True}
    finally:
        client.close()
