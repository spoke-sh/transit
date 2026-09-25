{ pkgs }:
{
  packages = with pkgs; [
    rustc
    cargo
    rustfmt
    jdk
    tlaplus
    dotnet-sdk
    erlang
    beam.packages.erlang_28.elixir
  ];
  gson = pkgs.fetchurl {
    url = "https://repo.maven.apache.org/maven2/com/google/code/gson/gson/2.12.1/gson-2.12.1.jar";
    sha256 = "1v7vnk63b7ppjzd4hlki143si36zav1y04603izwsxvlzgai7vpb";
  };
}
