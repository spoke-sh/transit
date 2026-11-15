"""Use the shared persistent native/Table owner for the direct Table source."""
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from serving.placement import DirectReference, query


class Reference(DirectReference):
    binary_names = query.BINARIES

    def __init__(self, work):
        query.Reference.__init__(self, work, 'query')
