"""An owned directory for an explicitly configured native Transit authority.

No storage process or emulated provider lifecycle lives here. The scenario owns
and joins its actual node/server processes before releasing this directory.
"""
import os
from pathlib import Path
import sys
import tempfile
import urllib.request


class Fixture:
    def __init__(self, *, retain_on_failure=False, parent='/var/tmp'):
        self.retain_on_failure = retain_on_failure
        self.directory = tempfile.TemporaryDirectory(
            prefix='transit-native-', dir=parent, delete=not retain_on_failure)
        self.root = Path(self.directory.name)
        self.native_directory = self.root / 'native'
        self.env = {k: v for k, v in os.environ.items() if not k.startswith('OTEL_')}
        self.http = urllib.request.build_opener(urllib.request.ProxyHandler({}))

    def __enter__(self):
        return self

    def __exit__(self, exc_type, *_):
        if exc_type and self.retain_on_failure:
            print(f'Failed private native installation retained at {self.root}', file=sys.stderr)
        else:
            self.directory.cleanup()
