"""Independent controls for confirmed handler-turn evidence."""
import copy
import unittest

from performance.load import station_turn as driver


def fixture():
    config = dict(warmup=1, repeat=1)
    records = []
    counts = dict(alloc_attempts=1, alloc_successes=1, resize_attempts=0, resize_successes=0,
                  growing_resize_attempts=0, remap_attempts=0, remap_successes=0, frees=1,
                  requested_bytes=128, acquired_bytes=128, released_bytes=128, forbidden_attempts=0)
    # Frozen SHA-256 values of independently encoded 128-byte modular payloads.
    hashes = ['cc548ca2dec1f6fe4f58b2e27aa9c7521607df1130d140b55a4dad0665302356',
              '2ffb90b6260cfedf636a076d8f7a43bdb9f5ab5843408a1fbf31f99abfb85328']
    for index in range(2):
        stage = 'warmup' if index == 0 else 'measured'
        records.extend([dict(event='input_attempt', index=index),
                        dict(event='input_accepted', index=index, input=10 + index * 10),
                        dict(event='attempt', index=index, input=10 + index * 10, stage=stage),
                        dict(event='confirmed', index=index, input=10 + index * 10, commit=15 + index * 10),
                        dict(event='state', index=index, recovery=False, sha256=hashes[index]),
                        dict(event='sample', index=index, input=10 + index * 10, commit=15 + index * 10,
                             stage=stage, ns=100 + index, backing=counts)])
    records.extend(dict(event='output', index=i, input=10 + i * 10, commit=15 + i * 10,
                        recovery=False, sha256=hashes[i]) for i in range(2))
    records.append(dict(event='complete', recovery=False, definition='test-definition', build_mode='safe'))
    return records, config


class Reports(unittest.TestCase):
    def test_confirmed_turn_and_recovered_original_outputs(self):
        records, config = fixture()
        result = driver.validate(records, config, False, 'test-definition')
        self.assertEqual(101, result['turn_ns']['p50_ns'])
        recovered = [dict(row, recovery=True) for row in records if row['event'] == 'output']
        recovered += [dict(records[10], recovery=True), dict(records[-1], recovery=True)]
        self.assertEqual(result['accepted'], driver.validate(recovered, config, True, 'test-definition', result['accepted'])['accepted'])

    def test_missing_or_corrupt_state_output_and_completion_fail(self):
        records, config = fixture()
        for index in range(len(records)):
            missing = records[:index] + records[index + 1:]
            with self.assertRaises(ValueError):
                driver.validate(missing, config, False, 'test-definition')
        for index in (4, 10, 12, 13):
            corrupt = copy.deepcopy(records)
            corrupt[index]['sha256'] = '0' * 64
            with self.assertRaises(ValueError):
                driver.validate(corrupt, config, False, 'test-definition')

    def test_changed_definition_original_attribution_and_allocation_fail(self):
        records, config = fixture()
        for index, field, value in ((14, 'definition', 'foreign'), (12, 'commit', 99), (5, 'backing', {}), (11, 'stage', 'warmup')):
            changed = copy.deepcopy(records)
            changed[index][field] = value
            with self.assertRaises(ValueError):
                driver.validate(changed, config, False, 'test-definition')

    def test_unconfirmed_turn_and_input_remain_unknown(self):
        records, _ = fixture()
        self.assertEqual(1, driver.incomplete(records[:3])['unknown'])
        self.assertEqual(1, driver.incomplete(records[:1])['admission_unknown'])
        self.assertEqual(0, driver.incomplete(records[:3])['refused'])
        self.assertEqual(0, driver.incomplete(records[:4])['unknown'])
        self.assertEqual(1, driver.incomplete(records[:4])['failed'])


if __name__ == '__main__':
    unittest.main()
