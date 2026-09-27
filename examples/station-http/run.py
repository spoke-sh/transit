"""Run the finite Zig HTTP example over the shared placement schedule."""
import argparse
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "exchange"))
from run import run

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", choices=("local", "compose", "reference"), default="local")
    parser.add_argument("--bootstrap", action="store_true")
    args = parser.parse_args()
    if args.bootstrap and args.profile == "compose": parser.error("Use local or reference for bootstrap qualification")
    run(args.profile, args.bootstrap, protocol="http")
