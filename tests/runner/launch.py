"""Execute a repository test with an explicit import root, without exporting it."""
from pathlib import Path
import runpy
import sys

from paths import ROOT, TESTS


def main():
    if len(sys.argv) < 2:
        raise SystemExit("usage: python3 -B tests/runner/launch.py tests/OWNER/DRIVER.py [arguments...]")
    target = (ROOT / sys.argv[1]).resolve()
    if not target.is_relative_to(TESTS) or target.suffix != ".py" or not target.is_file():
        raise SystemExit(f"not a Python test inside {TESTS}: {target}")
    # This applies only to this interpreter. Installed SDK consumers launched as
    # children must resolve their own packages; never export a test PYTHONPATH.
    sys.path[0] = str(TESTS)
    sys.argv = [str(target), *sys.argv[2:]]
    runpy.run_path(str(target), run_name="__main__")


if __name__ == "__main__":
    main()
