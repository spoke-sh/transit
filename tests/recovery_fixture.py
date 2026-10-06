"""Retain only owned private proof state after joining native providers."""
import shutil
import time


def retain_recovery_fixture(fixture, cold_store, destination, recovery):
    """Retain private failed state after joining each owned native process."""
    fixture.stop()
    retained = destination.parent / 'recovery-failures' / str(time.time_ns())
    retained.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    recovery['original_fixture'] = str(fixture.root)
    shutil.move(fixture.root, retained)
    recovery['retained_fixture'] = str(retained)
    if cold_store:
        recovery['original_cold_fixture'] = str(cold_store.root)
        cold_store.stop()
        shutil.move(cold_store.root, retained / 'cold-store')
        recovery['retained_cold_fixture'] = str(retained / 'cold-store')

