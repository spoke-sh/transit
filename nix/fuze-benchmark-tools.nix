{ pkgs }:
# Development comparator only. Source/transitive hashes come from flake.lock.
assert pkgs.python3Packages.duckdb.version == "1.5.2";
assert pkgs.python3Packages.pyarrow.version == "23.0.0";
pkgs.python3.withPackages (ps: [
  ps.duckdb
  ps.pyarrow
])
