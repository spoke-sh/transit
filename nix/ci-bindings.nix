{
  pkgs,
  base,
  sql-tools,
}:
let
  tools = import ./bindings-tools.nix { inherit pkgs; };
in
pkgs.mkShellNoCC {
  inputsFrom = [ base ];
  packages = tools.packages ++ [
    pkgs.stdenv.cc
    (pkgs.python3.withPackages (ps: [
      ps.pyyaml
      ps.pyarrow
      ps.build
      ps.setuptools
      ps.wheel
      ps.pip
      ps.mypy
    ]))
  ];
  TRANSIT_SQL_TOOLS = "${sql-tools}";
  TRANSIT_GSON_JAR = "${tools.gson}";
  DOTNET_CLI_TELEMETRY_OPTOUT = "1";
  DOTNET_SKIP_FIRST_TIME_EXPERIENCE = "1";
}
