"""Repository coordinates shared by test drivers, independent of their depth."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TESTS = ROOT / "tests"
