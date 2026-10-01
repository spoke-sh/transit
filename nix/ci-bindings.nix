{
  pkgs,
  base,
  sql-tools,
  minio,
}:
let
  tools = import ./bindings-tools.nix { inherit pkgs; };
in
pkgs.mkShellNoCC {
  inputsFrom = [ base ];
  packages =
    tools.packages
    ++ [
      pkgs.stdenv.cc
      pkgs.protobuf
      (pkgs.python3.withPackages (ps: [
        ps.pyyaml
        ps.jsonschema
        ps.pyarrow
        ps.grpcio
        ps.protobuf
        ps.h2
        ps.build
        ps.setuptools
        ps.wheel
        ps.pip
        ps.mypy
      ]))
    ]
    ++ pkgs.lib.optionals (pkgs.stdenv.hostPlatform.system == "x86_64-linux") [ minio ];
  TRANSIT_SQL_TOOLS = "${sql-tools}";
  TRANSIT_GSON_JAR = "${tools.gson}";
  DOTNET_CLI_TELEMETRY_OPTOUT = "1";
  DOTNET_SKIP_FIRST_TIME_EXPERIENCE = "1";
}
