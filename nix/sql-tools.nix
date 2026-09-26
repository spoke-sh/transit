{ pkgs }:
# Versions and transitive source hashes are fixed by the existing flake.lock.
# Keep verification tooling out of Fuze and the ordinary developer shell.
assert pkgs.antlr4.version == "4.13.2";
assert pkgs.lean4.version == "4.29.1";
assert pkgs.python3Packages.pglast.version == "7.13";
pkgs.buildEnv {
  name = "transit-sql-tools";
  paths = [
    pkgs.antlr4
    pkgs.lean4
    (pkgs.python3.withPackages (ps: [
      ps.antlr4-python3-runtime
      ps.pglast
      ps.pyarrow
    ]))
  ];
}
